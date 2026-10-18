# Phase M: PTZ Camera Control API Integration - Implementation Plan

## Proposed Changes

### Data & Repository Layer
- [x] Add `movePtz({required String siteId, required String cameraId, required String direction, double speed = 1.0})` to `CameraRepository`.
- [x] Add `zoomPtz({required String siteId, required String cameraId, required String zoomMode, double speed = 1.0})` to `CameraRepository`.
- [x] Add `presetPtz({required String siteId, required String cameraId, required int presetId})` to `CameraRepository`.

### Presentation Layer
- [x] Implement `_handlePtzMove` and `_handlePtzZoom` in `VideoTileState`.
- [x] Connect D-pad directional arrows and zoom buttons to dispatch real PTZ commands.
- [x] Display visual teal active feedback snackbar upon PTZ command dispatch.

### Unit & Integration Testing
- [x] Add `movePtz` unit test to `camera_repository_test.dart`.
- [x] Add `zoomPtz` unit test to `camera_repository_test.dart`.

## Verification Results
- Static Analysis: `flutter analyze` completed with 0 errors/warnings.
- Automated Test Suite: `flutter test` passed all 65 unit and widget tests.
