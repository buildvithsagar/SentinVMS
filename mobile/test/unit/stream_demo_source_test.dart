import 'package:app/features/stream_demo/stream_demo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreamDemoSourceParser', () {
    test('accepts RTSP and RTSPS camera URLs', () {
      expect(
        StreamDemoSourceParser.validate(
          'rtsp://user:pass@192.168.1.20:554/live',
          StreamDemoMode.directRtsp,
        ),
        isNull,
      );
      expect(
        StreamDemoSourceParser.validate(
          'rtsps://camera.example.com/live',
          StreamDemoMode.directRtsp,
        ),
        isNull,
      );
    });

    test('normalizes uppercase scheme and raw at sign in password', () {
      final source = StreamDemoSourceParser.parse(
        'RTSP://admin:pass@word@camera.example.com:554/live',
        StreamDemoMode.directRtsp,
      );

      expect(source, isNotNull);
      expect(
        source!.uri.toString(),
        'rtsp://admin:pass%40word@camera.example.com:554/live',
      );
    });

    test('does not double encode an already encoded password', () {
      final source = StreamDemoSourceParser.parse(
        'rtsp://admin:pass%40word@camera.example.com/live',
        StreamDemoMode.directRtsp,
      );

      expect(
        source!.uri.toString(),
        'rtsp://admin:pass%40word@camera.example.com/live',
      );
    });

    test('rejects an HTTP URL in direct RTSP mode', () {
      expect(
        StreamDemoSourceParser.validate(
          'http://192.168.1.20/live',
          StreamDemoMode.directRtsp,
        ),
        contains('rtsp://'),
      );
    });

    test('accepts HTTP and HTTPS HLS playlist URLs', () {
      expect(
        StreamDemoSourceParser.validate(
          'http://192.168.1.10:8888/camera/index.m3u8',
          StreamDemoMode.serverHls,
        ),
        isNull,
      );
      expect(
        StreamDemoSourceParser.validate(
          'https://media.example.com/live/main.m3u8?token=abc',
          StreamDemoMode.serverHls,
        ),
        isNull,
      );
    });

    test('rejects malformed and non-HLS server URLs', () {
      expect(
        StreamDemoSourceParser.validate('', StreamDemoMode.serverHls),
        isNotNull,
      );
      expect(
        StreamDemoSourceParser.validate(
          'http://server/live.mp4',
          StreamDemoMode.serverHls,
        ),
        contains('.m3u8'),
      );
    });

    test('validates and parses local gateway input', () {
      expect(
        StreamDemoSourceParser.validate(
          'rtsp://camera.local/live',
          StreamDemoMode.localGateway,
        ),
        isNull,
      );
      expect(
        StreamDemoSourceParser.validateGateway('http://192.168.1.10:8090'),
        isNull,
      );

      final source = StreamDemoSourceParser.parse(
        'rtsp://camera.local/live',
        StreamDemoMode.localGateway,
        gatewayUrl: 'http://192.168.1.10:8090/',
        gatewayToken: ' demo-token ',
      );

      expect(source, isNotNull);
      expect(source!.gatewayUri.toString(), 'http://192.168.1.10:8090/');
      expect(source.gatewayToken, 'demo-token');
      expect(source.compatibilityMode, isTrue);
    });

    test('rejects a missing or non-HTTP gateway', () {
      expect(StreamDemoSourceParser.validateGateway(''), isNotNull);
      expect(
        StreamDemoSourceParser.validateGateway('rtsp://192.168.1.10:8090'),
        contains('http://'),
      );
    });
  });
}
