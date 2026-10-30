import 'package:app/core/video/rtsp_uri.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RtspUriParser', () {
    test('normalizes an uppercase scheme and raw @ in credentials', () {
      final uri = RtspUriParser.tryParse(
        'RTSP://admin:pass@word@camera.example.com:1554/media/video1/video',
      );

      expect(uri, isNotNull);
      expect(
        uri.toString(),
        'rtsp://admin:pass%40word@camera.example.com:1554/media/video1/video',
      );
    });

    test('does not treat an @ in the path as a credential separator', () {
      expect(
        RtspUriParser.normalize('rtsp://camera.local/live@main'),
        'rtsp://camera.local/live@main',
      );
    });

    test('sanitized labels never expose credentials', () {
      final uri = RtspUriParser.tryParse(
        'rtsp://admin:secret@camera.local:8554/live',
      )!;

      expect(
        RtspUriParser.sanitizedLabel(uri),
        'rtsp://camera.local:8554/live',
      );
      expect(RtspUriParser.sanitizedLabel(uri), isNot(contains('secret')));
    });
  });
}
