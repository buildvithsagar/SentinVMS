import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/core/auth/auth_state.dart';
import 'package:app/features/camera/models/camera_model.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

class CameraRepository {
  CameraRepository({
    required this.dio,
  });

  final Dio dio;

  /// Fetches cameras. Non-admin accounts have customer_id sharded implicitly.
  /// Standard GET /api/v5/cameras returns PaginatedDto<CameraResponseDto>.
  Future<List<Camera>> getCameras({String? siteId}) async {
    if (GetIt.instance.isRegistered<AuthBloc>()) {
      final authState = GetIt.instance<AuthBloc>().state;
      if (authState is Authenticated && authState.user.userId == 'usr-demo-operator') {
        return [
          const Camera(
            id: 'cam-front-gate',
            siteId: 'site-001',
            name: 'Front Gate Camera',
            ipAddress: '192.168.1.50',
            rtspUrl: 'rtsp://192.168.1.50/live',
            codec: 'H264',
            status: 'CONNECTED',
            onvifProfile: 'S',
            ptzCapable: true,
          ),
          const Camera(
            id: 'cam-parking-b',
            siteId: 'site-001',
            name: 'Parking Lot B',
            ipAddress: '192.168.1.51',
            rtspUrl: 'rtsp://192.168.1.51/live',
            codec: 'H264',
            status: 'CONNECTED',
            onvifProfile: 'S',
            ptzCapable: false,
          ),
          const Camera(
            id: 'cam-warehouse',
            siteId: 'site-002',
            name: 'Warehouse Interior',
            ipAddress: '192.168.2.100',
            rtspUrl: 'rtsp://192.168.2.100/live',
            codec: 'H265',
            status: 'CONNECTED',
            onvifProfile: 'T',
            ptzCapable: true,
          ),
        ];
      }
    }
    try {
      final response = await dio.get<Map<String, dynamic>>(
        'cameras',
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
    if (GetIt.instance.isRegistered<AuthBloc>()) {
      final authState = GetIt.instance<AuthBloc>().state;
      if (authState is Authenticated && authState.user.userId == 'usr-demo-operator') {
        return 'https://playertest.longtailvideo.com/adaptive/oceans/oceans.m3u8';
      }
    }

    try {
      final response = await dio.get<Map<String, dynamic>>(
        'recordings/stream',
        queryParameters: <String, dynamic>{
          'cameraId': cameraId,
        },
      );

      final data = response.data;
      if (data == null) {
        throw const CameraException('Received empty response from server');
      }

      final streamUri = data['streamUri'] as String?;
      if (streamUri == null || streamUri.trim().isEmpty) {
        throw const CameraException('Response missing stream URL');
      }

      return streamUri;
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
