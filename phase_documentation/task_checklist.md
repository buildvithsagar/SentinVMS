# VMS Flutter Client — Phase 1 Micro-Phases Checklist

## ── Micro-Phase A: Security, Auth & Storage (Foundation) ──
- `[x]` A.1: Configure project dependencies & strict analysis rules (`very_good_analysis`)
- `[x]` A.2: Create folder directory structure (`core/`, `features/`, etc.)
- `[x]` A.3: Implement native Android secure storage platform channel (`SecureStoragePlugin.kt`)
- `[x]` A.4: Implement native iOS secure storage platform channel (`SecureStoragePlugin.swift`)
- `[x]` A.5: Implement Dart `SecureStorageService` wrapper
- `[x]` A.6: Implement `DioFactory` with SPKI Intermediate CA pinning (and `--dart-define=BYPASS_PINNING=true` toggle)
- `[x]` A.7: Implement `RefreshTokenInterceptor` with Dart `Completer`-based `RefreshLock`
- `[x]` A.8: Implement `AuthBloc` (Volatile token management & tenant/role mapping)
- `[x]` A.9: Build LoginPage & MFA UI (Tactical Dark Industrial Palette)
- `[x]` A.10: Write unit/widget tests for secure storage, SPKI pinning, and RefreshLock

## ── Micro-Phase B: Camera Registry & Status Telemetry (Metadata) ──
- `[x]` B.1: Implement Camera API integration in `CameraRepository` (`GET /api/v5/cameras`)
- `[x]` B.2: Implement `CameraBloc` to fetch and list sharded camera directories
- `[x]` B.3: Build Camera List UI (organized by site hierarchies)
- `[x]` B.4: Implement WebSocket background service connecting to Vivek's WSS broadcaster
- `[x]` B.5: Implement real-time camera status listener updating online/offline states (`#02965E` / `#D32F2F`)
- `[x]` B.6: Write mock API tests and WebSocket state reconciliation tests

## ── Micro-Phase C: Live Grid & Decoder Semaphore (Video Rendering) ──
- `[x]` C.1: Implement `DecoderPool` semaphore service (cap of 4 concurrent streams)
- `[x]` C.2: Implement FIFO/LRU auto-eviction logic in `DecoderPool`
- `[x]` C.3: Build `VideoTile` widget using native `Texture` rendering and `RepaintBoundary`
- `[x]` C.4: Build Live Grid Viewport supporting 1x1 and 2x2 grid views
- `[x]` C.5: Integrate non-functional PTZ overlay stub controls (arrows & zoom UI)
- `[x]` C.6: Write unit tests for DecoderPool lease limits and auto-eviction behaviors

## ── Micro-Phase D: Timeline Playback, Alarms & Exports (Operations) ──
- `[x]` D.1: Build color-coded Timeline Scrubber widget (Blue = Continuous, Orange = Motion, Green = Scheduled)
- `[x]` D.2: Implement interactive seek pre-buffering (load signed HLS URLs on handle drop)
- `[x]` D.3: Build Playback Speed controls (0.5x to 16x multiplier)
- `[x]` D.4: Implement `AlarmBloc` capturing WebSocket events in foreground and FCM in background
- `[x]` D.5: Implement Alarm List UI and Reconciliation on Resume API syncing
- `[x]` D.6: Build Evidence Export Wizard UI (initiator, status poller, and platform share sheet)
- `[x]` D.7: Write tests for timeline seeks, WebSocket alarms, and export poller flows

## ── Micro-Phase E: Dashboard Redesign (Feature 30) ──
- `[x]` E.1: Implement tactical Live Viewport grid with clean slot indicators, quick control toolbars, action shortcuts, and sliding Alarm Messages panel.

## ── Micro-Phase K: Memory Leak Remediation ──
- `[x]` K.1: Implement try-catch-finally and `didUpdateWidget` in `VideoTile` for stream decoder cleanup.
- `[x]` K.2: Implement seek request sequencing (`_seekRequestId`) in `PlaybackPage` for rapid scrubbing safety.
- `[x]` K.3: Implement duplicate camera lease auto-eviction and session clear on logout in `DecoderPool`.
- `[x]` K.4: Clear `_subscribedSites` set on disconnect in `WebSocketService`.
- `[x]` K.5: Cap real-time alert buffer to 200 items in `AlarmBloc`.
- `[x]` K.6: Add `ValueKey` to `VideoTile` instances and cancel periodic timers on unmount in `LiveGridPage` and `ExportPage`.

## ── Micro-Phase L: Feature-First Clean Architecture Restructuring ──
- `[x]` L.1: Reorganize all UI screen pages into dedicated `presentation/pages/` subdirectories.
- `[x]` L.2: Create feature barrel export files (`core.dart`, `login.dart`, `live_view.dart`, `camera.dart`, `alarms.dart`, `playback.dart`, `export.dart`, `device_onboarding.dart`).
- `[x]` L.3: Refactor all import references across `lib/` and `test/` to use modular barrel exports.
- `[x]` L.4: Verify zero static analysis errors (`flutter analyze`) and 100% test suite pass rate (`flutter test`).

