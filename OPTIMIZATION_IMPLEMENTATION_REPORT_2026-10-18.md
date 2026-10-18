# SentinVMS Optimization Implementation Report

Date: 18 October 2026

This report records the implementation completed after the full performance and
UX audit. It deliberately separates completed work from production hardening
that still depends on backend contracts, release infrastructure, or physical
device measurements.

## Completed in this pass

### Runtime configuration and networking

- Added an explicit default `demo` environment so the hiring build does not
  wait for an unavailable control-plane backend before showing fixture data.
- Routed Dio and Socket.io through `AppConfig` instead of conflicting constants.
- Reduced interactive HTTP timeouts and demo retries; real builds use one retry.
- Restricted automatic retry to idempotent requests unless a request explicitly
  opts in, preventing accidental duplicate POST actions.
- Fixed API base URL normalization so relative endpoints resolve below
  `/api/v5/` consistently.
- Restored the operating-system TLS trust store when no pin certificates are
  configured. An empty custom trust store is no longer created.
- Disabled control-plane WebSocket and Internet polling in demo mode. Local CCTV
  playback can continue without a public Internet connection.
- Reworded the connectivity banner to distinguish control-plane reachability
  from local-video reachability.
- Real camera repository failures now surface as failures instead of silently
  becoming demo data or fake PTZ/panic success.

### Camera data and decoder efficiency

- Added a 30-second shared camera cache and concurrent-request coalescing. Live
  Grid, Cameras, Playback, and Export no longer need to issue duplicate camera
  directory requests when they open together.
- Made the hardware-decoder budget configurable with `MAX_VIDEO_DECODERS` and
  changed the mobile default from nine to four.
- Decoder eviction, release, logout cleanup, and controller disposal are now
  awaited, avoiding temporary overlap between old and replacement decoders.

### Player rendering and lifecycle

- Replaced controller-driven page `setState` loops in RTSP, HLS, and gateway HLS
  players with small `ValueListenableBuilder` regions.
- Playback position now updates a timeline notifier instead of rebuilding the
  complete playback page every second.
- Live-grid players stop and reinitialize across app background/resume.
- Direct RTSP and standalone HLS pause in the background and resume only if they
  were playing before the lifecycle change.
- Gateway WebRTC/HLS sessions are released on background and recreated on
  resume, including server-side DELETE cleanup.
- Removed continuous blinking live dots and pulsing selection animations from
  the video grid.

### Stream Diagnostics and real CCTV input

- Normalizes uppercase RTSP/RTSPS schemes.
- Handles raw `@` characters inside CCTV passwords by encoding user-info while
  preserving the final host separator; already encoded passwords are not
  double encoded.
- Masks the camera URL by default and adds a show/hide action.
- Raw VLC/HLS error strings are no longer rendered, reducing credential and
  signed-URL leakage.
- The preview header no longer reports a live session merely because a source
  object was created; each player exposes connecting/live/error state.
- Direct RTSP remains available for the fastest local test. Smart Gateway
  remains the compatibility route for H.265 cameras.

### Local Media Gateway

- Smart Gateway now requests `auto` transcoding: H.264 passes through and H.265
  is converted to phone-compatible H.264.
- Flutter's gateway timeout is now longer than the server's probe plus startup
  contract.
- Added failed-process cleanup, natural-exit cleanup, a configurable maximum
  stream count, and a 30-minute orphan-stream reaper.
- H.265 output is bounded to at most 1280 pixels wide, 20 fps, and a controlled
  bitrate to reduce laptop CPU and network load.
- Docker startup generates a cryptographically random gateway access token.
- Docker no longer publishes MediaMTX's RTSP ingest port on the host.
- Added a native Windows mode that does not require Docker or WSL:
  `Install-Gateway-Tools.ps1`, `Start-Gateway-Native.ps1`, and
  `Stop-Gateway-Native.ps1`.
- Native mode binds MediaMTX ingest and API ports to localhost, starts hidden
  processes, writes bounded operational logs, and records validated process IDs
  for safe shutdown.

### UX cleanup

- Reduced login entrance, OTP, and successful-verification delays.
- Removed the large collection of fake Live Grid actions that only toggled
  local labels or displayed simulated success.
- Kept a compact toolbar containing layout, playback, real PTZ, fullscreen, and
  remove-camera actions.
- Removed backdrop blur above active video surfaces.
- Enlarged PTZ direction controls to 48 logical pixels and added tooltips.
- Fixed the broken playback export route (`/export` to `/exports`).
- Primary bottom navigation now uses one `go` policy instead of mixing push and
  replacement behavior.

## Verification evidence

- Mobile static analysis: **clean, no issues** after the final changes.
- Mobile Flutter tests: **87/87 passed** after the primary optimization pass.
- A camera-cache regression test was then added. The final source remains
  analyzer-clean; a subsequent full rerun was blocked by a local Flutter runner
  process hang before test output, so that last added test still needs one clean
  rerun on the developer machine.
- Gateway static analysis: **clean, no issues**.
- Gateway unit tests: **5/5 passed** after the final transcode constraints.
- All four PowerShell gateway scripts pass PowerShell AST syntax parsing.
- The supplied real H.265 camera flow had previously been verified end to end:
  H.265 RTSP input, H.264 gateway delivery, and a reachable HLS playlist.

## Current interview run paths

### Without Docker/WSL

```powershell
cd C:\Users\SAGAR\vmsapp\SentinVMS\local_media_gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-Gateway-Tools.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Start-Gateway-Native.ps1
```

In the app, open **RTSP / Server Test**, select **Smart Gateway**, enter the
printed gateway URL and token, paste the CCTV RTSP URL, keep compatibility mode
enabled, and connect.

### Direct RTSP

Open **RTSP / Server Test**, keep **Direct RTSP** selected, paste the RTSP URL,
and connect. This is the fastest route but H.265 success depends on the phone's
VLC/native decoder. Smart Gateway is the deterministic H.265 fallback.

## Remaining production work

The app is materially faster and safer for the hiring demo, but the following
items are not honestly complete production features:

- Authentication, alarm REST data, ONVIF discovery/onboarding, and parts of
  export are still prototype/demo implementations pending final backend APIs.
- The HLS decoder pool is global, but WebRTC and VLC are not yet governed by one
  unified cross-protocol media budget.
- A shared state-preserving primary navigation shell and breakup of the largest
  page files remain architectural work.
- Android release signing, production-vs-demo cleartext policy, iOS local
  network permissions, TURN/TLS, MediaMTX viewer authorization, and gateway
  rate limiting remain release hardening work.
- Profile-mode measurements on the actual interview phone are still required
  for first-frame time, frame budget, memory recovery, CPU, and thermal targets.

These remaining items should not block the controlled direct-RTSP or local
Smart Gateway hiring demonstration.
