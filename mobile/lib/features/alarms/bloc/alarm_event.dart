import 'package:equatable/equatable.dart';

abstract class AlarmEvent extends Equatable {
  const AlarmEvent();

  @override
  List<Object?> get props => [];
}

class FetchAlarms extends AlarmEvent {
  const FetchAlarms({this.siteId});

  final String? siteId;

  @override
  List<Object?> get props => [siteId];
}

class AlarmAcknowledged extends AlarmEvent {
  const AlarmAcknowledged({required this.alarmId});

  final String alarmId;

  @override
  List<Object?> get props => [alarmId];
}

class AlarmReceived extends AlarmEvent {
  const AlarmReceived({required this.alarmData});

  final Map<String, dynamic> alarmData;

  @override
  List<Object?> get props => [alarmData];
}
