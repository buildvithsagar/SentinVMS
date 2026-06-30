import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/core/auth/auth_state.dart';
import 'package:app/features/playback/models/recording_segment_model.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

class PlaybackRepository {
  PlaybackRepository({
    required this.dio,
  });

  final Dio dio;

  /// Fetches recording segments for a camera on a given date.
  /// Returns timeline segments used to render the playback scrubber.
  Future<List<RecordingSegment>> getRecordingSegments({
    required String siteId,
    required String cameraId,
    required DateTime date,
  }) async {
    if (GetIt.instance.isRegistered<AuthBloc>()) {
      final authState = GetIt.instance<AuthBloc>().state;
      if (authState is Authenticated && authState.user.userId == 'usr-demo-operator') {
      final day = DateTime(date.year, date.month, date.day);
      return [
        RecordingSegment(
          id: 'seg-001',
          siteId: siteId,
          cameraId: cameraId,
          startTime: day.add(const Duration(hours: 2)),
          endTime: day.add(const Duration(hours: 6)),
          type: 'CONTINUOUS',
        ),
        RecordingSegment(
          id: 'seg-002',
          siteId: siteId,
          cameraId: cameraId,
          startTime: day.add(const Duration(hours: 9, minutes: 30)),
          endTime: day.add(const Duration(hours: 11, minutes: 15)),
          type: 'MOTION',
        ),
        RecordingSegment(
          id: 'seg-003',
          siteId: siteId,
          cameraId: cameraId,
          startTime: day.add(const Duration(hours: 15)),
          endTime: day.add(const Duration(hours: 19, minutes: 45)),
          type: 'SCHEDULED',
        ),
      ];
    }
    }

    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/v5/recordings/segments',
        queryParameters: <String, dynamic>{
          'siteId': siteId,
          'cameraId': cameraId,
          'date': date.toIso8601String().split('T').first,
        },
      );

      final data = response.data;
      if (data == null) {
        throw const PlaybackException('Received empty response from server');
      }

      final list = data['data'] as List<dynamic>?;
      if (list == null) {
        throw const PlaybackException('Missing data array in response');
      }

      return list
          .map(
            (json) => RecordingSegment.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw PlaybackException(
        e.message ?? 'Failed to load recording segments',
      );
    }
  }

  /// Fetches a signed HLS playback URL for recorded footage starting at
  /// [startTime].
  Future<String> getPlaybackUrl({
    required String siteId,
    required String cameraId,
    required DateTime startTime,
  }) async {
    if (GetIt.instance.isRegistered<AuthBloc>()) {
      final authState = GetIt.instance<AuthBloc>().state;
      if (authState is Authenticated && authState.user.userId == 'usr-demo-operator') {
      return 'https://playertest.longtailvideo.com/adaptive/oceans/oceans.m3u8';
    }
    }

    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/v5/recordings/playback',
        queryParameters: <String, dynamic>{
          'siteId': siteId,
          'cameraId': cameraId,
          'startTime': startTime.toIso8601String(),
        },
      );

      final data = response.data;
      if (data == null) {
        throw const PlaybackException('Received empty response from server');
      }

      final hlsUrl = data['hlsUrl'] as String?;
      if (hlsUrl == null || hlsUrl.trim().isEmpty) {
        throw const PlaybackException('Response missing playback URL');
      }

      return hlsUrl;
    } on DioException catch (e) {
      throw PlaybackException(e.message ?? 'Failed to load playback URL');
    }
  }
}

class PlaybackException implements Exception {
  const PlaybackException(this.message);

  final String message;

  @override
  String toString() => 'PlaybackException: $message';
}
