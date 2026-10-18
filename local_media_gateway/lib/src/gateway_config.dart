import 'dart:io';

class GatewayConfig {
  const GatewayConfig({
    required this.bindAddress,
    required this.port,
    required this.ffmpegPath,
    required this.ffprobePath,
    required this.mediaMtxRtspBase,
    required this.mediaMtxHlsBase,
    required this.publicHlsPort,
    required this.publicWebRtcPort,
    required this.startupTimeout,
    required this.streamTtl,
    required this.maxStreams,
    this.apiToken,
    this.advertisedHost,
  });

  factory GatewayConfig.fromEnvironment(Map<String, String> environment) {
    return GatewayConfig(
      bindAddress: InternetAddress(
        environment['GATEWAY_BIND_ADDRESS'] ?? '0.0.0.0',
      ),
      port: _integer(environment, 'GATEWAY_PORT', 8090),
      ffmpegPath: environment['FFMPEG_PATH'] ?? 'ffmpeg',
      ffprobePath: environment['FFPROBE_PATH'] ?? 'ffprobe',
      mediaMtxRtspBase:
          environment['MEDIAMTX_RTSP_BASE'] ?? 'rtsp://mediamtx:8554',
      mediaMtxHlsBase:
          environment['MEDIAMTX_HLS_BASE'] ?? 'http://mediamtx:8888',
      publicHlsPort: _integer(environment, 'PUBLIC_HLS_PORT', 8888),
      publicWebRtcPort: _integer(environment, 'PUBLIC_WEBRTC_PORT', 8889),
      startupTimeout: Duration(
        seconds: _integer(environment, 'STREAM_START_TIMEOUT_SECONDS', 25),
      ),
      streamTtl: Duration(
        minutes: _integer(environment, 'STREAM_TTL_MINUTES', 30),
      ),
      maxStreams: _integer(environment, 'MAX_STREAMS', 4),
      apiToken: _nonEmpty(environment['GATEWAY_API_TOKEN']),
      advertisedHost: _nonEmpty(environment['GATEWAY_ADVERTISED_HOST']),
    );
  }

  final InternetAddress bindAddress;
  final int port;
  final String ffmpegPath;
  final String ffprobePath;
  final String mediaMtxRtspBase;
  final String mediaMtxHlsBase;
  final int publicHlsPort;
  final int publicWebRtcPort;
  final Duration startupTimeout;
  final Duration streamTtl;
  final int maxStreams;
  final String? apiToken;
  final String? advertisedHost;

  static int _integer(
    Map<String, String> environment,
    String key,
    int fallback,
  ) {
    return int.tryParse(environment[key] ?? '') ?? fallback;
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
