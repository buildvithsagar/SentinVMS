# Phase Q: Exhaustive Deep Enhancement of Core Enterprise Modules - Implementation Plan

## Proposed Changes

### Module 1: PTZ Presets
- [x] Add PTZ Presets Recall button to Zoom toolbar in `VideoTile`.
- [x] Build `_showPtzPresetsSheet` modal in `VideoTileState` calling `cameraRepository.presetPtz(...)`.
- [x] Add `presetPtz` unit test to `camera_repository_test.dart`.

### Module 2: Emergency Panic
- [x] Add `SILENT DISPATCH` button to `_showPanicDialog` in `LiveGridPage`.

### Module 3: Export Vault
- [x] Add Incident Case Reference ID text field to Export Wizard in `ExportPage`.

### Module 4: Device Onboarding
- [x] Add `initialSerialNumber` and `initialDeviceName` auto-fill parameters to `DeviceDetailsFormPage`.
- [x] Update `/onboard/register` route parameters in `router.dart`.
- [x] Pass encoded `categoryName` queryParameter from `onboarding_mode_sheet.dart`.

## Verification Results
- Static Analysis: `flutter analyze` completed with 0 errors/warnings.
- Automated Test Suite: `flutter test` passed all 71 unit and widget tests.
