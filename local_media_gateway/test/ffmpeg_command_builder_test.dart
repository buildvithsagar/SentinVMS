import 'package:sentinvms_local_media_gateway/local_media_gateway.dart';
import 'package:test/test.dart';

void main() {
  group('FfmpegCommandBuilder', () {
    const source = 'rtsp://user:pass@192.168.1.20:554/live';

    test('transcodes H265 to WebRTC-compatible H264 baseline', () {
      final command = FfmpegCommandBuilder.build(
        source: Uri.parse(source),
        destination: 'rtsp://mediamtx:8554/demo',
        sourceCodec: 'hevc',
        policy: TranscodePolicy.auto,
      );

      expect(command.transcoded, isTrue);
      expect(command.arguments, containsAllInOrder(['-timeout', '10000000']));
      expect(command.arguments, containsAllInOrder(['-c:v', 'libx264']));
      expect(command.arguments, containsAllInOrder(['-profile:v', 'baseline']));
      expect(
        command.arguments,
        containsAllInOrder([
          '-vf',
          'scale=w=1280:h=-2:force_original_aspect_ratio=decrease,fps=20',
        ]),
      );
      expect(command.arguments, containsAllInOrder(['-b:v', '2500k']));
      expect(command.arguments, containsAllInOrder(['-bf', '0']));
    });

    test('can pass H264 through in auto mode', () {
      final command = FfmpegCommandBuilder.build(
        source: Uri.parse(source),
        destination: 'rtsp://mediamtx:8554/demo',
        sourceCodec: 'h264',
        policy: TranscodePolicy.auto,
      );

      expect(command.transcoded, isFalse);
      expect(command.arguments, containsAllInOrder(['-c:v', 'copy']));
    });

    test('rejects H265 when transcoding is disabled', () {
      expect(
        () => FfmpegCommandBuilder.build(
          source: Uri.parse(source),
          destination: 'rtsp://mediamtx:8554/demo',
          sourceCodec: 'hevc',
          policy: TranscodePolicy.never,
        ),
        throwsA(isA<GatewayRequestException>()),
      );
    });
  });
}
