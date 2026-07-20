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
      sha256Hash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
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
    bool watermarked = true,
    String format = 'MP4',
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
        watermarked: watermarked,
        format: format,
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
                sha256Hash: 'd7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592',
                watermarked: currentJob.watermarked,
                format: currentJob.format,
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
                watermarked: currentJob.watermarked,
                format: currentJob.format,
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
        'recordings/$cameraId/export',
        data: <String, dynamic>{
          'start_time': startTime.toIso8601String(),
          'end_time': endTime.toIso8601String(),
          'watermark': watermarked,
          'watermark_text': 'CONFIDENTIAL - SENTINEL VMS EVIDENCE',
          'format': format,
          'reason': 'Security Incident Evidence Export',
        },
      );

      final data = response.data;
      if (data == null) {
        throw const ExportException('Received empty response from server');
      }

      final jobJson = data['data'] as Map<String, dynamic>? ?? data;

      return ExportJob(
        id: jobJson['export_id'] as String? ?? jobJson['exportId'] as String? ?? '',
        cameraId: cameraId,
        siteId: siteId,
        startTime: startTime,
        endTime: endTime,
        status: jobJson['status'] as String? ?? 'PENDING',
        progress: 0,
        createdAt: DateTime.now(),
      );
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
        'recordings/exports/$exportId',
      );

      final data = response.data;
      if (data == null) {
        throw const ExportException('Received empty response from server');
      }

      final jobJson = data['data'] as Map<String, dynamic>? ?? data;

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
        'recordings/exports',
      );

      final data = response.data;
      if (data == null) {
        throw const ExportException('Received empty response from server');
      }

      final list = data['data'] as List<dynamic>? ?? data['exports'] as List<dynamic>? ?? [data];

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
