import 'dart:async';
import 'package:app/core/network/websocket_service.dart';
import 'package:app/features/camera/bloc/camera_bloc.dart';
import 'package:app/features/camera/bloc/camera_event.dart';
import 'package:app/features/camera/bloc/camera_state.dart';
import 'package:app/features/camera/data/camera_repository.dart';
import 'package:app/features/camera/models/camera_model.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCameraRepository extends Mock implements CameraRepository {}

class MockWebSocketService extends Mock implements WebSocketService {}

void main() {
  group('CameraBloc', () {
    late CameraRepository cameraRepository;
    late WebSocketService webSocketService;
    late StreamController<Map<String, dynamic>> eventStreamController;
    late StreamController<WebSocketStatus> statusStreamController;
    late CameraBloc cameraBloc;

    const camera = Camera(
      id: 'camera-1',
      siteId: 'site-123',
      name: 'Main Gate',
      ipAddress: '192.168.1.100',
      rtspUrl: 'rtsp://...',
      onvifProfile: 'S',
      codec: 'H264',
      ptzCapable: true,
      status: 'DISCONNECTED',
    );

    setUp(() {
      cameraRepository = MockCameraRepository();
      webSocketService = MockWebSocketService();

      eventStreamController = StreamController<Map<String, dynamic>>.broadcast();
      statusStreamController = StreamController<WebSocketStatus>.broadcast();

      when(() => webSocketService.eventStream)
          .thenAnswer((_) => eventStreamController.stream);
      when(() => webSocketService.statusStream)
          .thenAnswer((_) => statusStreamController.stream);
      when(() => webSocketService.subscribeToSite(any())).thenAnswer((_) {});

      cameraBloc = CameraBloc(
        cameraRepository: cameraRepository,
        webSocketService: webSocketService,
      );
    });

    tearDown(() {
      cameraBloc.close();
      eventStreamController.close();
      statusStreamController.close();
    });

    test('initial state is CameraInitial', () {
      expect(cameraBloc.state, const CameraInitial());
    });

    blocTest<CameraBloc, CameraState>(
      'emits [CameraLoading, CameraLoaded] when FetchCameras succeeds',
      build: () {
        when(() => cameraRepository.getCameras(siteId: 'site-123'))
            .thenAnswer((_) async => [camera]);
        return cameraBloc;
      },
      act: (bloc) => bloc.add(const FetchCameras(siteId: 'site-123')),
      expect: () => [
        const CameraLoading(),
        const CameraLoaded(cameras: [camera]),
      ],
      verify: (_) {
        verify(() => webSocketService.subscribeToSite('site-123')).called(1);
      },
    );

    blocTest<CameraBloc, CameraState>(
      'emits [CameraLoading, CameraError] when FetchCameras fails',
      build: () {
        when(() => cameraRepository.getCameras(siteId: 'site-123'))
            .thenThrow(const CameraException('API Error'));
        return cameraBloc;
      },
      act: (bloc) => bloc.add(const FetchCameras(siteId: 'site-123')),
      expect: () => [
        const CameraLoading(),
        const CameraError(message: 'CameraException: API Error'),
      ],
    );

    blocTest<CameraBloc, CameraState>(
      'updates camera status when WebSocket status event is received',
      build: () {
        when(() => cameraRepository.getCameras(siteId: 'site-123'))
            .thenAnswer((_) async => [camera]);
        return cameraBloc;
      },
      act: (bloc) async {
        bloc.add(const FetchCameras(siteId: 'site-123'));
        // Wait for fetch to complete and state to be CameraLoaded
        await Future<void>.delayed(Duration.zero);
        // Emit WebSocket update
        eventStreamController.add({
          'event': 'camera.status',
          'data': {'cameraId': 'camera-1', 'status': 'CONNECTED'}
        });
      },
      skip: 2, // Skip initial loading and loaded states
      expect: () => [
        CameraLoaded(cameras: [camera.copyWith(status: 'CONNECTED')]),
      ],
    );

    test('reconnects and triggers reconciliation when status becomes connected', () async {
      when(() => cameraRepository.getCameras(siteId: 'site-123'))
          .thenAnswer((_) async => [camera]);

      cameraBloc.add(const FetchCameras(siteId: 'site-123'));
      await Future<void>.delayed(Duration.zero);



      // Simulate a connection status change (disconnected then connected)
      statusStreamController.add(WebSocketStatus.disconnected);
      await Future<void>.delayed(Duration.zero);

      statusStreamController.add(WebSocketStatus.connected);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify reconciliation refetched cameras
      verify(() => cameraRepository.getCameras(siteId: 'site-123')).called(2);
    });
  });
}
