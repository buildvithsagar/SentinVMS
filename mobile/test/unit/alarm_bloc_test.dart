import 'package:app/features/alarms/bloc/alarm_bloc.dart';
import 'package:app/features/alarms/bloc/alarm_event.dart';
import 'package:app/features/alarms/bloc/alarm_state.dart';
import 'package:app/features/alarms/data/alarm_repository.dart';
import 'package:app/features/alarms/models/alarm_model.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAlarmRepository extends Mock implements AlarmRepository {}

void main() {
  group('AlarmBloc Tests', () {
    late AlarmRepository alarmRepository;
    late AlarmBloc alarmBloc;

    final mockAlarms = [
      Alarm(
        id: 'alarm-1',
        siteId: 'site-1',
        cameraId: 'cam-1',
        cameraName: 'Camera 1',
        eventClass: 'INTRUSION',
        confidence: 0.95,
        status: 'ACTIVE',
        timestamp: DateTime(2026, 6, 25, 12, 0),
      ),
    ];

    setUp(() {
      alarmRepository = MockAlarmRepository();
      alarmBloc = AlarmBloc(alarmRepository: alarmRepository);
    });

    tearDown(() {
      alarmBloc.close();
    });

    blocTest<AlarmBloc, AlarmState>(
      'emits [AlarmLoading, AlarmLoaded] when FetchAlarms is added successfully',
      build: () {
        when(() => alarmRepository.getAlarms(siteId: any(named: 'siteId')))
            .thenAnswer((_) async => mockAlarms);
        return alarmBloc;
      },
      act: (bloc) => bloc.add(const FetchAlarms()),
      expect: () => [
        const AlarmLoading(),
        AlarmLoaded(alarms: mockAlarms),
      ],
      verify: (_) {
        verify(() => alarmRepository.getAlarms()).called(1);
      },
    );

    blocTest<AlarmBloc, AlarmState>(
      'emits [AlarmLoading, AlarmError] when FetchAlarms fails',
      build: () {
        when(() => alarmRepository.getAlarms(siteId: any(named: 'siteId')))
            .thenThrow(const AlarmException('Database connection failed'));
        return alarmBloc;
      },
      act: (bloc) => bloc.add(const FetchAlarms()),
      expect: () => [
        const AlarmLoading(),
        const AlarmError(message: 'Database connection failed'),
      ],
    );

    blocTest<AlarmBloc, AlarmState>(
      'updates alarm list when AlarmAcknowledged is added successfully',
      build: () {
        final ackedAlarm = mockAlarms.first.copyWith(
          status: 'ACKNOWLEDGED',
          acknowledgedBy: 'current_user',
          acknowledgedAt: DateTime(2026, 6, 25, 12, 5),
        );
        when(() => alarmRepository.acknowledgeAlarm(alarmId: 'alarm-1'))
            .thenAnswer((_) async => ackedAlarm);
        return alarmBloc;
      },
      seed: () => AlarmLoaded(alarms: mockAlarms),
      act: (bloc) => bloc.add(const AlarmAcknowledged(alarmId: 'alarm-1')),
      expect: () {
        final ackedAlarm = mockAlarms.first.copyWith(
          status: 'ACKNOWLEDGED',
          acknowledgedBy: 'current_user',
          acknowledgedAt: DateTime(2026, 6, 25, 12, 5),
        );
        return [
          AlarmLoaded(alarms: [ackedAlarm]),
        ];
      },
      verify: (_) {
        verify(() => alarmRepository.acknowledgeAlarm(alarmId: 'alarm-1'))
            .called(1);
      },
    );

    blocTest<AlarmBloc, AlarmState>(
      'prepends new alarm to loaded state when AlarmReceived is dispatched',
      build: () => alarmBloc,
      seed: () => AlarmLoaded(alarms: mockAlarms),
      act: (bloc) => bloc.add(
        AlarmReceived(
          alarmData: <String, dynamic>{
            'alarmId': 'alarm-2',
            'siteId': 'site-1',
            'cameraId': 'cam-2',
            'cameraName': 'Camera 2',
            'eventClass': 'FIRE',
            'confidence': 0.88,
            'status': 'ACTIVE',
            'timestamp': '2026-06-25T12:10:00Z',
          },
        ),
      ),
      expect: () {
        final newAlarm = Alarm(
          id: 'alarm-2',
          siteId: 'site-1',
          cameraId: 'cam-2',
          cameraName: 'Camera 2',
          eventClass: 'FIRE',
          confidence: 0.88,
          status: 'ACTIVE',
          timestamp: DateTime.parse('2026-06-25T12:10:00Z'),
        );
        return [
          AlarmLoaded(alarms: [newAlarm, ...mockAlarms]),
        ];
      },
    );
  });
}
