import 'package:app/features/camera/models/camera_model.dart';
import 'package:dio/dio.dart';

class CameraRepository {
  CameraRepository({
    required this.dio,
  });

  final Dio dio;

  /// Fetches cameras. Non-admin accounts have customer_id sharded implicitly.
  /// Standard GET /api/v5/cameras returns PaginatedDto<CameraResponseDto>.
  Future<List<Camera>> getCameras({String? siteId}) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/v5/cameras',
        queryParameters: <String, dynamic>{
          if (siteId != null) 'siteId': siteId,
        },
      );

      final data = response.data;
      if (data == null) {
        throw const CameraException('Received empty response from server');
      }

      final list = data['data'] as List<dynamic>?;
      if (list == null) {
        throw const CameraException('Missing data array in response');
      }

      return list
          .map((json) => Camera.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw CameraException(e.message ?? 'Failed to load cameras');
    }
  }

  /// Fetches signed HLS playback URL for a camera stream.
  /// Scoped by siteId and cameraId.
  Future<String> getLiveStreamUrl({
    required String siteId,
    required String cameraId,
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/v5/recordings/stream',
        queryParameters: <String, dynamic>{
          'siteId': siteId,
          'cameraId': cameraId,
        },
      );

      final data = response.data;
      if (data == null) {
        throw const CameraException('Received empty response from server');
      }

      final hlsUrl = data['hlsUrl'] as String?;
      if (hlsUrl == null || hlsUrl.trim().isEmpty) {
        throw const CameraException('Response missing stream URL');
      }

      return hlsUrl;
    } on DioException catch (e) {
      throw CameraException(e.message ?? 'Failed to load live stream URL');
    }
  }
}

class CameraException implements Exception {
  const CameraException(this.message);

  final String message;

  @override
  String toString() => 'CameraException: $message';
}