## ── Micro-Phase M: PTZ Camera Control API Integration ──
- `[x]` M.1: Implement `movePtz`, `zoomPtz`, and `presetPtz` in `CameraRepository`.
- `[x]` M.2: Connect D-pad directional and zoom overlay buttons in `VideoTile` with active teal feedback.
- `[x]` M.3: Add PTZ unit tests to `camera_repository_test.dart`.

## ── Micro-Phase N: Emergency Panic Control Room Dispatch API ──
- `[x]` N.1: Implement `dispatchEmergencyPanic` in `CameraRepository`.
- `[x]` N.2: Connect 5s countdown completion overlay in `LiveGridPage` with crimson alert feedback.
- `[x]` N.3: Add `dispatchEmergencyPanic` unit test to `camera_repository_test.dart`.

## ── Micro-Phase O: Video Evidence Export Sharing & Saver ──
- `[x]` O.1: Implement `verifyClipIntegrity` in `ExportRepository`.
- `[x]` O.2: Add "SHARE EVIDENCE" button and `_showEvidenceShareSheet` glassmorphic modal in `ExportPage`.
- `[x]` O.3: Build `export_repository_test.dart` test suite.

## ── Micro-Phase P: ONVIF Subnet Packet Scanner & Discovery ──
- `[x]` P.1: Create `DiscoveredOnvifDevice` model & `scanSubnetForOnvifDevices` in `DeviceOnboardingRepository`.
- `[x]` P.2: Connect category card taps in `DeviceCategoryPage` to UDP WS-Discovery subnet scanner dialog and discovered cameras modal.
- `[x]` P.3: Build `device_onboarding_repository_test.dart` test suite.

## ── Micro-Phase Q: Exhaustive Deep Enhancement of Core Enterprise Modules ──
- `[x]` Q.1: Add PTZ Presets Recall button and `_showPtzPresetsSheet` modal to `VideoTile`.
- `[x]` Q.2: Add `SILENT DISPATCH` button option to `_showPanicDialog` in `LiveGridPage`.
- `[x]` Q.3: Add Incident Case Reference ID text field to Export Wizard in `ExportPage`.
- `[x]` Q.4: Support instant ONVIF form auto-fill in `DeviceDetailsFormPage`, `router.dart`, and `onboarding_mode_sheet.dart`.

## ── Micro-Phase R: Enterprise Data Structures & Algorithmic Optimizations ──
- `[x]` R.1: Upgrade `DecoderPool` to `LinkedHashMap<String, DecoderLease>` for $O(1)$ LRU eviction.
- `[x]` R.2: Implement `findSegmentAtTime` in `PlaybackRepository` using $O(\log N)$ Binary Search and integrate into `PlaybackPage`.
- `[x]` R.3: Upgrade `AlarmBloc` real-time threat ingestion to `DoubleLinkedQueue` for $O(1)$ Deque push and eviction.

## ── Micro-Phase S: Fullscreen Responsive Matrix Grid & Viewport Auto-Fitting ──
- `[x]` S.1: Implement `_buildMatrixGrid` dynamic `LayoutBuilder` matrix calculation.
- `[x]` S.2: Wrap fullscreen Scaffold in `SafeArea` to prevent notch/punch-hole camera collision.
- `[x]` S.3: Support smooth orientation handling for both Portrait and Landscape fullscreen modes.
- `[x]` S.4: Verify zero static analysis issues and 100% test suite pass rate.


## ── Micro-Phase T: Subtle Dark Glassmorphism Polish, Manual RTSP & Device Code Autofill ──
- `[x]` T.1: Build unified `vms_ui.dart` and `vms_navigation_bar.dart` with Subtle Dark Glassmorphism tokens (`#0F172A`, `#2DD4BF`, `BackdropFilter` $\sigma=10$).
- `[x]` T.2: Refactor `VmsDrawer`, `LiveGridPage`, `CameraListPage`, `PlaybackPage`, `AlarmListPage`, and `ExportPage` to adopt unified glass design.
- `[x]` T.3: Implement `RtspUri` parser and validator (`rtsp_uri.dart`) with credential masking and URI normalization.
- `[x]` T.4: Create `LocalCameraStore` with encrypted persistence using `SecureStorageService`.
- `[x]` T.5: Build `ManualRtspCameraPage` and direct RTSP stream playback integration in `DirectRtspVideoTile`.
- `[x]` T.6: Implement `DeviceCodePayload` scanner model for QR/barcode autofill in onboarding.
- `[x]` T.7: Add comprehensive unit and widget tests for `RtspUri`, `LocalCameraStore`, `DeviceCodePayload`, and `ConnectivityBanner`.
