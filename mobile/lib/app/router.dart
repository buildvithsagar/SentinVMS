import 'dart:async';
import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/core/auth/auth_state.dart';
import 'package:app/core/network/websocket_service.dart';
import 'package:app/features/alarms/bloc/alarm_bloc.dart';
import 'package:app/features/alarms/bloc/alarm_event.dart';
import 'package:app/features/alarms/presentation/alarm_list_page.dart';
import 'package:app/features/camera/bloc/camera_bloc.dart';
import 'package:app/features/camera/data/camera_repository.dart';
import 'package:app/features/camera/presentation/camera_list_page.dart';
import 'package:app/features/export/presentation/export_page.dart';
import 'package:app/features/live_view/live_grid_page.dart';
import 'package:app/features/login/bloc/login_bloc.dart';
import 'package:app/features/login/data/auth_repository.dart';
import 'package:app/features/login/login_page.dart';
import 'package:app/features/playback/presentation/playback_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

/// Helper to convert a Bloc/Stream into a [Listenable] for GoRouter refresh.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
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
            create: (context) => LoginBloc(
              authRepository: GetIt.instance<AuthRepository>(),
            ),
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
            child: const LiveGridPage(),
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
    ],
  );
}
