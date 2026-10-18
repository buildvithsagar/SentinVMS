import 'dart:async';

import 'package:app/core/theme/vms_theme.dart';
import 'package:app/core/video/whep_service.dart';
import 'package:app/features/stream_demo/data/local_gateway_client.dart';
import 'package:app/features/stream_demo/models/local_gateway_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:video_player/video_player.dart';

enum _GatewayPlayerPhase {
  startingGateway,
  connectingWebRtc,
  webRtcLive,
  connectingHls,
  hlsLive,
  failed,
}

class LocalGatewayPlayerPane extends StatefulWidget {
  const LocalGatewayPlayerPane({
    required this.gatewayBaseUri,
    required this.rtspUri,
    required this.compatibilityMode,
    this.gatewayToken,
    this.gatewayClient,
    this.whepService,
    super.key,
  });

  final Uri gatewayBaseUri;
  final Uri rtspUri;
  final bool compatibilityMode;
  final String? gatewayToken;
  final LocalGatewayClient? gatewayClient;
  final WhepService? whepService;

  @override
  State<LocalGatewayPlayerPane> createState() => _LocalGatewayPlayerPaneState();
}

class _LocalGatewayPlayerPaneState extends State<LocalGatewayPlayerPane>
    with WidgetsBindingObserver {
  late final LocalGatewayClient _gatewayClient;
  late final WhepService _whepService;
  var _phase = _GatewayPlayerPhase.startingGateway;
  LocalGatewaySession? _session;
  WhepConnection? _whepConnection;
  VideoPlayerController? _hlsController;
  String? _message;
  var _disposed = false;
  var _suspended = false;
  var _requestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gatewayClient = widget.gatewayClient ?? LocalGatewayClient();
    _whepService = widget.whepService ?? WhepService();
    unawaited(_start());
  }

  Future<void> _start() async {
    final requestId = ++_requestId;
    try {
      await _gatewayClient.checkHealth(
        gatewayBaseUri: widget.gatewayBaseUri,
        token: widget.gatewayToken,
      );
      if (_disposed || _suspended || requestId != _requestId) return;

      final session = await _gatewayClient.createStream(
        gatewayBaseUri: widget.gatewayBaseUri,
        rtspUri: widget.rtspUri,
        compatibilityMode: widget.compatibilityMode,
        token: widget.gatewayToken,
      );
      if (_disposed || _suspended || requestId != _requestId) {
        await _gatewayClient.stopStream(
          gatewayBaseUri: widget.gatewayBaseUri,
          streamId: session.id,
          token: widget.gatewayToken,
        );
        return;
      }
      _session = session;
      _setPhase(_GatewayPlayerPhase.connectingWebRtc);
      try {
        _whepConnection = await _whepService.connect(session.whepUri);
        if (_disposed || _suspended || requestId != _requestId) {
          await _whepConnection?.close();
          return;
        }
        _setPhase(_GatewayPlayerPhase.webRtcLive);
        return;
      } catch (_) {
        _message =
            'Low-latency connection was unavailable. Compatibility playback is active.';
        await _whepConnection?.close();
        _whepConnection = null;
      }
      await _startHls(session, requestId);
    } on LocalGatewayException catch (error) {
      if (!_disposed && !_suspended && requestId == _requestId) {
        _message = error.message;
        _setPhase(_GatewayPlayerPhase.failed);
      }
    } catch (_) {
      if (!_disposed && !_suspended && requestId == _requestId) {
        _message = 'The gateway could not start this camera.';
        _setPhase(_GatewayPlayerPhase.failed);
      }
    }
  }

  Future<void> _startHls(LocalGatewaySession session, int requestId) async {
    _setPhase(_GatewayPlayerPhase.connectingHls);
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.networkUrl(session.hlsUri);
      await controller.initialize();
      await controller.play();
      if (_disposed || _suspended || requestId != _requestId) {
        await controller.dispose();
        return;
      }
      _hlsController = controller;
      _setPhase(_GatewayPlayerPhase.hlsLive);
    } catch (_) {
      await controller?.dispose();
      if (!_disposed && !_suspended && requestId == _requestId) {
        _message =
            'The camera could not be played through WebRTC or HLS. Check network access and gateway diagnostics.';
        _setPhase(_GatewayPlayerPhase.failed);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_suspended && !_disposed) {
          _suspended = false;
          _setPhase(_GatewayPlayerPhase.startingGateway);
          unawaited(_start());
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (!_suspended && !_disposed) {
          _suspended = true;
          unawaited(_stopActiveSession());
        }
    }
  }

  Future<void> _stopActiveSession() async {
    _requestId++;
    final session = _session;
    final whepConnection = _whepConnection;
    final hlsController = _hlsController;
    _session = null;
    _whepConnection = null;
    _hlsController = null;
    await whepConnection?.close();
    await hlsController?.dispose();
    if (session != null) {
      await _gatewayClient.stopStream(
        gatewayBaseUri: widget.gatewayBaseUri,
        streamId: session.id,
        token: widget.gatewayToken,
      );
    }
  }

  void _setPhase(_GatewayPlayerPhase phase) {
    if (!mounted || _disposed) return;
    setState(() => _phase = phase);
  }

  Future<void> _togglePlayback() async {
    final controller = _hlsController;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    unawaited(_stopActiveSession());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final hlsController = _hlsController;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: Colors.black,
              child: switch (_phase) {
                _GatewayPlayerPhase.webRtcLive => RTCVideoView(
                  _whepConnection!.renderer,
                ),
                _GatewayPlayerPhase.hlsLive =>
                  hlsController == null
                      ? const SizedBox.shrink()
                      : VideoPlayer(hlsController),
                _GatewayPlayerPhase.failed => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _message ?? 'Local gateway stream failed.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: VmsColors.danger),
                    ),
                  ),
                ),
                _ => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(
                        _statusLabel,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _statusColor.withValues(alpha: 0.5)),
              ),
              child: Text(
                _statusLabel,
                style: TextStyle(
                  color: _statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (session != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${session.sourceCodec} → ${session.deliveryCodec}'
                  '${session.transcoded ? ' • transcoded' : ' • pass-through'}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            ] else
              const Spacer(),
            if (_phase == _GatewayPlayerPhase.hlsLive)
              if (hlsController != null)
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: hlsController,
                  builder: (context, value, _) => IconButton(
                    tooltip: value.isPlaying ? 'Pause' : 'Play',
                    onPressed: _togglePlayback,
                    icon: Icon(
                      value.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                    color: Colors.white,
                  ),
                ),
          ],
        ),
        if (_message != null && _phase == _GatewayPlayerPhase.hlsLive)
          Text(
            _message!,
            style: const TextStyle(color: VmsColors.warning, fontSize: 11),
          ),
      ],
    );
  }

  String get _statusLabel => switch (_phase) {
    _GatewayPlayerPhase.startingGateway => 'PREPARING CAMERA',
    _GatewayPlayerPhase.connectingWebRtc => 'STARTING LOW-LATENCY VIDEO',
    _GatewayPlayerPhase.webRtcLive => 'LIVE • LOW LATENCY',
    _GatewayPlayerPhase.connectingHls => 'STARTING COMPATIBILITY MODE',
    _GatewayPlayerPhase.hlsLive => 'LIVE • COMPATIBILITY',
    _GatewayPlayerPhase.failed => 'CONNECTION FAILED',
  };

  Color get _statusColor => switch (_phase) {
    _GatewayPlayerPhase.webRtcLive ||
    _GatewayPlayerPhase.hlsLive => VmsColors.success,
    _GatewayPlayerPhase.failed => VmsColors.danger,
    _ => VmsColors.warning,
  };
}
