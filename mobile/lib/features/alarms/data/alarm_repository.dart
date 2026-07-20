import 'package:app/features/alarms/models/alarm_model.dart';
import 'package:dio/dio.dart';

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
          siteId: 'site-hq',
          cameraId: 'cam-001',
          cameraName: 'CAM-01 | Main Entrance',
          eventClass: 'CRITICAL INTRUSION',
          confidence: 0.98,
          timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
          status: 'ACTIVE',
        ),
        Alarm(
          id: 'alarm-002',
          siteId: 'site-hq',
          cameraId: 'cam-003',
          cameraName: 'CAM-03 | Executive Parking',
          eventClass: 'PERIMETER LOITERING',
          confidence: 0.94,
          timestamp: DateTime.now().subtract(const Duration(minutes: 35)),
          status: 'ACKNOWLEDGED',
          acknowledgedBy: 'operator@demo.com',
          acknowledgedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
        Alarm(
          id: 'alarm-003',
          siteId: 'site-warehouse',
          cameraId: 'cam-005',
          cameraName: 'CAM-05 | High-Value Vault',
          eventClass: 'THERMAL FIRE ANOMALY',
          confidence: 0.92,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          status: 'ACTIVE',
        ),
        Alarm(
          id: 'alarm-004',
          siteId: 'site-hq',
          cameraId: 'cam-003',
          cameraName: 'CAM-03 | Executive Parking',
          eventClass: 'LICENSE PLATE MATCH',
          confidence: 0.97,
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          status: 'ACKNOWLEDGED',
          acknowledgedBy: 'operator@demo.com',
          acknowledgedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 50)),
        ),
        Alarm(
          id: 'alarm-005',
          siteId: 'site-datacenter',
          cameraId: 'cam-006',
          cameraName: 'CAM-06 | Server Rack Aisle 4',
          eventClass: 'UNAUTHORIZED ACCESS',
          confidence: 0.99,
          timestamp: DateTime.now().subtract(const Duration(hours: 4)),
          status: 'ACTIVE',
        ),
      ];

  /// Acknowledges an alarm by its ID.
  /// Returns the updated Alarm with ACKNOWLEDGED status.
  Future<Alarm> acknowledgeAlarm({required String alarmId}) async {
    // Return updated acknowledged alarm instantly for offline demo
    final match = _demoAlarms.firstWhere(
      (a) => a.id == alarmId,
      orElse: () => _demoAlarms.first,
    );
    return match.copyWith(
      status: 'ACKNOWLEDGED',
      acknowledgedBy: 'operator@demo.com',
      acknowledgedAt: DateTime.now(),
    );
  }
}

class AlarmException implements Exception {
  const AlarmException(this.message);

  final String message;

  @override
  String toString() => 'AlarmException: $message';
}
