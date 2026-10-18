import 'package:equatable/equatable.dart';

enum StreamType { webrtc, hls }

extension StreamTypeValue on StreamType {
  String get apiValue => name;
}

class LiveStreamSession extends Equatable {
  const LiveStreamSession({
    required this.type,
    this.sessionId,
    this.viewerId,
    this.streamUrl,
    this.signalingUrl,
    this.offerUrl,
    this.iceUrl,
    this.closeUrl,
    this.expiresAt,
    this.sourceCodec,
    this.deliveryCodec,
    this.iceServers = const [],
  });

  factory LiveStreamSession.fromJson(
    Map<String, dynamic> json, {
    StreamType? requestedType,
  }) {
    final payload = _map(json['data']) ?? json;
    final signaling = _map(payload['signaling']);
    final rawType = (payload['type'] as String?)?.toLowerCase();
    final type = rawType == 'webrtc'
        ? StreamType.webrtc
        : rawType == 'hls'
        ? StreamType.hls
        : requestedType ?? StreamType.hls;

    return LiveStreamSession(
      type: type,
      sessionId: _string(payload, const ['session_id', 'sessionId']),
      viewerId: _string(payload, const ['viewer_id', 'viewerId']),
      streamUrl: _string(payload, const [
        'stream_url',
        'streamUrl',
        'hls_url',
        'hlsUrl',
        'url',
      ]),
      signalingUrl: signaling == null
          ? _string(payload, const ['signaling_url', 'signalingUrl'])
          : _string(signaling, const ['url', 'signaling_url', 'signalingUrl']),
      offerUrl: signaling == null
          ? _string(payload, const ['offer_url', 'offerUrl'])
          : _string(signaling, const ['offer_url', 'offerUrl']),
      iceUrl: signaling == null
          ? _string(payload, const ['ice_url', 'iceUrl'])
          : _string(signaling, const ['ice_url', 'iceUrl']),
      closeUrl: signaling == null
          ? _string(payload, const ['close_url', 'closeUrl'])
          : _string(signaling, const ['close_url', 'closeUrl']),
      expiresAt: _dateTime(payload, const ['expires_at', 'expiresAt']),
      sourceCodec: _string(payload, const ['source_codec', 'sourceCodec']),
      deliveryCodec: _string(payload, const [
        'delivery_codec',
        'deliveryCodec',
        'codec',
      ]),
      iceServers: _iceServers(payload, signaling),
    );
  }

  final StreamType type;
  final String? sessionId;
  final String? viewerId;
  final String? streamUrl;
  final String? signalingUrl;
  final String? offerUrl;
  final String? iceUrl;
  final String? closeUrl;
  final DateTime? expiresAt;
  final String? sourceCodec;
  final String? deliveryCodec;
  final List<Map<String, dynamic>> iceServers;

  String? get resolvedOfferUrl =>
      offerUrl ?? _appendPath(signalingUrl, 'offer');
  String? get resolvedIceUrl => iceUrl ?? _appendPath(signalingUrl, 'ice');

  String? get resolvedCloseUrl {
    if (closeUrl != null) return closeUrl;
    final base = signalingUrl;
    if (base == null || sessionId == null || viewerId == null) return null;
    return '${base.replaceFirst(RegExp(r'/+$'), '')}/sessions/$sessionId/viewers/$viewerId';
  }

  static Map<String, dynamic>? _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static String? _string(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) return value;
    }
    return null;
  }

  static DateTime? _dateTime(Map<String, dynamic> map, List<String> keys) {
    final value = _string(map, keys);
    return value == null ? null : DateTime.tryParse(value);
  }

  static List<Map<String, dynamic>> _iceServers(
    Map<String, dynamic> payload,
    Map<String, dynamic>? signaling,
  ) {
    final value =
        signaling?['ice_servers'] ??
        signaling?['iceServers'] ??
        payload['ice_servers'] ??
        payload['iceServers'];
    if (value is! List) return const [];
    return value
        .whereType<Map<Object?, Object?>>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }

  static String? _appendPath(String? base, String segment) {
    if (base == null || base.isEmpty) return null;
    return '${base.replaceFirst(RegExp(r'/+$'), '')}/$segment';
  }

  @override
  List<Object?> get props => [
    type,
    sessionId,
    viewerId,
    streamUrl,
    signalingUrl,
    offerUrl,
    iceUrl,
    closeUrl,
    expiresAt,
    sourceCodec,
    deliveryCodec,
    iceServers,
  ];
}

class WebRtcNegotiationResult extends Equatable {
  const WebRtcNegotiationResult({
    required this.answerSdp,
    this.answerType = 'answer',
    this.remoteCandidates = const [],
  });

  final String answerSdp;
  final String answerType;
  final List<WebRtcIceCandidateData> remoteCandidates;

  @override
  List<Object?> get props => [answerSdp, answerType, remoteCandidates];
}

class WebRtcIceCandidateData extends Equatable {
  const WebRtcIceCandidateData({
    required this.candidate,
    this.sdpMid,
    this.sdpMLineIndex,
  });

  factory WebRtcIceCandidateData.fromJson(Map<String, dynamic> json) {
    return WebRtcIceCandidateData(
      candidate: json['candidate'] as String? ?? '',
      sdpMid: json['sdpMid'] as String? ?? json['sdp_mid'] as String?,
      sdpMLineIndex:
          (json['sdpMLineIndex'] as num?)?.toInt() ??
          (json['sdp_mline_index'] as num?)?.toInt(),
    );
  }

  final String candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;

  Map<String, dynamic> toJson() => {
    'candidate': candidate,
    'sdpMid': sdpMid,
    'sdpMLineIndex': sdpMLineIndex,
  };

  @override
  List<Object?> get props => [candidate, sdpMid, sdpMLineIndex];
}
