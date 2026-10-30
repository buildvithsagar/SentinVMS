import 'package:app/core/video/rtsp_uri.dart';

enum StreamDemoMode {
  directRtsp,
  localGateway,
  serverHls;

  String get label => switch (this) {
    StreamDemoMode.directRtsp => 'Direct RTSP',
    StreamDemoMode.localGateway => 'Smart Gateway',
    StreamDemoMode.serverHls => 'Local Server HLS',
  };

  String get description => switch (this) {
    StreamDemoMode.directRtsp =>
      'Connect directly to an H.264/H.265 CCTV stream with VLC.',
    StreamDemoMode.localGateway =>
      'Send CCTV RTSP to MediaMTX + FFmpeg, then use WebRTC with HLS fallback.',
    StreamDemoMode.serverHls =>
      'Play an HLS URL produced by MediaMTX, FFmpeg, or another server.',
  };

  String get hint => switch (this) {
    StreamDemoMode.directRtsp || StreamDemoMode.localGateway =>
      'rtsp://username:password@192.168.1.20:554/stream',
    StreamDemoMode.serverHls => 'http://192.168.1.10:8888/camera/index.m3u8',
  };
}

class StreamDemoSource {
  const StreamDemoSource({
    required this.mode,
    required this.uri,
    this.gatewayUri,
    this.gatewayToken,
    this.compatibilityMode = true,
  });

  final StreamDemoMode mode;
  final Uri uri;
  final Uri? gatewayUri;
  final String? gatewayToken;
  final bool compatibilityMode;
}

class StreamDemoSourceParser {
  const StreamDemoSourceParser._();

  /// Normalizes URLs copied from camera manuals/VLC without changing the
  /// camera path. CCTV passwords commonly contain a raw `@`; only the final
  /// `@` separates credentials from the host, so earlier occurrences are
  /// encoded as part of user-info.
  static String normalize(String value) {
    return RtspUriParser.normalize(value);
  }

  static String? validate(String? value, StreamDemoMode mode) {
    final input = normalize(value ?? '');
    if (input.isEmpty) return 'Enter a stream URL.';

    final uri = Uri.tryParse(input);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Enter a complete URL including protocol and host.';
    }

    switch (mode) {
      case StreamDemoMode.directRtsp:
      case StreamDemoMode.localGateway:
        if (uri.scheme != 'rtsp' && uri.scheme != 'rtsps') {
          return 'This mode requires an rtsp:// or rtsps:// CCTV URL.';
        }
      case StreamDemoMode.serverHls:
        if (uri.scheme != 'http' && uri.scheme != 'https') {
          return 'Server mode requires an http:// or https:// HLS URL.';
        }
        if (!uri.path.toLowerCase().endsWith('.m3u8')) {
          return 'Enter an HLS playlist URL ending in .m3u8.';
        }
    }
    return null;
  }

  static String? validateGateway(String? value) {
    final input = normalize(value ?? '');
    if (input.isEmpty) return 'Enter the local gateway URL.';
    final uri = Uri.tryParse(input);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Enter a complete http:// or https:// gateway URL.';
    }
    return null;
  }

  static StreamDemoSource? parse(
    String value,
    StreamDemoMode mode, {
    String? gatewayUrl,
    String? gatewayToken,
    bool compatibilityMode = true,
  }) {
    if (validate(value, mode) != null) return null;
    Uri? gatewayUri;
    if (mode == StreamDemoMode.localGateway) {
      if (validateGateway(gatewayUrl) != null) return null;
      gatewayUri = Uri.parse(normalize(gatewayUrl!));
    }
    return StreamDemoSource(
      mode: mode,
      uri: Uri.parse(normalize(value)),
      gatewayUri: gatewayUri,
      gatewayToken: gatewayToken?.trim(),
      compatibilityMode: compatibilityMode,
    );
  }
}
