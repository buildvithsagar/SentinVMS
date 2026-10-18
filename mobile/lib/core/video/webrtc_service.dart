import 'dart:async';

import 'package:app/features/camera/models/live_stream_session.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef WebRtcOfferExchange =
    Future<WebRtcNegotiationResult> Function(String sdp, String type);
typedef WebRtcCandidateSender =
    Future<void> Function(WebRtcIceCandidateData candidate);

class WebRtcConnection {
  WebRtcConnection({required this.peerConnection, required this.renderer});

  final RTCPeerConnection peerConnection;
  final RTCVideoRenderer renderer;
  bool _closed = false;

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    renderer.srcObject = null;
    try {
      await peerConnection.close();
    } finally {
      await peerConnection.dispose();
      await renderer.dispose();
    }
  }
}

class WebRtcService {
  const WebRtcService({this.connectionTimeout = const Duration(seconds: 10)});

  final Duration connectionTimeout;

  Future<WebRtcConnection> connect({
    required LiveStreamSession session,
    required WebRtcOfferExchange exchangeOffer,
    required WebRtcCandidateSender sendCandidate,
  }) async {
    final renderer = RTCVideoRenderer();
    await renderer.initialize();

    RTCPeerConnection? peerConnection;
    try {
      peerConnection = await createPeerConnection(<String, dynamic>{
        'sdpSemantics': 'unified-plan',
        'iceServers': session.iceServers,
      });

      final connected = Completer<void>();
      peerConnection
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
              StateError('WebRTC connection entered state $state.'),
            );
          }
        }
        ..onTrack = (event) {
          if (event.track.kind == 'video' && event.streams.isNotEmpty) {
            renderer.srcObject = event.streams.first;
          }
        }
        ..onIceCandidate = (candidate) {
          final value = candidate.candidate;
          if (value == null || value.isEmpty) return;
          unawaited(
            _sendCandidateSafely(
              sendCandidate,
              WebRtcIceCandidateData(
                candidate: value,
                sdpMid: candidate.sdpMid,
                sdpMLineIndex: candidate.sdpMLineIndex,
              ),
            ),
          );
        };

      await peerConnection.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      final offer = await peerConnection.createOffer();
      await peerConnection.setLocalDescription(offer);
      final offerSdp = offer.sdp;
      if (offerSdp == null || offerSdp.isEmpty) {
        throw StateError('WebRTC generated an empty SDP offer.');
      }

      final negotiation = await exchangeOffer(offerSdp, offer.type ?? 'offer');
      await peerConnection.setRemoteDescription(
        RTCSessionDescription(negotiation.answerSdp, negotiation.answerType),
      );
      for (final candidate in negotiation.remoteCandidates) {
        await peerConnection.addCandidate(
          RTCIceCandidate(
            candidate.candidate,
            candidate.sdpMid,
            candidate.sdpMLineIndex,
          ),
        );
      }

      await connected.future.timeout(connectionTimeout);
      return WebRtcConnection(
        peerConnection: peerConnection,
        renderer: renderer,
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

  Future<void> _sendCandidateSafely(
    WebRtcCandidateSender sender,
    WebRtcIceCandidateData candidate,
  ) async {
    try {
      await sender(candidate);
    } catch (_) {
      // A later candidate or TURN route can still complete negotiation.
    }
  }
}
