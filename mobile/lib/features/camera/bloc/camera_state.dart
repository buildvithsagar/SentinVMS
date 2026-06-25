import 'package:app/features/camera/models/camera_model.dart';
import 'package:equatable/equatable.dart';

abstract class CameraState extends Equatable {
  const CameraState();

  @override
  List<Object?> get props => [];
}

class CameraInitial extends CameraState {
  const CameraInitial();
}

class CameraLoading extends CameraState {
  const CameraLoading();
}

class CameraLoaded extends CameraState {
  const CameraLoaded({required this.cameras});

  final List<Camera> cameras;

  @override
  List<Object?> get props => [cameras];
}

class CameraError extends CameraState {
  const CameraError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
