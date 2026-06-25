import 'package:app/features/alarms/models/alarm_model.dart';
import 'package:equatable/equatable.dart';

abstract class AlarmState extends Equatable {
  const AlarmState();

  @override
  List<Object?> get props => [];
}

class AlarmInitial extends AlarmState {
  const AlarmInitial();
}

class AlarmLoading extends AlarmState {
  const AlarmLoading();
}

class AlarmLoaded extends AlarmState {
  const AlarmLoaded({required this.alarms});

  final List<Alarm> alarms;

  @override
  List<Object?> get props => [alarms];
}

class AlarmError extends AlarmState {
  const AlarmError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
