import 'stream_models.dart';

class FfmpegCommand {
  const FfmpegCommand({required this.arguments, required this.transcoded});

  final List<String> arguments;
  final bool transcoded;
}

class FfmpegCommandBuilder {
  const FfmpegCommandBuilder._();

  static FfmpegCommand build({
    required Uri source,
    required String destination,
    required String sourceCodec,
    required TranscodePolicy policy,
  }) {
    final codec = sourceCodec.toLowerCase();
    if (codec != 'h264' && codec != 'hevc' && codec != 'h265') {
      throw GatewayRequestException(
        'Unsupported CCTV video codec: $sourceCodec. Expected H.264 or H.265.',
        statusCode: 422,
      );
    }

    final transcode =
        policy == TranscodePolicy.always ||
        (policy == TranscodePolicy.auto && codec != 'h264');
    if (!transcode && codec != 'h264') {
      throw const GatewayRequestException(
        'H.265 cannot be delivered in compatibility mode without transcoding.',
        statusCode: 422,
      );
    }

    final arguments = <String>[
      '-hide_banner',
      '-loglevel',
      'warning',
      '-rtsp_transport',
      'tcp',
      '-timeout',
      '10000000',
      '-i',
      source.toString(),
      '-map',
      '0:v:0',
      '-an',
    ];

    if (transcode) {
      arguments.addAll(const [
        '-c:v',
        'libx264',
        '-preset',
        'ultrafast',
        '-tune',
        'zerolatency',
        '-profile:v',
        'baseline',
        '-level:v',
        '4.1',
        '-pix_fmt',
        'yuv420p',
        '-vf',
        'scale=w=1280:h=-2:force_original_aspect_ratio=decrease,fps=20',
        '-b:v',
        '2500k',
        '-maxrate',
        '3000k',
        '-bufsize',
        '5000k',
        '-bf',
        '0',
        '-g',
        '30',
        '-keyint_min',
        '30',
        '-sc_threshold',
        '0',
      ]);
    } else {
      arguments.addAll(const ['-c:v', 'copy']);
    }

    arguments.addAll(['-f', 'rtsp', '-rtsp_transport', 'tcp', destination]);
    return FfmpegCommand(arguments: arguments, transcoded: transcode);
  }
}
