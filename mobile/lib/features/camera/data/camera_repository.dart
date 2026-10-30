import 'package:app/features/camera/data/local_camera_store.dart';
import 'package:app/features/camera/models/camera_model.dart';
import 'package:app/features/camera/models/live_stream_session.dart';
import 'package:dio/dio.dart';

class CameraRepository {
  CameraRepository({
    required this.dio,
    this.demoMode = false,
    this.cacheTtl = const Duration(seconds: 30),
    this.localCameraStore,
  });

  final Dio dio;
  final bool demoMode;
  final Duration cacheTtl;
  final LocalCameraStore? localCameraStore;
  final Map<String, _CameraCacheEntry> _cache = {};
  final Map<String, Future<List<Camera>>> _inFlightRequests = {};

  /// Fetches cameras. Non-admin accounts have customer_id sharded implicitly.
  /// Standard GET /api/v5/cameras returns PaginatedDto<CameraResponseDto>.
  Future<List<Camera>> getCameras({
    String? siteId,
    bool forceRefresh = false,
  }) async {
    final localCameras =
        await localCameraStore?.getCameras() ?? const <Camera>[];
    final visibleLocal = siteId == null
        ? localCameras
        : localCameras.where((camera) => camera.siteId == siteId).toList();

    if (demoMode) {
      final demoCameras = siteId == null
          ? _demoCameras
          : _demoCameras.where((camera) => camera.siteId == siteId);
      return List<Camera>.unmodifiable([...visibleLocal, ...demoCameras]);
    }

    try {
      final remote = await _getRemoteCameras(
        siteId: siteId,
        forceRefresh: forceRefresh,
      );
      return List<Camera>.unmodifiable([...visibleLocal, ...remote]);
    } on CameraException {
      if (visibleLocal.isNotEmpty) {
        return List<Camera>.unmodifiable(visibleLocal);
      }
      rethrow;
    }
  }

