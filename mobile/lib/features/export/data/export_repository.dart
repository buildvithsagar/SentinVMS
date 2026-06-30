import 'dart:async';
import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/core/auth/auth_state.dart';
import 'package:app/features/export/models/export_job_model.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

class ExportRepository {
  ExportRepository({
    required this.dio,
  });

  final Dio dio;

  static final List<ExportJob> _demoExports = [
    ExportJob(
      id: 'exp-a1b2c3d4-e5f6-7890-abcd-ef1234567890',
      cameraId: 'cam-front-gate',
      siteId: 'site-001',
      startTime: DateTime.now().subtract(const Duration(hours: 6)),
      endTime: DateTime.now().subtract(const Duration(hours: 5)),
      status: 'COMPLETED',
      downloadUrl: 'https://playertest.longtailvideo.com/adaptive/oceans/oceans.m3u8',
      progress: 1,
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    ExportJob(
      id: 'exp-b2c3d4e5-f6a7-8901-bcde-f12345678901',
      cameraId: 'cam-parking-b',
      siteId: 'site-001',
      startTime: DateTime.now().subtract(const Duration(hours: 3)),
      endTime: DateTime.now().subtract(const Duration(hours: 2)),
      status: 'PROCESSING',
      progress: 0.65,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  ];

  /// Creates a new video export job for the specified time range.
  Future<ExportJob> createExportJob({
    required String siteId,
    required String cameraId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    if (GetIt.instance.isRegistered<AuthBloc>()) {
      final authState = GetIt.instance<AuthBloc>().state;
      if (authState is Authenticated && authState.user.userId == 'usr-demo-operator') {
      final newJob = ExportJob(
        id: 'exp-${DateTime.now().millisecondsSinceEpoch}',
        cameraId: cameraId,
        siteId: siteId,
        startTime: startTime,
        endTime: endTime,
        status: 'PROCESSING',
        progress: 0,
        createdAt: DateTime.now(),
      );
      _demoExports.insert(0, newJob);

      Timer.periodic(const Duration(seconds: 4), (timer) {
        final idx = _demoExports.indexWhere((j) => j.id == newJob.id);
        if (idx != -1) {
          final currentJob = _demoExports[idx];
          if (currentJob.status == 'PROCESSING') {
            final nextProgress = (currentJob.progress ?? 0.0) + 0.25;
            if (nextProgress >= 1) {
              _demoExports[idx] = ExportJob(
                id: currentJob.id,
                cameraId: currentJob.cameraId,
                siteId: currentJob.siteId,
                startTime: currentJob.startTime,
                endTime: currentJob.endTime,
                status: 'COMPLETED',
                progress: 1,
                downloadUrl: 'https://playertest.longtailvideo.com/adaptive/oceans/oceans.m3u8',
                createdAt: currentJob.createdAt,
              );
              timer.cancel();
            } else {
              _demoExports[idx] = ExportJob(
                id: currentJob.id,
                cameraId: currentJob.cameraId,
                siteId: currentJob.siteId,
                startTime: currentJob.startTime,
                endTime: currentJob.endTime,
                status: 'PROCESSING',
                progress: nextProgress,
                createdAt: currentJob.createdAt,
              );
            }
          } else {
            timer.cancel();
          }
        } else {
          timer.cancel();
        }
      });

      return newJob;
    }
    }

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

  Future<ExportJob> getExportStatus({required String exportId}) async {
    if (GetIt.instance.isRegistered<AuthBloc>()) {
      final authState = GetIt.instance<AuthBloc>().state;
      if (authState is Authenticated && authState.user.userId == 'usr-demo-operator') {
      final idx = _demoExports.indexWhere((j) => j.id == exportId);
      if (idx != -1) {
        return _demoExports[idx];
      }
      return ExportJob(
        id: exportId,
        cameraId: 'cam-front-gate',
        siteId: 'site-001',
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        endTime: DateTime.now(),
        status: 'FAILED',
        createdAt: DateTime.now(),
      );
    }
    }

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
    if (GetIt.instance.isRegistered<AuthBloc>()) {
      final authState = GetIt.instance<AuthBloc>().state;
      if (authState is Authenticated && authState.user.userId == 'usr-demo-operator') {
      return _demoExports;
    }
    }

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
