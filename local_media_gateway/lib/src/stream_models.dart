enum TranscodePolicy {
  always,
  auto,
  never;

  static TranscodePolicy parse(Object? value) {
    return switch (value?.toString().toLowerCase()) {
      'auto' => TranscodePolicy.auto,
      'never' => TranscodePolicy.never,
      _ => TranscodePolicy.always,
    };
  }
}

enum GatewayStreamState { starting, ready, failed, stopped }

class CreateStreamRequest {
  const CreateStreamRequest({
    required this.rtspUri,
    required this.transcodePolicy,
  });

  factory CreateStreamRequest.fromJson(Map<String, dynamic> json) {
    final rawUrl = json['rtsp_url']?.toString().trim() ?? '';
    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty ||
        (uri.scheme != 'rtsp' && uri.scheme != 'rtsps')) {
      throw const GatewayRequestException(
        'rtsp_url must be a complete rtsp:// or rtsps:// URL.',
      );
    }
    return CreateStreamRequest(
      rtspUri: uri,
      transcodePolicy: TranscodePolicy.parse(json['transcode']),
    );
  }

  final Uri rtspUri;
  final TranscodePolicy transcodePolicy;
}

class GatewayStreamInfo {
  const GatewayStreamInfo({
    required this.id,
    required this.state,
    required this.sourceCodec,
    required this.deliveryCodec,
    required this.transcoded,
    this.message,
  });

  final String id;
  final GatewayStreamState state;
  final String sourceCodec;
  final String deliveryCodec;
  final bool transcoded;
  final String? message;

  Map<String, dynamic> toJson({required String publicHost}) => {
    'id': id,
    'state': state.name,
    'source_codec': sourceCodec,
    'delivery_codec': deliveryCodec,
    'transcoded': transcoded,
    if (message != null) 'message': message,
    'public_host': publicHost,
  };
}

class GatewayRequestException implements Exception {
  const GatewayRequestException(this.message, {this.statusCode = 400});

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
