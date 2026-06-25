import 'package:app/features/alarms/bloc/alarm_event.dart';
import 'package:app/features/alarms/bloc/alarm_state.dart';
import 'package:app/features/alarms/data/alarm_repository.dart';
import 'package:app/features/alarms/models/alarm_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Manages alarm lifecycle: fetching, real-time ingestion, and acknowledgement.
class AlarmBloc extends Bloc<AlarmEvent, AlarmState> {
  AlarmBloc({
    required this.alarmRepository,
  })  : super(const AlarmInitial()) {
    on<FetchAlarms>(_onFetchAlarms);
    on<AlarmAcknowledged>(_onAlarmAcknowledged);
    on<AlarmReceived>(_onAlarmReceived);
  }

  final AlarmRepository alarmRepository;

  Future<void> _onFetchAlarms(
    FetchAlarms event,
    Emitter<AlarmState> emit,
  ) async {
    emit(const AlarmLoading());
    try {
      final alarms = await alarmRepository.getAlarms(siteId: event.siteId);
      emit(AlarmLoaded(alarms: alarms));
    } on AlarmException catch (e) {
      emit(AlarmError(message: e.message));
    } catch (e) {
      emit(AlarmError(message: e.toString()));
    }
  }

  Future<void> _onAlarmAcknowledged(
    AlarmAcknowledged event,
    Emitter<AlarmState> emit,
  ) async {
    final currentState = state;
    if (currentState is AlarmLoaded) {
      try {
        final updatedAlarm = await alarmRepository.acknowledgeAlarm(
          alarmId: event.alarmId,
        );
        final updatedAlarms = currentState.alarms.map((alarm) {
          if (alarm.id == event.alarmId) {
            return updatedAlarm;
          }
          return alarm;
        }).toList();
        emit(AlarmLoaded(alarms: updatedAlarms));
      } on AlarmException catch (e) {
        // Keep current alarms, but surface the error.
        emit(AlarmError(message: e.message));
        emit(AlarmLoaded(alarms: currentState.alarms));
      }
    }
  }

  void _onAlarmReceived(
    AlarmReceived event,
    Emitter<AlarmState> emit,
  ) {
    final currentState = state;
    final newAlarm = Alarm.fromJson(event.alarmData);
    if (currentState is AlarmLoaded) {
      emit(AlarmLoaded(alarms: [newAlarm, ...currentState.alarms]));
    } else {
      emit(AlarmLoaded(alarms: [newAlarm]));
    }
  }
}
