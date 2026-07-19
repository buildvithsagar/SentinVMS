import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/core/auth/auth_state.dart';
import 'package:app/features/alarms/models/alarm_model.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

class AlarmRepository {
  AlarmRepository({
    required this.dio,
  });

  final Dio dio;

  /// Fetches alarms with optional filters for site and status.
  Future<List<Alarm>> getAlarms({String? siteId, String? status}) async {
    // Detached from backend: Return mock alarms instantly
    return _demoAlarms;
  }

  List<Alarm> get _demoAlarms => [
        Alarm(
          id: 'alarm-001',
          siteId: 'site-001',
          cameraId: 'cam-front-gate',
          cameraName: 'Front Gate Camera',
          eventClass: 'INTRUSION',
          confidence: 0.9,
          timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
          status: 'ACTIVE',
        ),
        Alarm(
          id: 'alarm-002',
          siteId: 'site-001',
          cameraId: 'cam-parking-b',
          cameraName: 'Parking Lot B',
          eventClass: 'LOITERING',
          confidence: 0.9,
          timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 5)),
          status: 'ACKNOWLEDGED',
        ),
        Alarm(
          id: 'alarm-003',
          siteId: 'site-002',
          cameraId: 'cam-warehouse',
          cameraName: 'Warehouse Interior',
          eventClass: 'FIRE',
          confidence: 0.9,
          timestamp: DateTime.now().subtract(const Duration(hours: 4)),
          status: 'ACTIVE',
        ),
      ];

  /// Acknowledges an alarm by its ID.
  /// Returns the updated Alarm with ACKNOWLEDGED status.
  Future<Alarm> acknowledgeAlarm({required String alarmId}) async {
    if (GetIt.instance.isRegistered<AuthBloc>()) {
      final authState = GetIt.instance<AuthBloc>().state;
      if (authState is Authenticated && authState.user.userId == 'usr-demo-operator') {
        return Alarm(
          id: alarmId,
          siteId: 'site-001',
          cameraId: 'cam-front-gate',
          cameraName: 'Front Gate Camera',
          eventClass: 'INTRUSION',
          confidence: 0.9,
          timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
          status: 'ACKNOWLEDGED',
        );
      }
    }

    try {
      final response = await dio.patch<Map<String, dynamic>>(
        'events/$alarmId/acknowledge',
      );

      final data = response.data;
      if (data == null) {
        throw const AlarmException('Received empty response from server');
      }

      // Backend returns updated alarm directly, or wrapped under 'data'
      final alarmJson = data['data'] as Map<String, dynamic>? ?? data;

      return Alarm.fromJson(alarmJson);
    } on DioException catch (e) {
      throw AlarmException(e.message ?? 'Failed to acknowledge alarm');
    }
  }
}

class AlarmException implements Exception {
  const AlarmException(this.message);

  final String message;

  @override
  String toString() => 'AlarmException: $message';
}
