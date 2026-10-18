import 'package:app/features/stream_demo/stream_demo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses gateway WebRTC and HLS session URLs', () {
    final session = LocalGatewaySession.fromJson({
      'id': 'camera-a1',
      'whep_url': 'http://192.168.1.10:8889/camera-a1/whep',
      'hls_url': 'http://192.168.1.10:8888/camera-a1/index.m3u8',
      'source_codec': 'HEVC',
      'delivery_codec': 'H264',
      'transcoded': true,
    });

    expect(session.id, 'camera-a1');
    expect(session.whepUri.path, '/camera-a1/whep');
    expect(session.hlsUri.path, '/camera-a1/index.m3u8');
    expect(session.sourceCodec, 'HEVC');
    expect(session.deliveryCodec, 'H264');
    expect(session.transcoded, isTrue);
  });

  test('rejects a gateway response without usable playback URLs', () {
    expect(
      () => LocalGatewaySession.fromJson({
        'id': 'camera-a1',
        'whep_url': '',
        'hls_url': '',
      }),
      throwsFormatException,
    );
  });
}
