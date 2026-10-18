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
      dio = Dio(BaseOptions(baseUrl: 'https://api.example.com/api/v5'));
      mockAdapter = MockHttpClientAdapter();
      dio.httpClientAdapter = mockAdapter;
      repository = ExportRepository(dio: dio);
    });

    test('getExports returns list of ExportJob objects', () async {
      final payload = {
        'data': [
          {
            'exportId': 'exp-101',
            'cameraId': 'cam-1',
            'siteId': 'site-1',
            'startTime': DateTime.now()
                .subtract(const Duration(hours: 2))
                .toIso8601String(),
            'endTime': DateTime.now()
                .subtract(const Duration(hours: 1))
                .toIso8601String(),
            'status': 'COMPLETED',
            'progress': 1.0,
            'downloadUrl': 'https://example.com/clip.mp4',
            'sha256Hash': 'abc123hash',
            'createdAt': DateTime.now().toIso8601String(),
          },
        ],
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

      final exports = await repository.getExports();

      expect(exports.length, 1);
      expect(exports[0].id, 'exp-101');
      expect(exports[0].status, 'COMPLETED');
    });

    test(
      'verifyClipIntegrity returns true on successful verification',
      () async {
        final responseBody = ResponseBody.fromString(
          jsonEncode({'verified': true, 'hash': 'abc123hash'}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );

        when(
          () => mockAdapter.fetch(any(), any(), any()),
        ).thenAnswer((_) async => responseBody);

        final isVerified = await repository.verifyClipIntegrity(
          jobId: 'exp-101',
        );

        expect(isVerified, true);
      },
    );
  });
}
