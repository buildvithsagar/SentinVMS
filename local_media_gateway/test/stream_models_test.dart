import 'package:sentinvms_local_media_gateway/local_media_gateway.dart';
import 'package:test/test.dart';

void main() {
  test('parses a valid RTSP create request', () {
    final request = CreateStreamRequest.fromJson({
      'rtsp_url': 'rtsp://user:pass@192.168.1.20:554/live',
      'transcode': 'auto',
    });

    expect(request.rtspUri.scheme, 'rtsp');
    expect(request.transcodePolicy, TranscodePolicy.auto);
  });

  test('rejects non-RTSP sources', () {
    expect(
      () => CreateStreamRequest.fromJson({
        'rtsp_url': 'https://example.com/video.m3u8',
      }),
      throwsA(isA<GatewayRequestException>()),
    );
  });
}
