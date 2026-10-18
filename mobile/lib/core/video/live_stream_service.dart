import 'dart:async';

import 'package:app/core/video/decoder_pool.dart';
import 'package:app/core/video/stream_state.dart';
import 'package:app/core/video/webrtc_service.dart';
import 'package:app/features/camera/data/camera_repository.dart';
import 'package:app/features/camera/models/live_stream_session.dart';
import 'package:video_player/video_player.dart';

class LiveStreamService {
  LiveStreamService({
    required this.cameraRepository,
    required this.decoderPool,
    required this.webRtcService,
  });

  final CameraRepository cameraRepository;
  final DecoderPool decoderPool;
  final WebRtcService webRtcService;

  final _stateController = StreamController<LiveStreamState>.broadcast();
  Stream<LiveStreamState> get stateStream => _stateController.stream;

  LiveStreamState _state = const LiveStreamState.idle();
  LiveStreamState get state => _state;

  WebRtcConnection? _webRtcConnection;
  VideoPlayerController? _hlsController;
  DecoderLease? _hlsLease;
  LiveStreamSession? _session;
  int _requestId = 0;
  bool _disposed = false;

  WebRtcConnection? get webRtcConnection => _webRtcConnection;
  VideoPlayerController? get hlsController => _hlsController;

  Future<void> start({
    required String cameraId,
    required String siteId,
    String quality = 'main',
  }) async {
    final requestId = ++_requestId;
    await _releaseCurrentSession();
    if (_disposed || requestId != _requestId) return;

    _emit(const LiveStreamState(phase: LiveStreamPhase.connectingWebRtc));
    try {
      final session = await cameraRepository.getLiveStreamSession(
        cameraId: cameraId,
        type: StreamType.webrtc,
        quality: quality,
      );
      if (_disposed || requestId != _requestId) {
        await cameraRepository.closeLiveStreamSession(session);
        return;
      }
      _session = session;
      _webRtcConnection = await webRtcService.connect(
        session: session,
        exchangeOffer: (sdp, type) => cameraRepository.exchangeWebRtcOffer(
          session: session,
          sdp: sdp,
          type: type,
        ),
        sendCandidate: (candidate) => cameraRepository.sendWebRtcIceCandidate(
          session: session,
          candidate: candidate,
        ),
      );
      if (_disposed || requestId != _requestId) {
        await _releaseCurrentSession();
        return;
      }
      _emit(
        LiveStreamState(
          phase: LiveStreamPhase.webRtcConnected,
          session: session,
        ),
      );
      return;
    } catch (error) {
      if (_disposed || requestId != _requestId) return;
      await _releaseCurrentSession();
      _emit(
        LiveStreamState(
          phase: LiveStreamPhase.webRtcFailed,
          message: error.toString(),
        ),
      );
    }

    await _startHls(requestId: requestId, cameraId: cameraId, quality: quality);
  }

  Future<void> _startHls({
    required int requestId,
    required String cameraId,
    required String quality,
  }) async {
    _emit(const LiveStreamState(phase: LiveStreamPhase.connectingHls));
    try {
      final session = await cameraRepository.getLiveStreamSession(
        cameraId: cameraId,
        type: StreamType.hls,
        quality: quality,
      );
      if (_disposed || requestId != _requestId) {
        await cameraRepository.closeLiveStreamSession(session);
        return;
      }
      _session = session;
      final streamUrl = session.streamUrl;
      if (streamUrl == null || streamUrl.isEmpty) {
        throw const CameraException(
          'HLS session did not provide a stream URL.',
        );
      }

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(streamUrl),
        httpHeaders: const {
          'User-Agent': 'SentinVMS/1.0 (Flutter; authorized MediaCore session)',
        },
      );
      await controller.initialize();
      if (_disposed || requestId != _requestId) {
        await controller.dispose();
        return;
      }

      _hlsController = controller;
      _hlsLease = await decoderPool.acquire(
        cameraId: cameraId,
        controller: controller,
        onEvicted: () {
          _hlsController = null;
          _hlsLease = null;
          if (!_disposed) {
            _emit(
              const LiveStreamState(
                phase: LiveStreamPhase.failed,
                message: 'Player resource was reassigned to another stream.',
              ),
            );
          }
        },
      );
      await controller.setLooping(true);
      await controller.play();
      _emit(
        LiveStreamState(phase: LiveStreamPhase.hlsConnected, session: session),
      );
    } catch (error) {
      if (!_disposed && requestId == _requestId) {
        await _releaseCurrentSession();
        _emit(
          LiveStreamState(
            phase: LiveStreamPhase.failed,
            message: error.toString(),
          ),
        );
      }
    }
  }

  Future<void> stop() async {
    _requestId++;
    await _releaseCurrentSession();
    if (!_disposed) {
      _emit(const LiveStreamState(phase: LiveStreamPhase.stopped));
    }
  }

  Future<void> _releaseCurrentSession() async {
    final webRtcConnection = _webRtcConnection;
    _webRtcConnection = null;
    if (webRtcConnection != null) {
      await webRtcConnection.close();
    }

    final lease = _hlsLease;
    _hlsLease = null;
    _hlsController = null;
    if (lease != null) {
      await decoderPool.release(lease);
    }

    final session = _session;
    _session = null;
    if (session != null) {
      await cameraRepository.closeLiveStreamSession(session);
    }
  }

  void _emit(LiveStreamState state) {
    _state = state;
    if (!_stateController.isClosed) _stateController.add(state);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _requestId++;
    await _releaseCurrentSession();
    await _stateController.close();
  }
}
