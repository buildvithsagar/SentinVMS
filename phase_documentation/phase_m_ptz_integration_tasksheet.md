# Phase M: PTZ Camera Control API Integration - Tasksheet

| Task ID | Task Description | Target File | Status |
|---|---|---|---|
| TASK-M-001 | Add `movePtz`, `zoomPtz`, `presetPtz` to `CameraRepository` | `mobile/lib/features/camera/data/camera_repository.dart` | Completed |
| TASK-M-002 | Implement `_handlePtzMove` and `_handlePtzZoom` in `VideoTileState` | `mobile/lib/features/live_view/presentation/widgets/video_tile.dart` | Completed |
| TASK-M-003 | Connect D-pad directional and zoom buttons to real API handlers | `mobile/lib/features/live_view/presentation/widgets/video_tile.dart` | Completed |
| TASK-M-004 | Add PTZ unit tests to `camera_repository_test.dart` | `mobile/test/unit/camera_repository_test.dart` | Completed |
| TASK-M-005 | Verify zero static analysis issues | `mobile/` | Completed |
| TASK-M-006 | Verify all unit & widget tests pass | `mobile/` | Completed |
| TASK-M-007 | Generate Phase M documentation artifacts | `phase_documentation/` | Completed |
