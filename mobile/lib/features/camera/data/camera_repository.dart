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
    // Detached from backend: Return mock cameras instantly
    return _demoCameras;
  }

  static const List<Camera> _demoCameras = [
    Camera(
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
    Camera(
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
    Camera(
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

  /// Fetches signed HLS playback URL for a camera stream.
  /// Scoped by siteId and cameraId.
  Future<String> getLiveStreamUrl({
    required String siteId,
    required String cameraId,
  }) async {
    // Detached from backend: Return mock live stream URL instantly
    return 'https://playertest.longtailvideo.com/adaptive/oceans/oceans.m3u8';
  }
}

class CameraException implements Exception {
  const CameraException(this.message);

  final String message;

  @override
  String toString() => 'CameraException: $message';
}
