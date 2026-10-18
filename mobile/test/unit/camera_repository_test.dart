import 'dart:convert';
import 'package:app/features/camera/data/camera_repository.dart';
import 'package:app/features/camera/models/live_stream_session.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHttpClientAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions());
  });

  group('CameraRepository', () {
    late Dio dio;
    late MockHttpClientAdapter mockAdapter;
    late CameraRepository repository;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://api.example.com/api/v5'));
      mockAdapter = MockHttpClientAdapter();
      dio.httpClientAdapter = mockAdapter;
      repository = CameraRepository(dio: dio);
    });

    test('getCameras returns list of Camera objects on success', () async {
      final payload = {
        'data': [
          {
            'cameraId': 'camera-1',
            'siteId': 'site-123',
            'name': 'Main Gate',
            'ipAddress': '192.168.1.100',
            'rtspUrl': 'rtsp://...',
            'onvifProfile': 'S',
            'codec': 'H264',
            'ptzCapable': true,
            'status': 'CONNECTED',
          },
          {
            'cameraId': 'camera-2',
            'siteId': 'site-123',
            'name': 'Exit Gate',
            'ipAddress': '192.168.1.101',
            'rtspUrl': 'rtsp://...',
            'onvifProfile': 'T',
            'codec': 'H265',
            'ptzCapable': false,
            'status': 'DISCONNECTED',
          },
        ],
        'total': 2,
        'page': 1,
        'limit': 100,
      };

      final responseBody = ResponseBody.fromString(
        jsonEncode(payload),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

      when(
        () => mockAdapter.fetch(any(), any(), any()),
      ).thenAnswer((_) async => responseBody);

      final cameras = await repository.getCameras(siteId: 'site-123');

      expect(cameras.length, 2);
      expect(cameras[0].id, 'camera-1');
      expect(cameras[0].name, 'Main Gate');
      expect(cameras[0].status, 'CONNECTED');
      expect(cameras[0].ptzCapable, true);
      expect(cameras[1].id, 'camera-2');
      expect(cameras[1].codec, 'H265');
      expect(cameras[1].status, 'DISCONNECTED');
    });

    test('getCameras reuses the short-lived shared cache', () async {
      final responseBody = ResponseBody.fromString(
        jsonEncode({
          'data': [
            {
              'cameraId': 'camera-1',
              'siteId': 'site-123',
              'name': 'Main Gate',
              'ipAddress': '192.168.1.100',
              'rtspUrl': 'rtsp://camera/live',
              'onvifProfile': 'S',
              'codec': 'H264',
              'ptzCapable': true,
              'status': 'CONNECTED',
            },
          ],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
      when(
        () => mockAdapter.fetch(any(), any(), any()),
      ).thenAnswer((_) async => responseBody);

      await repository.getCameras();
      await repository.getCameras();

      verify(() => mockAdapter.fetch(any(), any(), any())).called(1);
    });

    test(
      'getCameras throws CameraException when server returns non-200 code',
      () async {
        final responseBody = ResponseBody.fromString(
          'Internal Server Error',
          500,
          headers: {
            Headers.contentTypeHeader: const ['text/plain'],
          },
        );

        when(
          () => mockAdapter.fetch(any(), any(), any()),
        ).thenAnswer((_) async => responseBody);

        expect(() => repository.getCameras(), throwsA(isA<CameraException>()));
      },
    );

    test('getCameras throws CameraException when response is empty', () async {
      final responseBody = ResponseBody.fromString(
        jsonEncode({}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

      when(
        () => mockAdapter.fetch(any(), any(), any()),
      ).thenAnswer((_) async => responseBody);

      expect(() => repository.getCameras(), throwsA(isA<CameraException>()));
    });

    test('getLiveStreamSession parses WebRTC signaling contract', () async {
      final responseBody = ResponseBody.fromString(
        jsonEncode({
          'type': 'webrtc',
          'session_id': 'session-1',
          'viewer_id': 'viewer-1',
          'source_codec': 'H265',
          'delivery_codec': 'H264',
          'signaling': {
            'url': '/media/signaling',
            'ice_servers': [
              {
                'urls': ['stun:stun.example.com:3478'],
              },
            ],
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
      when(
        () => mockAdapter.fetch(any(), any(), any()),
      ).thenAnswer((_) async => responseBody);

      final session = await repository.getLiveStreamSession(
        cameraId: 'camera-1',
        type: StreamType.webrtc,
      );

      expect(session.type, StreamType.webrtc);
      expect(session.sessionId, 'session-1');
      expect(session.viewerId, 'viewer-1');
      expect(session.sourceCodec, 'H265');
      expect(session.deliveryCodec, 'H264');
      expect(session.resolvedOfferUrl, '/media/signaling/offer');
      expect(session.iceServers, hasLength(1));
    });

    test('getLiveStreamSession parses signed HLS response', () async {
      final responseBody = ResponseBody.fromString(
        jsonEncode({
          'data': {
            'type': 'hls',
            'stream_url': 'https://media.example.com/live/camera-1.m3u8',
            'expires_at': '2026-10-15T12:00:00Z',
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
      when(
        () => mockAdapter.fetch(any(), any(), any()),
      ).thenAnswer((_) async => responseBody);

      final session = await repository.getLiveStreamSession(
        cameraId: 'camera-1',
        type: StreamType.hls,
      );

      expect(session.type, StreamType.hls);
      expect(session.streamUrl, 'https://media.example.com/live/camera-1.m3u8');
      expect(session.expiresAt, DateTime.utc(2026, 10, 15, 12));
    });

    test('exchangeWebRtcOffer parses SDP answer and ICE candidates', () async {
      final responseBody = ResponseBody.fromString(
        jsonEncode({
          'answer': {'type': 'answer', 'sdp': 'v=0\r\nanswer'},
          'ice_candidates': [
            {
              'candidate': 'candidate:1 1 UDP 1 192.0.2.1 5000 typ host',
              'sdpMid': '0',
              'sdpMLineIndex': 0,
            },
          ],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
      when(
        () => mockAdapter.fetch(any(), any(), any()),
      ).thenAnswer((_) async => responseBody);

      final result = await repository.exchangeWebRtcOffer(
        session: const LiveStreamSession(
          type: StreamType.webrtc,
          offerUrl: '/media/session-1/offer',
        ),
        sdp: 'v=0\r\noffer',
      );

      expect(result.answerType, 'answer');
      expect(result.answerSdp, 'v=0\r\nanswer');
      expect(result.remoteCandidates, hasLength(1));
      expect(result.remoteCandidates.single.sdpMLineIndex, 0);
    });

    test('movePtz dispatches POST command successfully', () async {
      final responseBody = ResponseBody.fromString(
        jsonEncode({'success': true}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

      when(
        () => mockAdapter.fetch(any(), any(), any()),
      ).thenAnswer((_) async => responseBody);

      await expectLater(
        repository.movePtz(
          siteId: 'site-1',
          cameraId: 'cam-1',
          direction: 'up',
        ),
        completes,
      );
    });

    test('zoomPtz dispatches POST command successfully', () async {
      final responseBody = ResponseBody.fromString(
        jsonEncode({'success': true}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

      when(
        () => mockAdapter.fetch(any(), any(), any()),
      ).thenAnswer((_) async => responseBody);

      await expectLater(
        repository.zoomPtz(siteId: 'site-1', cameraId: 'cam-1', zoomMode: 'in'),
        completes,
      );
    });

    test('dispatchEmergencyPanic posts emergency alert successfully', () async {
      final responseBody = ResponseBody.fromString(
        jsonEncode({'status': 'DISPATCHED', 'alertId': 'alt-999'}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

      when(
        () => mockAdapter.fetch(any(), any(), any()),
      ).thenAnswer((_) async => responseBody);

      await expectLater(
        repository.dispatchEmergencyPanic(
          protocol: 'EMERGENCY SIREN',
          operatorId: 'operator-123',
        ),
        completes,
      );
    });

    test('presetPtz dispatches POST command successfully', () async {
      final responseBody = ResponseBody.fromString(
        jsonEncode({'success': true}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

      when(
        () => mockAdapter.fetch(any(), any(), any()),
      ).thenAnswer((_) async => responseBody);

      await expectLater(
        repository.presetPtz(siteId: 'site-1', cameraId: 'cam-1', presetId: 1),
        completes,
      );
    });
  });
}
