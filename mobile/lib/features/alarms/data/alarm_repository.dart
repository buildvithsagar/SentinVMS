import 'package:app/features/alarms/models/alarm_model.dart';
import 'package:dio/dio.dart';

class AlarmRepository {
  AlarmRepository({
    required this.dio,
  });

  final Dio dio;

  /// Fetches alarms with optional filters for site and status.
  Future<List<Alarm>> getAlarms({String? siteId, String? status}) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/v5/alarms',
        queryParameters: <String, dynamic>{
          if (siteId != null) 'siteId': siteId,
          if (status != null) 'status': status,
        },
      );

      final data = response.data;
      if (data == null) {
        throw const AlarmException('Received empty response from server');
      }

      final list = data['data'] as List<dynamic>?;
      if (list == null) {
        throw const AlarmException('Missing data array in response');
      }

      return list
          .map((json) => Alarm.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw AlarmException(e.message ?? 'Failed to load alarms');
    }
  }

  /// Acknowledges an alarm by its ID.
  /// Returns the updated Alarm with ACKNOWLEDGED status.
  Future<Alarm> acknowledgeAlarm({required String alarmId}) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/api/v5/alarms/$alarmId/acknowledge',
      );

      final data = response.data;
      if (data == null) {
        throw const AlarmException('Received empty response from server');
      }

      final alarmJson = data['data'] as Map<String, dynamic>?;
      if (alarmJson == null) {
        throw const AlarmException('Missing data in response');
      }

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
