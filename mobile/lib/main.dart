import 'dart:async';

import 'package:app/app/app.dart';
import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/core/config/app_config.dart';
import 'package:app/core/lifecycle/app_lifecycle_observer.dart';
import 'package:app/core/network/connectivity_service.dart';
import 'package:app/core/network/dio_factory.dart';
import 'package:app/core/network/websocket_service.dart';
import 'package:app/core/storage/secure_storage_service.dart';
import 'package:app/core/video/decoder_pool.dart';
import 'package:app/features/alarms/bloc/alarm_bloc.dart';
import 'package:app/features/alarms/bloc/alarm_event.dart';
import 'package:app/features/alarms/data/alarm_repository.dart';
import 'package:app/features/camera/data/camera_repository.dart';
import 'package:app/features/device_onboarding/data/device_onboarding_repository.dart';
import 'package:app/features/export/data/export_repository.dart';
import 'package:app/features/login/data/auth_repository.dart';
import 'package:app/features/playback/data/playback_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';

final GetIt getIt = GetIt.instance;
final Logger _logger = Logger();

void main() {
  runZonedGuarded<void>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // 0. Environment & Crash Traps
      AppConfig.initialize();

      FlutterError.onError = (details) {
        _logger.e(
          'Flutter Uncaught UI Error: ${details.exceptionAsString()}',
          error: details.exception,
          stackTrace: details.stack,
        );
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        _logger.e('Platform Uncaught Error: $error', error: error, stackTrace: stack);
        return true;
      };

      // 1. Core Security & Storage
      final storage = SecureStorageService();
      getIt.registerSingleton<SecureStorageService>(storage);

      // 2. Session Management
      final authBloc = AuthBloc();
      getIt.registerSingleton<AuthBloc>(authBloc);

      // 3. Network Infrastructure
      final dio = DioFactory.create(
        storage: storage,
        authBloc: authBloc,
        trustedCAsPem: const <String>[],
      );
      getIt.registerSingleton<Dio>(dio);

      // 4. Connectivity & Telemetry Monitoring
      final connectivityService = ConnectivityService(logger: _logger);
      getIt.registerSingleton<ConnectivityService>(connectivityService);

      // 5. Feature Repositories & Services
      final authRepository = AuthRepository(dio: dio, storage: storage);
      getIt.registerSingleton<AuthRepository>(authRepository);

      final cameraRepository = CameraRepository(dio: dio);
      getIt.registerSingleton<CameraRepository>(cameraRepository);

      final decoderPool = DecoderPool(maxDecoders: 9);
      getIt.registerSingleton<DecoderPool>(decoderPool);

      final webSocketService = WebSocketService(authBloc: authBloc);
      getIt.registerSingleton<WebSocketService>(webSocketService);

      final playbackRepository = PlaybackRepository(dio: dio);
      getIt.registerSingleton<PlaybackRepository>(playbackRepository);

      final alarmRepository = AlarmRepository(dio: dio);
      getIt.registerSingleton<AlarmRepository>(alarmRepository);

      final exportRepository = ExportRepository(dio: dio);
      getIt.registerSingleton<ExportRepository>(exportRepository);

      final deviceOnboardingRepository = DeviceOnboardingRepository(dio: dio);
      getIt.registerSingleton<DeviceOnboardingRepository>(deviceOnboardingRepository);

      final alarmBloc = AlarmBloc(alarmRepository: alarmRepository);
      getIt.registerSingleton<AlarmBloc>(alarmBloc);

      // 6. App Lifecycle Observer Registration
      final lifecycleObserver = AppLifecycleObserver(
        webSocketService: webSocketService,
        logger: _logger,
      )..initialize();
      getIt.registerSingleton<AppLifecycleObserver>(lifecycleObserver);

      webSocketService.eventStream.listen((event) {
        if (event['event'] == 'alarm' && event['data'] != null) {
          alarmBloc.add(
            AlarmReceived(
              alarmData: event['data'] as Map<String, dynamic>,
            ),
          );
        } else if (event['eventClass'] != null) {
          alarmBloc.add(
            AlarmReceived(
              alarmData: event,
            ),
          );
        }
      });

      runApp(const MyApp());
    },
    (error, stack) {
      _logger.e('Uncaught Zone Error: $error', error: error, stackTrace: stack);
    },
  );
}
