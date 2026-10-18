class LocalGatewaySession {
  const LocalGatewaySession({
    required this.id,
    required this.whepUri,
    required this.hlsUri,
    required this.sourceCodec,
    required this.deliveryCodec,
    required this.transcoded,
  });

  factory LocalGatewaySession.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final whepUri = Uri.tryParse(json['whep_url'] as String? ?? '');
    final hlsUri = Uri.tryParse(json['hls_url'] as String? ?? '');
    if (id == null ||
        id.isEmpty ||
        whepUri == null ||
        !whepUri.hasScheme ||
        hlsUri == null ||
        !hlsUri.hasScheme) {
      throw const FormatException(
        'Local gateway returned an invalid stream session.',
      );
    }
    return LocalGatewaySession(
      id: id,
      whepUri: whepUri,
      hlsUri: hlsUri,
      sourceCodec: json['source_codec'] as String? ?? 'UNKNOWN',
      deliveryCodec: json['delivery_codec'] as String? ?? 'H264',
      transcoded: json['transcoded'] as bool? ?? false,
    );
  }

  final String id;
  final Uri whepUri;
  final Uri hlsUri;
  final String sourceCodec;
  final String deliveryCodec;
  final bool transcoded;
}
