import 'dart:convert';

import 'package:app/core/storage/secure_storage_service.dart';
import 'package:app/features/camera/models/camera_model.dart';
import 'package:mutex/mutex.dart';

class LocalCameraStore {
  LocalCameraStore({required this._storage});

  static const storageKey = 'sentinvms_local_rtsp_cameras_v1';
  static const localSiteId = 'local-phone';

  final SecureKeyValueStore _storage;
  final Mutex _mutex = Mutex();

  Future<List<Camera>> getCameras() async {
    return _mutex.protect(_readUnlocked);
  }

  Future<Camera> addCamera({
    required String name,
    required Uri rtspUri,
    required String codec,
  }) async {
    return _mutex.protect(() async {
      final cameras = await _readUnlocked();
      final camera = Camera(
        id: 'local-rtsp-${DateTime.now().microsecondsSinceEpoch}',
        siteId: localSiteId,
        name: name.trim(),
        ipAddress: rtspUri.host,
        rtspUrl: rtspUri.toString(),
        onvifProfile: 'RTSP',
        codec: codec.toUpperCase(),
        ptzCapable: false,
        status: 'CONNECTED',
      );
      await _writeUnlocked([...cameras, camera]);
      return camera;
    });
  }

  Future<void> deleteCamera(String cameraId) async {
    await _mutex.protect(() async {
      final cameras = await _readUnlocked();
      await _writeUnlocked(
        cameras
            .where((camera) => camera.id != cameraId)
            .toList(growable: false),
      );
    });
  }

  Future<List<Camera>> _readUnlocked() async {
    final encoded = await _storage.readSecureValue(storageKey);
    if (encoded == null || encoded.trim().isEmpty) return const [];
    try {
      final value = jsonDecode(encoded);
      if (value is! List) return const [];
      return value
          .whereType<Map<Object?, Object?>>()
          .map((json) => Camera.fromJson(Map<String, dynamic>.from(json)))
          .where((camera) => camera.usesDirectRtsp)
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  Future<void> _writeUnlocked(List<Camera> cameras) async {
    if (cameras.isEmpty) {
      await _storage.deleteSecureValue(storageKey);
      return;
    }
    await _storage.writeSecureValue(
      storageKey,
      jsonEncode(cameras.map((camera) => camera.toJson()).toList()),
    );
  }
}
