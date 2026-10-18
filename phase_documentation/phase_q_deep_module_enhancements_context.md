# Phase Q: Exhaustive Deep Enhancement of Core Enterprise Modules - Context

## Objectives
Perform an exhaustive deep enhancement across the 4 core enterprise modules (Phases M, N, O, P) to eliminate all remaining missing features, UI gaps, and edge cases:
1. **PTZ Preset Controls**: Added PTZ Presets Recall button (`Icons.bookmark_outline`) and `_showPtzPresetsSheet` modal to `VideoTile`.
2. **Emergency Panic Silent Protocol**: Added `SILENT DISPATCH` protocol choice to `_showPanicDialog` in `LiveGridPage`.
3. **Custom Incident Case Watermarks**: Added custom incident case ID text input field in `ExportPage` Export Wizard.
4. **ONVIF Form Auto-Fill**: Updated `DeviceDetailsFormPage` and `router.dart` to auto-fill camera IP and vendor parameters into registration form controllers.

## Key Changes
- **`VideoTile` (`lib/features/live_view/presentation/widgets/video_tile.dart`)**: Integrated Presets popover recall triggering `cameraRepository.presetPtz(...)`.
- **`LiveGridPage` (`lib/features/live_view/presentation/pages/live_grid_page.dart`)**: Integrated Silent Panic protocol countdown dispatch.
- **`ExportPage` (`lib/features/export/presentation/pages/export_page.dart`)**: Added Incident Case Reference ID text field.
- **`DeviceDetailsFormPage` (`lib/features/device_onboarding/presentation/pages/device_details_form_page.dart`)**: Added constructor parameters `initialSerialNumber` and `initialDeviceName` for instant form auto-fill.
