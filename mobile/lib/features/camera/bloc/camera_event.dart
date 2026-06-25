import 'package:equatable/equatable.dart';

abstract class CameraEvent extends Equatable {
  const CameraEvent();

  @override
  List<Object?> get props => [];
}

class FetchCameras extends CameraEvent {
  const FetchCameras({this.siteId});

  final String? siteId;

  @override
  List<Object?> get props => [siteId];
}

class UpdateCameraStatus extends CameraEvent {
  const UpdateCameraStatus({
    required this.cameraId,
    required this.status,
  });

  final String cameraId;
  final String status;

  @override
  List<Object?> get props => [cameraId, status];
}
