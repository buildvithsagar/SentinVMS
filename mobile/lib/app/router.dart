import 'dart:async';

import 'package:app/core/core.dart';
import 'package:app/features/alarms/alarms.dart';
import 'package:app/features/camera/camera.dart';
import 'package:app/features/device_onboarding/device_onboarding.dart';
import 'package:app/features/export/export.dart';
import 'package:app/features/live_view/live_view.dart';
import 'package:app/features/login/login.dart';
import 'package:app/features/playback/playback.dart';
import 'package:app/features/stream_demo/stream_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

/// Helper to convert a Bloc/Stream into a [Listenable] for GoRouter refresh.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(GetIt.instance<AuthBloc>().stream),
    redirect: (BuildContext context, GoRouterState state) {
      final authState = GetIt.instance<AuthBloc>().state;
      final isLoggingIn = state.matchedLocation == '/login';

      if (authState is! Authenticated) {
        // If not authenticated, redirect to /login unless already there
        return isLoggingIn ? null : '/login';
      }

      // If authenticated and trying to access /login, redirect to viewport grid
      if (isLoggingIn) {
        return '/live_grid';
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) {
          return BlocProvider<LoginBloc>(
            create: (context) =>
                LoginBloc(authRepository: GetIt.instance<AuthRepository>()),
            child: const LoginPage(),
          );
        },
      ),
      GoRoute(
        path: '/live_grid',
        builder: (BuildContext context, GoRouterState state) {
          return MultiBlocProvider(
            providers: [
              BlocProvider<CameraBloc>(
                create: (context) => CameraBloc(
                  cameraRepository: GetIt.instance<CameraRepository>(),
                  webSocketService: GetIt.instance<WebSocketService>(),
                ),
              ),
              BlocProvider<AlarmBloc>.value(
                value: GetIt.instance<AlarmBloc>()..add(const FetchAlarms()),
              ),
            ],
            child: LiveGridPage(
              initialCameraId: state.uri.queryParameters['cameraId'],
            ),
          );
        },
      ),
      GoRoute(
        path: '/cameras',
        builder: (BuildContext context, GoRouterState state) {
          return BlocProvider<CameraBloc>(
            create: (context) => CameraBloc(
              cameraRepository: GetIt.instance<CameraRepository>(),
              webSocketService: GetIt.instance<WebSocketService>(),
            ),
            child: const CameraListPage(),
          );
        },
      ),
      GoRoute(
        path: '/cameras/add',
        builder: (BuildContext context, GoRouterState state) {
          return const ManualRtspCameraPage();
        },
      ),
      GoRoute(
        path: '/playback',
        builder: (BuildContext context, GoRouterState state) {
          return const PlaybackPage();
        },
      ),
      GoRoute(
        path: '/alarms',
        builder: (BuildContext context, GoRouterState state) {
          return BlocProvider<AlarmBloc>.value(
            value: GetIt.instance<AlarmBloc>()..add(const FetchAlarms()),
            child: const AlarmListPage(),
          );
        },
      ),
      GoRoute(
        path: '/exports',
        builder: (BuildContext context, GoRouterState state) {
          return const ExportPage();
        },
      ),
      GoRoute(
        path: '/stream_demo',
        builder: (BuildContext context, GoRouterState state) {
          return const StreamDemoPage();
        },
      ),
      GoRoute(
        path: '/onboard',
        builder: (BuildContext context, GoRouterState state) {
          return const DeviceCategoryPage();
        },
      ),
      GoRoute(
        path: '/onboard/register',
        builder: (BuildContext context, GoRouterState state) {
          final category = state.uri.queryParameters['category'] ?? '';
          final mode = state.uri.queryParameters['mode'] ?? 'insta_on';
          final autoStartScan = state.uri.queryParameters['scan'] == 'true';
          final initialSerialNumber = state.uri.queryParameters['sn'];
          final initialDeviceName = state.uri.queryParameters['name'];
          return DeviceDetailsFormPage(
            category: category,
            mode: mode,
            autoStartScan: autoStartScan,
            initialSerialNumber: initialSerialNumber,
            initialDeviceName: initialDeviceName,
          );
        },
      ),
    ],
  );
}
