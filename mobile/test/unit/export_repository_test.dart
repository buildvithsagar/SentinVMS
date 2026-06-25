import 'dart:convert';
import 'package:app/features/export/data/export_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHttpClientAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions());
  });

  group('ExportRepository', () {
    late Dio dio;
    late MockHttpClientAdapter mockAdapter;
    late ExportRepository repository;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      mockAdapter = MockHttpClientAdapter();
      dio.httpClientAdapter = mockAdapter;
      repository = ExportRepository(dio: dio);
    });

    test('createExportJob returns ExportJob on success', () async {
      final payload = {
        'data': {
          'exportId': 'exp-123',
          'cameraId': 'cam-1',
          'siteId': 'site-1',
          'startTime': '2026-06-25T12:00:00Z',
          'endTime': '2026-06-25T12:30:00Z',
          'status': 'PENDING',
          'progress': 0.0
        }
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

      final job = await repository.createExportJob(
        siteId: 'site-1',
        cameraId: 'cam-1',
        startTime: DateTime(2026, 6, 25, 12),
        endTime: DateTime(2026, 6, 25, 12, 30),
      );

      expect(job.id, 'exp-123');
      expect(job.status, 'PENDING');
      expect(job.progress, 0.0);
    });

    test('getExportStatus returns updated ExportJob on success', () async {
      final payload = {
        'data': {
          'exportId': 'exp-123',
          'cameraId': 'cam-1',
          'siteId': 'site-1',
          'startTime': '2026-06-25T12:00:00Z',
          'endTime': '2026-06-25T12:30:00Z',
          'status': 'PROCESSING',
          'progress': 0.45
        }
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

      final job = await repository.getExportStatus(exportId: 'exp-123');

      expect(job.id, 'exp-123');
      expect(job.status, 'PROCESSING');
      expect(job.progress, 0.45);
    });

    test('getExports returns list of ExportJob on success', () async {
      final payload = {
        'data': [
          {
            'exportId': 'exp-123',
            'cameraId': 'cam-1',
            'siteId': 'site-1',
            'startTime': '2026-06-25T12:00:00Z',
            'endTime': '2026-06-25T12:30:00Z',
            'status': 'COMPLETED',
            'downloadUrl': 'https://cdn.vms.io/exports/123.mp4'
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

      final jobs = await repository.getExports();

      expect(jobs.length, 1);
      expect(jobs[0].id, 'exp-123');
      expect(jobs[0].isCompleted, true);
      expect(jobs[0].downloadUrl, 'https://cdn.vms.io/exports/123.mp4');
    });
  });
}
