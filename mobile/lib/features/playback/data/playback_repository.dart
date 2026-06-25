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
