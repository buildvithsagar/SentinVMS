# Phase N: Emergency Control Room Panic Dispatch API Integration - Context

## Objectives
Connect the 5-second cancelable Emergency Panic Alert modal and overlay in `LiveGridPage` to a real API dispatcher method in `CameraRepository`. Upon countdown completion, dispatch `POST /api/v5/emergency/dispatch` with emergency protocol parameters (Siren, Silent Alarm, Control Room Call), operator ID, site ID, and timestamp.

## Key Changes
- **`CameraRepository` (`lib/features/camera/data/camera_repository.dart`)**: Added `dispatchEmergencyPanic({required String protocol, required String operatorId, String? siteId, String? cameraId})` targeting `POST /emergency/dispatch`.
- **`LiveGridPage` (`lib/features/live_view/presentation/pages/live_grid_page.dart`)**: Updated `_startPanicCountdown` to invoke `GetIt.instance<CameraRepository>().dispatchEmergencyPanic(...)` upon countdown reaching 0 with crimson alert feedback.
- **Unit Tests (`test/unit/camera_repository_test.dart`)**: Added unit test for `dispatchEmergencyPanic` verifying HTTP POST options and body parameters.
