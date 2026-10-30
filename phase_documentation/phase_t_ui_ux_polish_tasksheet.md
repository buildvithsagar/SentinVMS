# Phase T Tasksheet: UI/UX Subtle Dark Glassmorphism, Manual RTSP & Device Code Autofill

- `[x]` T.1: Build unified `vms_ui.dart` and `vms_navigation_bar.dart` with Subtle Dark Glassmorphism tokens (`#0F172A`, `#2DD4BF`, `BackdropFilter` $\sigma=10$).
- `[x]` T.2: Refactor `VmsDrawer`, `LiveGridPage`, `CameraListPage`, `PlaybackPage`, `AlarmListPage`, and `ExportPage` to adopt unified glass design.
- `[x]` T.3: Implement `RtspUri` parser and validator (`rtsp_uri.dart`) with credential masking and URI normalization.
- `[x]` T.4: Create `LocalCameraStore` with encrypted persistence using `SecureStorageService`.
- `[x]` T.5: Build `ManualRtspCameraPage` and direct RTSP stream playback integration in `DirectRtspVideoTile`.
- `[x]` T.6: Implement `DeviceCodePayload` scanner model for QR/barcode autofill in onboarding.
- `[x]` T.7: Add comprehensive unit and widget tests for `RtspUri`, `LocalCameraStore`, `DeviceCodePayload`, and `ConnectivityBanner`.

