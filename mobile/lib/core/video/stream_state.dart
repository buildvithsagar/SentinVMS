import 'package:app/features/camera/models/live_stream_session.dart';
import 'package:equatable/equatable.dart';

enum LiveStreamPhase {
  idle,
  connectingWebRtc,
  webRtcConnected,
  webRtcFailed,
  connectingHls,
  hlsConnected,
  failed,
  stopped,
}

class LiveStreamState extends Equatable {
  const LiveStreamState({required this.phase, this.session, this.message});

  const LiveStreamState.idle() : this(phase: LiveStreamPhase.idle);

  final LiveStreamPhase phase;
  final LiveStreamSession? session;
  final String? message;

  bool get isConnecting =>
      phase == LiveStreamPhase.connectingWebRtc ||
      phase == LiveStreamPhase.connectingHls;
  bool get isLive =>
      phase == LiveStreamPhase.webRtcConnected ||
      phase == LiveStreamPhase.hlsConnected;

  String get label {
    switch (phase) {
      case LiveStreamPhase.idle:
        return 'IDLE';
      case LiveStreamPhase.connectingWebRtc:
        return 'CONNECTING WEBRTC';
      case LiveStreamPhase.webRtcConnected:
        return 'LIVE • WEBRTC';
      case LiveStreamPhase.webRtcFailed:
        return 'SWITCHING TO HLS';
      case LiveStreamPhase.connectingHls:
        return 'CONNECTING HLS';
      case LiveStreamPhase.hlsConnected:
        return 'LIVE • HLS';
      case LiveStreamPhase.failed:
        return 'STREAM ERROR';
      case LiveStreamPhase.stopped:
        return 'STOPPED';
    }
  }

  @override
  List<Object?> get props => [phase, session, message];
}
