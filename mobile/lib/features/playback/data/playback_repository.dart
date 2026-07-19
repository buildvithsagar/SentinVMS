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
    // Detached from backend: Return mock timeline segments instantly
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

  /// Fetches a signed HLS playback URL for recorded footage starting at
  /// [startTime].
  Future<String> getPlaybackUrl({
    required String siteId,
    required String cameraId,
    required DateTime startTime,
  }) async {
    // Detached from backend: Return mock video stream URL instantly
    return 'https://playertest.longtailvideo.com/adaptive/oceans/oceans.m3u8';
  }
}

class PlaybackException implements Exception {
  const PlaybackException(this.message);

  final String message;

  @override
  String toString() => 'PlaybackException: $message';
}
