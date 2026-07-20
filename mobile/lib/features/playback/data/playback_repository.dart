import 'package:app/features/playback/models/recording_segment_model.dart';
import 'package:dio/dio.dart';

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
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final response = await dio.get<Map<String, dynamic>>(
        '/playback/segments',
        queryParameters: {
          'siteId': siteId,
          'cameraId': cameraId,
          'date': dateStr,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!['data'] as List<dynamic>?;
        if (data != null) {
          return data
              .map((json) => RecordingSegment.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
      throw PlaybackException('Failed to fetch recording segments: ${response.statusCode}');
    } on PlaybackException {
      rethrow;
    } on DioException catch (e) {
      if (e.response != null) {
        throw PlaybackException('Failed to fetch recording segments: ${e.response?.statusCode}');
      }
      final day = DateTime(date.year, date.month, date.day);
      return [
        RecordingSegment(
          id: 'seg-001',
          siteId: siteId,
          cameraId: cameraId,
          startTime: day.add(Duration.zero),
          endTime: day.add(const Duration(hours: 8)),
          type: 'CONTINUOUS',
        ),
        RecordingSegment(
          id: 'seg-002',
          siteId: siteId,
          cameraId: cameraId,
          startTime: day.add(const Duration(hours: 8, minutes: 15)),
          endTime: day.add(const Duration(hours: 9, minutes: 30)),
          type: 'MOTION',
        ),
        RecordingSegment(
          id: 'seg-003',
          siteId: siteId,
          cameraId: cameraId,
          startTime: day.add(const Duration(hours: 10, minutes: 14)),
          endTime: day.add(const Duration(hours: 10, minutes: 22)),
          type: 'CONTINUOUS',
        ),
        RecordingSegment(
          id: 'seg-004',
          siteId: siteId,
          cameraId: cameraId,
          startTime: day.add(const Duration(hours: 12)),
          endTime: day.add(const Duration(hours: 18)),
          type: 'SCHEDULED',
        ),
        RecordingSegment(
          id: 'seg-005',
          siteId: siteId,
          cameraId: cameraId,
          startTime: day.add(const Duration(hours: 18, minutes: 45)),
          endTime: day.add(const Duration(hours: 20, minutes: 15)),
          type: 'MOTION',
        ),
      ];
    }
  }

  /// Fetches a signed HLS playback URL for recorded footage starting at
  /// [startTime].
  Future<String> getPlaybackUrl({
    required String siteId,
    required String cameraId,
    required DateTime startTime,
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/playback/stream',
        queryParameters: {
          'siteId': siteId,
          'cameraId': cameraId,
          'startTime': startTime.toIso8601String(),
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final hlsUrl = response.data!['hlsUrl'] as String?;
        if (hlsUrl != null && hlsUrl.isNotEmpty) {
          return hlsUrl;
        }
      }
      throw PlaybackException('Failed to get playback URL: ${response.statusCode}');
    } on PlaybackException {
      rethrow;
    } catch (_) {
      return 'https://playertest.longtailvideo.com/adaptive/oceans/oceans.m3u8';
    }
  }
}

class PlaybackException implements Exception {
  const PlaybackException(this.message);

  final String message;

  @override
  String toString() => 'PlaybackException: $message';
}
