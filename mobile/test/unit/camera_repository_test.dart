import 'dart:convert';
import 'package:app/features/camera/data/camera_repository.dart';
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
            'status': 'CONNECTED'
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
            'status': 'DISCONNECTED'
          }
        ],
        'total': 2,
        'page': 1,
        'limit': 100
      };

      final responseBody = ResponseBody.fromString(
        jsonEncode(payload),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

      when(() => mockAdapter.fetch(any(), any(), any()))
          .thenAnswer((_) async => responseBody);

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

    test('getCameras throws CameraException when server returns non-200 code', () async {
      final responseBody = ResponseBody.fromString(
        'Internal Server Error',
        500,
        headers: {
          Headers.contentTypeHeader: const ['text/plain'],
        },
      );

      when(() => mockAdapter.fetch(any(), any(), any()))
          .thenAnswer((_) async => responseBody);

      expect(
        () => repository.getCameras(),
        throwsA(isA<CameraException>()),
      );
    });

    test('getCameras throws CameraException when response is empty', () async {
      final responseBody = ResponseBody.fromString(
        jsonEncode({}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

      when(() => mockAdapter.fetch(any(), any(), any()))
          .thenAnswer((_) async => responseBody);

      expect(
        () => repository.getCameras(),
        throwsA(isA<CameraException>()),
      );
    });
  });
}
