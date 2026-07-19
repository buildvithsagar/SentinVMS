import 'package:app/features/device_onboarding/bloc/device_onboarding_bloc.dart';
import 'package:app/features/device_onboarding/data/device_onboarding_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDeviceOnboardingRepository extends Mock
    implements DeviceOnboardingRepository {}

void main() {
  group('DeviceOnboardingBloc Tests', () {
    late DeviceOnboardingRepository repository;
    late DeviceOnboardingBloc bloc;

    const category = 'dvr_nvr';
    const serialNumber = 'J006286';
    const deviceName = 'Front Gate NVR';
    const username = 'admin';
    const password = 'password';
    const mode = 'insta_on';

    setUp(() {
      repository = MockDeviceOnboardingRepository();
      bloc = DeviceOnboardingBloc(repository: repository);
    });

    tearDown(() {
      bloc.close();
    });

    test('initial state is DeviceOnboardingInitial', () {
      expect(bloc.state, const DeviceOnboardingInitial());
    });

    blocTest<DeviceOnboardingBloc, DeviceOnboardingState>(
      'emits [DeviceOnboardingLoading, DeviceOnboardingSuccess] when onboardDevice succeeds',
      build: () {
        when(() => repository.onboardDevice(
              category: category,
              serialNumber: serialNumber,
              deviceName: deviceName,
              username: username,
              password: password,
              mode: mode,
            )).thenAnswer((_) async {});
        return bloc;
      },
      act: (bloc) => bloc.add(const DeviceOnboardSubmitted(
        category: category,
        serialNumber: serialNumber,
        deviceName: deviceName,
        username: username,
        password: password,
        mode: mode,
      )),
      expect: () => const [
        DeviceOnboardingLoading(),
        DeviceOnboardingSuccess(),
      ],
    );

    blocTest<DeviceOnboardingBloc, DeviceOnboardingState>(
      'emits [DeviceOnboardingLoading, DeviceOnboardingFailure] when onboardDevice fails',
      build: () {
        when(() => repository.onboardDevice(
              category: category,
              serialNumber: serialNumber,
              deviceName: deviceName,
              username: username,
              password: password,
              mode: mode,
            )).thenThrow(const DeviceOnboardingException('Registration failed'));
        return bloc;
      },
      act: (bloc) => bloc.add(const DeviceOnboardSubmitted(
        category: category,
        serialNumber: serialNumber,
        deviceName: deviceName,
        username: username,
        password: password,
        mode: mode,
      )),
      expect: () => const [
        DeviceOnboardingLoading(),
        DeviceOnboardingFailure(message: 'Registration failed'),
      ],
    );

    blocTest<DeviceOnboardingBloc, DeviceOnboardingState>(
      'emits [DeviceOnboardingInitial] when DeviceOnboardReset is added',
      build: () => bloc,
      act: (bloc) => bloc.add(const DeviceOnboardReset()),
      expect: () => const [
        DeviceOnboardingInitial(),
      ],
    );
  });
}