  Future<List<Camera>> _getRemoteCameras({
    String? siteId,
    bool forceRefresh = false,
  }) {
    final cacheKey = siteId ?? '*';
    final cached = _cache[cacheKey];
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.loadedAt) < cacheTtl) {
      return Future.value(cached.cameras);
    }

    final pending = _inFlightRequests[cacheKey];
    if (!forceRefresh && pending != null) return pending;

    final request = _fetchCameras(siteId: siteId)
        .then((cameras) {
          final stableResult = List<Camera>.unmodifiable(cameras);
          _cache[cacheKey] = _CameraCacheEntry(
            cameras: stableResult,
            loadedAt: DateTime.now(),
          );
          return stableResult;
        })
        .whenComplete(() {
          // Do not return the removed Future here. Returning the same in-flight
          // Future makes whenComplete wait on itself and deadlocks the request.
          _inFlightRequests.remove(cacheKey);
        });
    _inFlightRequests[cacheKey] = request;
    return request;
  }

  Future<Camera> addLocalCamera({
    required String name,
    required Uri rtspUri,
    required String codec,
    Uri? subStreamUri,
  }) async {
    final store = localCameraStore;
    if (store == null) {
      throw const CameraException('Local camera storage is unavailable.');
    }
    final camera = await store.addCamera(
      name: name,
      rtspUri: rtspUri,
      codec: codec,
      subStreamUri: subStreamUri,
    );
    invalidateCameraCache();
    return camera;
  }

  Future<void> deleteLocalCamera(String cameraId) async {
    final store = localCameraStore;
    if (store == null || !cameraId.startsWith('local-rtsp-')) return;
    await store.deleteCamera(cameraId);
    invalidateCameraCache();
  }

  Future<List<Camera>> _fetchCameras({String? siteId}) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        'cameras',
        queryParameters: siteId != null ? {'siteId': siteId} : null,
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!['data'] as List<dynamic>?;
        if (data != null && data.isNotEmpty) {
          return data
              .map((json) => Camera.fromJson(json as Map<String, dynamic>))
              .toList();
        }
        throw const CameraException(
          'No camera streams registered for this site.',
        );
      }
      throw CameraException('Failed to fetch cameras: ${response.statusCode}');
    } on CameraException {
      rethrow;
    } on DioException catch (e) {
      throw CameraException(
        e.response != null
            ? 'Failed to fetch cameras: ${e.response?.statusCode}'
            : e.message ?? 'Unable to reach the camera service.',
      );
    }
  }

  void invalidateCameraCache() => _cache.clear();

  static const List<Camera> _demoCameras = [
    Camera(
      id: 'cam-001',
      siteId: 'site-hq',
      name: 'CAM-01 | Main Entrance - Turnstile Gate',
      ipAddress: '10.0.1.50',
      rtspUrl: 'rtsp://10.0.1.50:554/live/ch1',
      codec: 'H264',
      status: 'CONNECTED',
      onvifProfile: 'S',
      ptzCapable: true,
    ),
    Camera(
      id: 'cam-002',
      siteId: 'site-hq',
      name: 'CAM-02 | Executive Lobby & Elevators',
      ipAddress: '10.0.1.51',
      rtspUrl: 'rtsp://10.0.1.51:554/live/ch1',
      codec: 'H264',
      status: 'CONNECTED',
      onvifProfile: 'S',
      ptzCapable: false,
    ),
    Camera(
      id: 'cam-003',
      siteId: 'site-hq',
      name: 'CAM-03 | Executive Parking - VIP Zone',
      ipAddress: '10.0.1.52',
      rtspUrl: 'rtsp://10.0.1.52:554/live/ch1',
      codec: 'H264',
      status: 'CONNECTED',
      onvifProfile: 'S',
      ptzCapable: true,
    ),
    Camera(
      id: 'cam-004',
      siteId: 'site-warehouse',
      name: 'CAM-04 | Loading Dock - Bay 3',
      ipAddress: '10.0.2.100',
      rtspUrl: 'rtsp://10.0.2.100:554/live/ch1',
      codec: 'H265',
      status: 'CONNECTED',
      onvifProfile: 'T',
      ptzCapable: true,
    ),
    Camera(
      id: 'cam-005',
      siteId: 'site-warehouse',
      name: 'CAM-05 | High-Value Goods Vault',
      ipAddress: '10.0.2.101',
      rtspUrl: 'rtsp://10.0.2.101:554/live/ch1',
      codec: 'H265',
      status: 'CONNECTED',
      onvifProfile: 'T',
      ptzCapable: false,
    ),
    Camera(
      id: 'cam-006',
      siteId: 'site-datacenter',
      name: 'CAM-06 | Server Rack Aisle 4 (Cold Corridor)',
      ipAddress: '10.0.3.200',
      rtspUrl: 'rtsp://10.0.3.200:554/live/ch1',
      codec: 'H265',
      status: 'CONNECTED',
      onvifProfile: 'T',
      ptzCapable: true,
    ),
    Camera(
      id: 'cam-007',
      siteId: 'site-hq',
      name: 'CAM-07 | Perimeter North Fence Line',
      ipAddress: '10.0.1.53',
      rtspUrl: 'rtsp://10.0.1.53:554/live/ch1',
      codec: 'H264',
      status: 'CONNECTED',
      onvifProfile: 'S',
      ptzCapable: true,
    ),
    Camera(
      id: 'cam-008',
      siteId: 'site-hq',
      name: 'CAM-08 | Cafeteria & Staff Lounge',
      ipAddress: '10.0.1.54',
      rtspUrl: 'rtsp://10.0.1.54:554/live/ch1',
      codec: 'H264',
      status: 'CONNECTED',
      onvifProfile: 'S',
      ptzCapable: false,
    ),
    Camera(
      id: 'cam-009',
      siteId: 'site-datacenter',
      name: 'CAM-09 | Main Backup Generator Room',
      ipAddress: '10.0.3.201',
      rtspUrl: 'rtsp://10.0.3.201:554/live/ch1',
      codec: 'H265',
      status: 'CONNECTED',
      onvifProfile: 'T',
      ptzCapable: true,
    ),
  ];

  /// Requests an authorized live media session from the control plane.
  ///
  /// The backend remains responsible for camera credentials, tenant scoping,
  /// Edge assignment, and MediaCore session orchestration. Flutter receives
  /// only a WebRTC signaling descriptor or a short-lived HLS URL.
  Future<LiveStreamSession> getLiveStreamSession({
    required String cameraId,
    required StreamType type,
    String quality = 'main',
  }) async {
    if (demoMode) {
      if (type == StreamType.webrtc) {
        throw const CameraException(
          'WebRTC control-plane sessions are unavailable in demo mode.',
        );
      }
      return LiveStreamSession(
        type: StreamType.hls,
        streamUrl: _demoStreamUrl(cameraId),
        sourceCodec: 'DEMO',
        deliveryCodec: 'H264',
      );
    }
    try {
      final response = await dio.get<Map<String, dynamic>>(
        'cameras/$cameraId/stream',
        queryParameters: {'type': type.apiValue, 'quality': quality},
      );
      final data = response.data;
      if (response.statusCode == 200 && data != null) {
        final session = LiveStreamSession.fromJson(data, requestedType: type);
        if (type == StreamType.hls &&
            (session.streamUrl == null || session.streamUrl!.isEmpty)) {
          throw const CameraException('HLS response is missing stream_url.');
        }
        if (type == StreamType.webrtc && session.resolvedOfferUrl == null) {
          throw const CameraException(
            'WebRTC response is missing signaling information.',
          );
        }
        return session;
      }
      throw CameraException(
        'Failed to create ${type.apiValue} session: ${response.statusCode}',
      );
    } on CameraException {
      rethrow;
    } on DioException catch (error) {
      throw CameraException(
        error.response?.data?.toString() ??
            error.message ??
            'Failed to create ${type.apiValue} session.',
      );
    }
  }

  Future<WebRtcNegotiationResult> exchangeWebRtcOffer({
    required LiveStreamSession session,
    required String sdp,
    String type = 'offer',
  }) async {
    final offerUrl = session.resolvedOfferUrl;
    if (offerUrl == null) {
      throw const CameraException('WebRTC offer URL is unavailable.');
    }

    try {
      final response = await dio.post<Map<String, dynamic>>(
        offerUrl,
        data: {
          'session_id': session.sessionId,
          'viewer_id': session.viewerId,
          'sdp': sdp,
          'type': type,
        },
      );
      final root = response.data;
      if (root == null) {
        throw const CameraException('WebRTC offer returned an empty body.');
      }
      final payload = root['data'] is Map
          ? Map<String, dynamic>.from(root['data'] as Map)
          : root;
      final answer = payload['answer'] is Map
          ? Map<String, dynamic>.from(payload['answer'] as Map)
          : payload;
      final answerSdp =
          answer['sdp'] as String? ??
          payload['answer_sdp'] as String? ??
          payload['answerSdp'] as String?;
      if (answerSdp == null || answerSdp.isEmpty) {
        throw const CameraException('WebRTC response is missing answer SDP.');
      }
      final rawCandidates =
          payload['ice_candidates'] as List<dynamic>? ??
          payload['iceCandidates'] as List<dynamic>? ??
          const <dynamic>[];
      return WebRtcNegotiationResult(
        answerSdp: answerSdp,
        answerType: answer['type'] as String? ?? 'answer',
        remoteCandidates: rawCandidates
            .whereType<Map<Object?, Object?>>()
            .map(
              (candidate) => WebRtcIceCandidateData.fromJson(
                Map<String, dynamic>.from(candidate),
              ),
            )
            .where((candidate) => candidate.candidate.isNotEmpty)
            .toList(),
      );
    } on CameraException {
      rethrow;
    } on DioException catch (error) {
      throw CameraException(
        error.response?.data?.toString() ??
            error.message ??
            'WebRTC negotiation failed.',
      );
    }
  }

  Future<void> sendWebRtcIceCandidate({
    required LiveStreamSession session,
    required WebRtcIceCandidateData candidate,
  }) async {
    final iceUrl = session.resolvedIceUrl;
    if (iceUrl == null) return;
    await dio.post<void>(
      iceUrl,
      data: {
        'session_id': session.sessionId,
        'viewer_id': session.viewerId,
        ...candidate.toJson(),
      },
    );
  }

  Future<void> closeLiveStreamSession(LiveStreamSession session) async {
    final closeUrl = session.resolvedCloseUrl;
    if (closeUrl == null) return;
    try {
      await dio.delete<void>(closeUrl);
    } on DioException {
      // Local media resources must still be released if remote cleanup fails.
    }
  }

  /// Backwards-compatible HLS accessor used by older callers.
  Future<String> getLiveStreamUrl({
    required String siteId,
    required String cameraId,
  }) async {
    final session = await getLiveStreamSession(
      cameraId: cameraId,
      type: StreamType.hls,
    );
    return session.streamUrl!;
  }

  String _demoStreamUrl(String cameraId) {
    switch (cameraId) {
      case 'cam-001':
        // Main Entrance - Turnstile Gate (City/Entrance Feed)
        return 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreet.mp4';
      case 'cam-002':
        // Executive Lobby & Elevators (Lobby/Interior Feed)
        return 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4';
      case 'cam-003':
        // Executive Parking - VIP Zone (Street Traffic Feed)
        return 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4';
      case 'cam-004':
        // Loading Dock - Bay 3 (Industrial Bay Feed)
        return 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';
      case 'cam-005':
        // High-Value Goods Vault (Vault/Indoor Room Feed)
        return 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4';
      case 'cam-006':
        // Server Rack Aisle 4 (Datacenter Feed)
        return 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4';
      case 'cam-007':
        // Perimeter North Fence Line (Outdoor Landscape Feed)
        return 'https://playertest.longtailvideo.com/adaptive/oceans/oceans.m3u8';
      case 'cam-008':
        // Cafeteria & Staff Lounge (Lounge Feed)
        return 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4';
      case 'cam-009':
        // Main Backup Generator Room (Utility/Generator Feed)
        return 'https://playertest.longtailvideo.com/adaptive/tears_of_steel/tears_of_steel.m3u8';
      default:
        return 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';
    }
  }

  /// Dispatches directional PTZ movement command for a camera.
  /// Allowed directions: 'left', 'right', 'up', 'down'.
  Future<void> movePtz({
    required String siteId,
    required String cameraId,
    required String direction,
    double speed = 1.0,
  }) async {
    if (demoMode) return;
    try {
      await dio.post<Map<String, dynamic>>(
        'sites/$siteId/cameras/$cameraId/ptz/move',
        data: {'direction': direction, 'speed': speed},
      );
    } on DioException catch (error) {
      throw CameraException(error.message ?? 'PTZ movement failed.');
    }
  }

  /// Dispatches PTZ zoom command for a camera.
  /// Allowed zoom modes: 'in', 'out'.
  Future<void> zoomPtz({
    required String siteId,
    required String cameraId,
    required String zoomMode,
    double speed = 1.0,
  }) async {
    if (demoMode) return;
    try {
      await dio.post<Map<String, dynamic>>(
        'sites/$siteId/cameras/$cameraId/ptz/zoom',
        data: {'zoomMode': zoomMode, 'speed': speed},
      );
    } on DioException catch (error) {
      throw CameraException(error.message ?? 'PTZ zoom failed.');
    }
  }

  /// Recalls a PTZ preset position for a camera.
  Future<void> presetPtz({
    required String siteId,
    required String cameraId,
    required int presetId,
  }) async {
    if (demoMode) return;
    try {
      await dio.post<Map<String, dynamic>>(
        'sites/$siteId/cameras/$cameraId/ptz/preset',
        data: {'presetId': presetId},
      );
    } on DioException catch (error) {
      throw CameraException(error.message ?? 'PTZ preset recall failed.');
    }
  }

  /// Dispatches emergency panic protocol payload to Control Room API.
  Future<void> dispatchEmergencyPanic({
    required String protocol,
    required String operatorId,
    String? siteId,
    String? cameraId,
  }) async {
    if (demoMode) return;
    try {
      await dio.post<Map<String, dynamic>>(
        'emergency/dispatch',
        data: {
          'protocol': protocol,
          'siteId': siteId ?? 'all',
          'cameraId': cameraId ?? 'all',
          'operatorId': operatorId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } on DioException catch (error) {
      throw CameraException(error.message ?? 'Emergency dispatch failed.');
    }
  }
}

class CameraException implements Exception {
  const CameraException(this.message);

  final String message;

  @override
  String toString() => 'CameraException: $message';
}

class _CameraCacheEntry {
  const _CameraCacheEntry({required this.cameras, required this.loadedAt});

  final List<Camera> cameras;
  final DateTime loadedAt;
}
