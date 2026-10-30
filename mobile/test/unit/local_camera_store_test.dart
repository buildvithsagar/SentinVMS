import 'package:app/core/storage/secure_storage_service.dart';
import 'package:app/features/camera/data/local_camera_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalCameraStore', () {
    late _MemorySecureStore secureStorage;
    late LocalCameraStore cameraStore;

    setUp(() {
      secureStorage = _MemorySecureStore();
      cameraStore = LocalCameraStore(secureStorage);
    });

    test('saves a direct RTSP camera and restores it', () async {
      final saved = await cameraStore.addCamera(
        name: 'Main Gate',
        rtspUri: Uri.parse('rtsp://admin:pass%40word@10.0.0.5:554/live'),
        subStreamUri: Uri.parse(
          'rtsp://admin:pass%40word@10.0.0.5:554/live/sub',
        ),
        codec: 'h265',
      );

      final restored = await LocalCameraStore(secureStorage).getCameras();
      expect(restored, hasLength(1));
      expect(restored.single.id, saved.id);
      expect(restored.single.name, 'Main Gate');
      expect(restored.single.codec, 'H265');
      expect(restored.single.usesDirectRtsp, isTrue);
      expect(restored.single.rtspUrl, contains('pass%40word'));
      expect(restored.single.hasSubStream, isTrue);
      expect(restored.single.streamUrlForGrid(2), restored.single.rtspUrl);
      expect(restored.single.streamUrlForGrid(3), restored.single.subStreamUrl);
    });

    test('removes only the selected camera', () async {
      final first = await cameraStore.addCamera(
        name: 'One',
        rtspUri: Uri.parse('rtsp://camera-one/live'),
        codec: 'AUTO',
      );
      await cameraStore.addCamera(
        name: 'Two',
        rtspUri: Uri.parse('rtsp://camera-two/live'),
        codec: 'H264',
      );

      await cameraStore.deleteCamera(first.id);

      final remaining = await cameraStore.getCameras();
      expect(remaining, hasLength(1));
      expect(remaining.single.name, 'Two');
    });
  });
}

class _MemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<void> deleteSecureValue(String key) async => values.remove(key);

  @override
  Future<String?> readSecureValue(String key) async => values[key];

  @override
  Future<void> writeSecureValue(String key, String value) async {
    values[key] = value;
  }
}
