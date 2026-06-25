import 'dart:convert';
import 'package:app/features/playback/data/playback_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHttpClientAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions());
  });

  group('PlaybackRepository', () {
    late Dio dio;
    late MockHttpClientAdapter mockAdapter;
    late PlaybackRepository repository;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      mockAdapter = MockHttpClientAdapter();
      dio.httpClientAdapter = mockAdapter;
      repository = PlaybackRepository(dio: dio);
    });

    test('getRecordingSegments returns list of RecordingSegment objects on success', () async {
      final payload = {
        'data': [
          {
            'segmentId': 'seg-1',
            'siteId': 'site-1',
            'cameraId': 'cam-1',
            'startTime': '2026-06-25T12:00:00Z',
            'endTime': '2026-06-25T13:00:00Z',
            'type': 'CONTINUOUS'
          },
          {
            'segmentId': 'seg-2',
            'siteId': 'site-1',
            'cameraId': 'cam-1',
            'startTime': '2026-06-25T14:00:00Z',
            'endTime': '2026-06-25T14:30:00Z',
            'type': 'MOTION'
          }
        ]
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

      final segments = await repository.getRecordingSegments(
        siteId: 'site-1',
        cameraId: 'cam-1',
        date: DateTime(2026, 6, 25),
      );

      expect(segments.length, 2);
      expect(segments[0].id, 'seg-1');
      expect(segments[0].type, 'CONTINUOUS');
      expect(segments[1].id, 'seg-2');
      expect(segments[1].type, 'MOTION');
    });

    test('getPlaybackUrl returns hlsUrl on success', () async {
      final payload = {
        'hlsUrl': 'https://stream.vms.io/playback/cam-1.m3u8'
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

      final url = await repository.getPlaybackUrl(
        siteId: 'site-1',
        cameraId: 'cam-1',
        startTime: DateTime(2026, 6, 25, 12),
      );

      expect(url, 'https://stream.vms.io/playback/cam-1.m3u8');
    });

    test('getRecordingSegments throws PlaybackException when response fails', () async {
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
        () => repository.getRecordingSegments(
          siteId: 'site-1',
          cameraId: 'cam-1',
          date: DateTime(2026, 6, 25),
        ),
        throwsA(isA<PlaybackException>()),
      );
    });
  });
}
