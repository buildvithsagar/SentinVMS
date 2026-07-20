import 'dart:async';
import 'package:app/core/video/decoder_pool.dart';
import 'package:app/features/camera/data/camera_repository.dart';
import 'package:app/features/camera/models/camera_model.dart';
import 'package:app/features/live_view/widgets/video_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCameraRepository extends Mock implements CameraRepository {}
class MockDecoderPool extends Mock implements DecoderPool {}

void main() {
  group('VideoTile Widget Tests', () {
    late Camera camera;
    late MockCameraRepository mockRepo;
    late MockDecoderPool mockPool;

    setUp(() {
      camera = const Camera(
        id: 'cam_1',
        siteId: 'site_1',
        name: 'Test Camera',
        ipAddress: '192.168.1.100',
        rtspUrl: 'rtsp://...',
        onvifProfile: 'S',
        codec: 'H264',
        ptzCapable: false,
        status: 'CONNECTED',
      );
      mockRepo = MockCameraRepository();
      mockPool = MockDecoderPool();
    });

    testWidgets('displays loading state initially', (tester) async {
      final completer = Completer<String>();
      when(() => mockRepo.getLiveStreamUrl(siteId: 'site_1', cameraId: 'cam_1'))
          .thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoTile(
              camera: camera,
              cameraRepository: mockRepo,
              decoderPool: mockPool,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete('http://example.com/stream.m3u8');
      await tester.pump();
    });

    testWidgets('displays error state when stream URL fetch fails', (tester) async {
      when(() => mockRepo.getLiveStreamUrl(siteId: 'site_1', cameraId: 'cam_1'))
          .thenThrow(const CameraException('Failed to load URL'));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoTile(
              camera: camera,
              cameraRepository: mockRepo,
              decoderPool: mockPool,
            ),
          ),
        ),
      );

      // Await future completing
      await tester.pump();

      expect(find.text('Stream Error'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders PTZ overlay if camera is PTZ capable and showPtzOverlay is true', (tester) async {
      final ptzCamera = camera.copyWith(ptzCapable: true);
      when(() => mockRepo.getLiveStreamUrl(siteId: 'site_1', cameraId: 'cam_1'))
          .thenThrow(const CameraException('Failed to load URL'));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoTile(
              camera: ptzCamera,
              cameraRepository: mockRepo,
              decoderPool: mockPool,
              showPtzOverlay: true,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
      expect(find.byIcon(Icons.zoom_out), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_up), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
      expect(find.byIcon(Icons.arrow_left), findsOneWidget);
      expect(find.byIcon(Icons.arrow_right), findsOneWidget);
    });
  });
}
