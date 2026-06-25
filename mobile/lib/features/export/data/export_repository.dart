import 'package:app/features/export/models/export_job_model.dart';
import 'package:dio/dio.dart';

class ExportRepository {
  ExportRepository({
    required this.dio,
  });

  final Dio dio;

  /// Creates a new video export job for the specified time range.
  Future<ExportJob> createExportJob({
    required String siteId,
    required String cameraId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/api/v5/exports',
        data: <String, dynamic>{
          'siteId': siteId,
          'cameraId': cameraId,
          'startTime': startTime.toIso8601String(),
          'endTime': endTime.toIso8601String(),
        },
      );

      final data = response.data;
      if (data == null) {
        throw const ExportException('Received empty response from server');
      }

      final jobJson = data['data'] as Map<String, dynamic>?;
      if (jobJson == null) {
        throw const ExportException('Missing data in response');
      }

      return ExportJob.fromJson(jobJson);
    } on DioException catch (e) {
      throw ExportException(e.message ?? 'Failed to create export job');
    }
  }

  /// Polls the current status of an export job.
  Future<ExportJob> getExportStatus({required String exportId}) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/v5/exports/$exportId',
      );

      final data = response.data;
      if (data == null) {
        throw const ExportException('Received empty response from server');
      }

      final jobJson = data['data'] as Map<String, dynamic>?;
      if (jobJson == null) {
        throw const ExportException('Missing data in response');
      }

      return ExportJob.fromJson(jobJson);
    } on DioException catch (e) {
      throw ExportException(e.message ?? 'Failed to load export status');
    }
  }

  /// Fetches all export jobs for the authenticated user.
  Future<List<ExportJob>> getExports() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/v5/exports',
      );

      final data = response.data;
      if (data == null) {
        throw const ExportException('Received empty response from server');
      }

      final list = data['data'] as List<dynamic>?;
      if (list == null) {
        throw const ExportException('Missing data array in response');
      }

      return list
          .map((json) => ExportJob.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ExportException(e.message ?? 'Failed to load exports');
    }
  }
}

class ExportException implements Exception {
  const ExportException(this.message);

  final String message;

  @override
  String toString() => 'ExportException: $message';
}
