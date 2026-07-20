import 'package:app/features/device_onboarding/data/device_onboarding_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// --- Events ---
abstract class DeviceOnboardingEvent extends Equatable {
  const DeviceOnboardingEvent();

  @override
  List<Object?> get props => [];
}

class DeviceOnboardSubmitted extends DeviceOnboardingEvent {
  const DeviceOnboardSubmitted({
    required this.category,
    required this.serialNumber,
    required this.deviceName,
    required this.username,
    required this.password,
    required this.mode,
  });

  final String category;
  final String serialNumber;
  final String deviceName;
  final String username;
  final String password;
  final String mode;

  @override
  List<Object?> get props => [
        category,
        serialNumber,
        deviceName,
        username,
        password,
        mode,
      ];
}

class DeviceOnboardReset extends DeviceOnboardingEvent {
  const DeviceOnboardReset();
}

// --- States ---
abstract class DeviceOnboardingState extends Equatable {
  const DeviceOnboardingState();

  @override
  List<Object?> get props => [];
}

class DeviceOnboardingInitial extends DeviceOnboardingState {
  const DeviceOnboardingInitial();
}

class DeviceOnboardingLoading extends DeviceOnboardingState {
  const DeviceOnboardingLoading();
}

class DeviceOnboardingSuccess extends DeviceOnboardingState {
  const DeviceOnboardingSuccess();
}

class DeviceOnboardingFailure extends DeviceOnboardingState {
  const DeviceOnboardingFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}

// --- Bloc ---
class DeviceOnboardingBloc
    extends Bloc<DeviceOnboardingEvent, DeviceOnboardingState> {
  DeviceOnboardingBloc({
    required this._repository,
  })  : super(const DeviceOnboardingInitial()) {
    on<DeviceOnboardSubmitted>(_onDeviceOnboardSubmitted);
    on<DeviceOnboardReset>(_onDeviceOnboardReset);
  }

  final DeviceOnboardingRepository _repository;

  Future<void> _onDeviceOnboardSubmitted(
    DeviceOnboardSubmitted event,
    Emitter<DeviceOnboardingState> emit,
  ) async {
    emit(const DeviceOnboardingLoading());
    try {
      await _repository.onboardDevice(
        category: event.category,
        serialNumber: event.serialNumber,
        deviceName: event.deviceName,
        username: event.username,
        password: event.password,
        mode: event.mode,
      );
      emit(const DeviceOnboardingSuccess());
    } on DeviceOnboardingException catch (e) {
      emit(DeviceOnboardingFailure(message: e.message));
    } catch (e) {
      emit(DeviceOnboardingFailure(message: e.toString()));
    }
  }

  void _onDeviceOnboardReset(
    DeviceOnboardReset event,
    Emitter<DeviceOnboardingState> emit,
  ) {
    emit(const DeviceOnboardingInitial());
  }
}
