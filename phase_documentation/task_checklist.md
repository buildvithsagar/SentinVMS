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
