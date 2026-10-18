# Phase M: PTZ Camera Control API Integration - Context

## Objectives
Connect the Pan-Tilt-Zoom (PTZ) directional controls and zoom buttons in `VideoTile` and `LiveGridPage` to real network dispatch endpoints in `CameraRepository`. Replace Phase 1 stub toasts with real network methods (`movePtz`, `zoomPtz`, `presetPtz`), visual active feedback, error reporting, and unit test coverage.

## Key Changes
- **`CameraRepository` (`lib/features/camera/data/camera_repository.dart`)**: Added `movePtz`, `zoomPtz`, and `presetPtz` API methods targeting `POST /sites/{siteId}/cameras/{cameraId}/ptz/*`.
- **`VideoTile` (`lib/features/live_view/presentation/widgets/video_tile.dart`)**: Updated directional D-pad arrows (Pan Up, Pan Down, Tilt Left, Tilt Right) and Zoom In / Zoom Out buttons to invoke `_handlePtzMove` and `_handlePtzZoom` with visual teal feedback toasts.
- **Unit Tests (`test/unit/camera_repository_test.dart`)**: Added unit tests for `movePtz` and `zoomPtz` verifying HTTP POST options and payloads.
