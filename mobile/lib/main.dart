import 'package:app/app/app.dart';
import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/core/network/dio_factory.dart';
import 'package:app/core/network/websocket_service.dart';
import 'package:app/core/storage/secure_storage_service.dart';
import 'package:app/core/video/decoder_pool.dart';
import 'package:app/features/alarms/bloc/alarm_bloc.dart';
import 'package:app/features/alarms/bloc/alarm_event.dart';
import 'package:app/features/alarms/data/alarm_repository.dart';
import 'package:app/features/camera/data/camera_repository.dart';
import 'package:app/features/export/data/export_repository.dart';
import 'package:app/features/login/data/auth_repository.dart';
import 'package:app/features/playback/data/playback_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

final GetIt getIt = GetIt.instance;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Core Security & Storage
  final storage = SecureStorageService();
  getIt.registerSingleton<SecureStorageService>(storage);

  // 2. Session Management
  final authBloc = AuthBloc();
  getIt.registerSingleton<AuthBloc>(authBloc);

  // 3. Network Infrastructure (Dio Client with Pinning and Dev Bypass)
  // trustedCAsPem can be hydrated with the Intermediate CA from HashiCorp Vault.
  // In local development, the BYPASS_PINNING flag skips pinning verification.
  final dio = DioFactory.create(
    storage: storage,
    authBloc: authBloc,
    trustedCAsPem: const <String>[],
  );
  getIt.registerSingleton<Dio>(dio);

  // 4. Feature Repositories & Services
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

  final alarmBloc = AlarmBloc(alarmRepository: alarmRepository);
  getIt.registerSingleton<AlarmBloc>(alarmBloc);

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
}
