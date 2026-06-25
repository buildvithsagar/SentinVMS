import 'dart:async';
import 'package:app/core/network/websocket_service.dart';
import 'package:app/features/camera/bloc/camera_event.dart';
import 'package:app/features/camera/bloc/camera_state.dart';
import 'package:app/features/camera/data/camera_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CameraBloc extends Bloc<CameraEvent, CameraState> {
  CameraBloc({
    required this.cameraRepository,
    required this.webSocketService,
  }) : super(const CameraInitial()) {
    on<FetchCameras>(_onFetchCameras);
    on<UpdateCameraStatus>(_onUpdateCameraStatus);

    _eventSubscription = webSocketService.eventStream.listen(_onWebSocketEvent);
    _statusSubscription = webSocketService.statusStream.listen(_onWebSocketStatusChanged);
  }

  final CameraRepository cameraRepository;
  final WebSocketService webSocketService;

  late final StreamSubscription<Map<String, dynamic>> _eventSubscription;
  late final StreamSubscription<WebSocketStatus> _statusSubscription;

  String? _lastSiteId;
  WebSocketStatus? _lastStatus;

  Future<void> _onFetchCameras(
    FetchCameras event,
    Emitter<CameraState> emit,
  ) async {
    _lastSiteId = event.siteId;
    emit(const CameraLoading());
    try {
      if (event.siteId != null) {
        webSocketService.subscribeToSite(event.siteId!);
      }

      final cameras = await cameraRepository.getCameras(siteId: event.siteId);
      emit(CameraLoaded(cameras: cameras));
    } catch (e) {
      emit(CameraError(message: e.toString()));
    }
  }

  void _onUpdateCameraStatus(
    UpdateCameraStatus event,
    Emitter<CameraState> emit,
  ) {
    final currentState = state;
    if (currentState is CameraLoaded) {
      final updatedCameras = currentState.cameras.map((camera) {
        if (camera.id == event.cameraId) {
          return camera.copyWith(status: event.status);
        }
        return camera;
      }).toList();
      emit(CameraLoaded(cameras: updatedCameras));
    }
  }

  void _onWebSocketEvent(Map<String, dynamic> event) {
    final eventName = event['event'] as String?;
    final data = event['data'] as Map<String, dynamic>?;
    if (eventName == 'camera.status' && data != null) {
      final cameraId = data['cameraId'] as String?;
      final status = data['status'] as String?;
      if (cameraId != null && status != null) {
        add(UpdateCameraStatus(cameraId: cameraId, status: status));
      }
    }
  }

  void _onWebSocketStatusChanged(WebSocketStatus status) {
    if (_lastStatus != null &&
        _lastStatus != WebSocketStatus.connected &&
        status == WebSocketStatus.connected) {
      add(FetchCameras(siteId: _lastSiteId));
    }
    _lastStatus = status;
  }

  @override
  Future<void> close() {
    _eventSubscription.cancel();
    _statusSubscription.cancel();
    return super.close();
  }
}
