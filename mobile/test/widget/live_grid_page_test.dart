import 'package:app/core/video/decoder_pool.dart';
import 'package:app/features/camera/bloc/camera_bloc.dart';
import 'package:app/features/camera/bloc/camera_event.dart';
import 'package:app/features/camera/bloc/camera_state.dart';
import 'package:app/features/camera/data/camera_repository.dart';
import 'package:app/features/camera/models/camera_model.dart';
import 'package:app/features/live_view/live_grid_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class MockCameraBloc extends MockBloc<CameraEvent, CameraState> implements CameraBloc {}
class MockCameraRepository extends Mock implements CameraRepository {}
class MockDecoderPool extends Mock implements DecoderPool {}

void main() {
  group('LiveGridPage Widget Tests', () {
    late MockCameraBloc mockCameraBloc;
    late MockCameraRepository mockRepo;
    late MockDecoderPool mockPool;

    setUpAll(() {
      registerFallbackValue(const FetchCameras());
    });

    setUp(() {
      mockCameraBloc = MockCameraBloc();
      mockRepo = MockCameraRepository();
      mockPool = MockDecoderPool();

      GetIt.instance.registerSingleton<CameraRepository>(mockRepo);
      GetIt.instance.registerSingleton<DecoderPool>(mockPool);

      when(() => mockCameraBloc.state).thenReturn(const CameraInitial());
    });

    tearDown(() {
      GetIt.instance.reset();
    });

    Widget buildTestWidget() {
      return MaterialApp(
        home: BlocProvider<CameraBloc>.value(
          value: mockCameraBloc,
          child: const LiveGridPage(),
        ),
      );
    }

    testWidgets('renders title and 2x2 grid slots initially', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Live Viewport Grid'), findsOneWidget);
      expect(find.text('Layout: 2x2 Grid (4 Feeds)'), findsOneWidget);

      expect(find.text('Slot 1: Empty'), findsOneWidget);
      expect(find.text('Slot 2: Empty'), findsOneWidget);
      expect(find.text('Slot 3: Empty'), findsOneWidget);
      expect(find.text('Slot 4: Empty'), findsOneWidget);
    });

    testWidgets('switching to 1x1 layout renders single slot focus', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final toggle1x1 = find.byTooltip('1x1 View');
      await tester.tap(toggle1x1);
      await tester.pumpAndSettle();

      expect(find.text('Layout: 1x1 Focus (Single Feed)'), findsOneWidget);
      expect(find.text('Slot 1: Empty'), findsOneWidget);

      expect(find.text('Slot 2: Empty'), findsNothing);
    });

    testWidgets('tapping empty slot selects it', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('Slot 2: Empty'));
      await tester.pump();

      expect(find.text('SLOT 2 SELECTED'), findsOneWidget);
    });

    testWidgets('clicking Select opens camera picker bottom sheet', (tester) async {
      final cameras = [
        const Camera(
          id: 'cam_1',
          siteId: 'site_1',
          name: 'Camera 1',
          ipAddress: '192.168.1.1',
          rtspUrl: 'rtsp://...',
          onvifProfile: 'S',
          codec: 'H264',
          ptzCapable: false,
          status: 'CONNECTED',
        )
      ];
      when(() => mockCameraBloc.state).thenReturn(CameraLoaded(cameras: cameras));

      await tester.pumpWidget(buildTestWidget());

      final selectButton = find.text('Select');
      await tester.tap(selectButton);
      await tester.pumpAndSettle();

      expect(find.text('Select Camera for Slot'), findsOneWidget);
      expect(find.text('Camera 1'), findsOneWidget);
    });
  });
}
