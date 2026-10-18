import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WhepConnection {
  WhepConnection._({
    required this.peerConnection,
    required this.renderer,
    required this._dio,
    required this._resourceUri,
    required this._entityTag,
  });

  final RTCPeerConnection peerConnection;
  final RTCVideoRenderer renderer;
  final Dio _dio;
  final Uri? _resourceUri;
  final String? _entityTag;
  var _closed = false;

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final resourceUri = _resourceUri;
    if (resourceUri != null) {
      try {
        await _dio.deleteUri<void>(
          resourceUri,
          options: Options(
            headers: {if (_entityTag != null) 'If-Match': _entityTag},
            validateStatus: (status) => status != null && status < 500,
          ),
        );
      } catch (_) {
        // Closing the local peer still releases the phone decoder and sockets.
      }
    }
    renderer.srcObject = null;
    try {
      await peerConnection.close();
    } finally {
      await peerConnection.dispose();
      await renderer.dispose();
    }
  }
}

class WhepService {
  WhepService({
    Dio? dio,
    this.iceGatheringTimeout = const Duration(seconds: 4),
    this.connectionTimeout = const Duration(seconds: 12),
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 15),
             ),
           );

  final Dio _dio;
  final Duration iceGatheringTimeout;
  final Duration connectionTimeout;

  Future<WhepConnection> connect(Uri endpoint) async {
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    RTCPeerConnection? peerConnection;
    try {
      peerConnection = await createPeerConnection(<String, dynamic>{
        'sdpSemantics': 'unified-plan',
        'iceServers': <Map<String, dynamic>>[],
      });
      final gatheringComplete = Completer<void>();
      final connected = Completer<void>();
      peerConnection
        ..onIceGatheringState = (state) {
          if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
              !gatheringComplete.isCompleted) {
            gatheringComplete.complete();
          }
        }
        ..onConnectionState = (state) {
          if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
              !connected.isCompleted) {
            connected.complete();
          } else if ((state ==
                      RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
                  state ==
                      RTCPeerConnectionState
                          .RTCPeerConnectionStateDisconnected ||
                  state ==
                      RTCPeerConnectionState.RTCPeerConnectionStateClosed) &&
              !connected.isCompleted) {
            connected.completeError(
              StateError('WHEP peer connection entered state $state.'),
            );
          }
        }
        ..onTrack = (event) {
          if (event.track.kind == 'video' && event.streams.isNotEmpty) {
            renderer.srcObject = event.streams.first;
          }
        };

      await peerConnection.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );
      final offer = await peerConnection.createOffer();
      await peerConnection.setLocalDescription(offer);
      try {
        await gatheringComplete.future.timeout(iceGatheringTimeout);
      } on TimeoutException {
        // Host candidates already gathered are enough on a shared LAN.
      }
      final localDescription = await peerConnection.getLocalDescription();
      final offerSdp = localDescription?.sdp;
      if (offerSdp == null || offerSdp.isEmpty) {
        throw StateError('WHEP generated an empty SDP offer.');
      }

      final response = await _dio.postUri<String>(
        endpoint,
        data: offerSdp,
        options: Options(
          contentType: 'application/sdp',
          responseType: ResponseType.plain,
          headers: const {'Accept': 'application/sdp'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (response.statusCode != 201 && response.statusCode != 200) {
        throw StateError('MediaMTX WHEP returned HTTP ${response.statusCode}.');
      }
      final answerSdp = response.data;
      if (answerSdp == null || answerSdp.isEmpty) {
        throw StateError('MediaMTX WHEP returned an empty SDP answer.');
      }
      await peerConnection.setRemoteDescription(
        RTCSessionDescription(answerSdp, 'answer'),
      );
      await connected.future.timeout(connectionTimeout);

      final location = response.headers.value('location');
      return WhepConnection._(
        peerConnection: peerConnection,
        renderer: renderer,
        dio: _dio,
        resourceUri: location == null ? null : endpoint.resolve(location),
        entityTag: response.headers.value('etag'),
      );
    } catch (_) {
      if (peerConnection != null) {
        try {
          await peerConnection.close();
          await peerConnection.dispose();
        } catch (_) {}
      }
      await renderer.dispose();
      rethrow;
    }
  }
}
