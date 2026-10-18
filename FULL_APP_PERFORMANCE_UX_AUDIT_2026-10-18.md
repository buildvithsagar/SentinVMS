# SentinVMS Full App Performance and UX Audit

Date: 18 October 2026  
Scope: Flutter mobile app, Android/iOS configuration, live video path, and local MediaMTX/FFmpeg gateway  
Audit type: static code/configuration review plus existing build/test evidence. No optimization code was changed during this audit.

## Executive summary

The app is a capable prototype, but it is not yet production-optimized. The RTSP hiring-demo path is technically viable and the real H.265 camera gateway flow has already been proven, but the surrounding app mixes prototype behavior, fake controls, real networking, and production-looking UI. That mixture creates most of the perceived slowness and trust problems.

Current audit ratings:

| Area | Rating | Main reason |
|---|---:|---|
| Functional prototype | 7/10 | Major screens and the direct/gateway stream paths exist |
| Runtime performance | 4.5/10 | Long network fallback, large rebuild scopes, many simultaneous decoders |
| UX consistency | 5/10 | Good visual direction, but inconsistent navigation, styling, feedback, and fake actions |
| Maintainability | 4/10 | Several 800-1,800 line stateful pages and UI-owned business logic |
| Production readiness | 3/10 | Demo authentication/data, permissive networking, missing lifecycle work, release config incomplete |
| Hiring-demo readiness | 6/10 | Gateway works, but stream input normalization, startup feedback, and demo stability need hardening |

The app does not need a rewrite. It needs a staged stabilization and optimization pass, starting with networking/configuration and live-stream lifecycle before visual polishing.

## What is already working

- Direct RTSP playback exists through VLC with TCP transport and hardware acceleration.
- Smart Gateway mode exists: RTSP input -> FFmpeg/MediaMTX -> WebRTC, with HLS fallback.
- H.265 input is detected and can be transcoded to H.264 for phone compatibility.
- The real supplied H.265 CCTV stream was successfully probed and routed through the gateway; the gateway reported H.265 input, H.264 delivery, transcoding enabled, and a reachable HLS playlist.
- Player and stream resources generally have explicit cleanup paths.
- Camera, alarm, playback, export, onboarding, login, and diagnostics screens exist.
- Unit/widget coverage exists for important repositories, blocs, the live grid, login, timeline, decoder pool, and stream URL parsing.
- The centralized `VmsTheme` introduced a good base palette and component theme for future consolidation.

## Why the app feels slow

### P0: Backend failure can make the camera list wait tens of seconds

Evidence:

- `mobile/lib/core/constants/app_constants.dart:16-17` uses 10 second connect and 30 second receive timeouts.
- `mobile/lib/core/network/dio_retry_interceptor.dart:10-14` adds 1, 2, and 4 second retry delays and allows three retries.
- `mobile/lib/features/camera/data/camera_repository.dart:32-38` returns demo cameras only after the network request has failed.

A connection-timeout path can take approximately 47 seconds before fallback: four connection attempts of up to 10 seconds plus 7 seconds of backoff. A receive-timeout path can be even longer. The UI shows a loader during this period, so the user experiences it as a slow app.

Required fix:

- Separate explicit `demo`, `local`, `staging`, and `production` modes.
- In demo mode, never call the unreachable backend before loading fixtures.
- In real mode, use shorter fail-fast timeouts for interactive screens and show retry/offline actions.
- Retry only idempotent requests and make retries cancelable when the screen is left.

### P0: Environment configuration is split and TLS is likely misconfigured

Evidence:

- `mobile/lib/core/config/app_config.dart` is initialized in `main.dart`, but the Dio and WebSocket clients read `AppConstants`, not `AppConfig`.
- `AppConfig` defaults production to the production URL, while `AppConstants` defaults to staging.
- `mobile/lib/main.dart:43-47` supplies an empty trusted-CA list.
- `mobile/lib/core/network/dio_factory.dart:42-49` creates a clean `SecurityContext` and adds only supplied custom certificates.

The selected environment can therefore be ignored, and an empty custom trust store can reject normal HTTPS certificates unless the bypass define is enabled. This can silently push normal flows into the slow retry/fallback path.

Required fix:

- Keep one typed runtime configuration source.
- Use system roots by default; enable certificate pinning only when real pins/certificates are supplied.
- Validate configuration at startup and visibly identify demo/local builds.

### P0: Gateway server and Flutter client timeouts do not agree

Evidence:

- Gateway FFprobe may run for 15 seconds: `local_media_gateway/lib/src/stream_manager.dart:123-136`.
- Media startup can then wait another 25 seconds: `gateway_config.dart:33-35` and `stream_manager.dart:147-165`.
- Flutter gateway receive timeout is 35 seconds: `mobile/lib/features/stream_demo/data/local_gateway_client.dart:10-12`.

The server is allowed roughly 40 seconds, while the client can give up at 35 seconds. On a slow camera, the app can report failure while FFmpeg continues starting on the PC, potentially leaving an orphan stream.

Required fix:

- Make stream creation asynchronous: return `202 + streamId`, then poll or subscribe to status.
- Alternatively, set a shared end-to-end timeout contract with client cancellation cleanup.
- Expose stages such as probing, transcoder starting, MediaMTX publishing, and ready.

### P0: Player controllers trigger broad, frequent rebuilds

Evidence:

- Direct RTSP calls page-level `setState` from the VLC controller listener: `rtsp_player_pane.dart:40-42`.
- HLS calls `setState` from the video controller listener: `hls_player_pane.dart:37-39`.
- Gateway HLS does the same: `local_gateway_player_pane.dart:127-129`.
- Playback updates a nearly 1,000-line page every second: `playback_page.dart:234-246`.

Video controllers update frequently. Rebuilding the full player column or full playback screen for position/buffer changes wastes UI-thread time and increases jank risk.

Required fix:

- Rebuild only the tiny control/status region with `ValueListenableBuilder`, a selector, or a throttled position notifier.
- Keep the video surface and static page tree outside changing builders.
- Add repaint profiling before and after the change.

### P0: The live grid can exceed real device decoder capacity

Evidence:

- The UI allows 1, 4, 9, or 16 simultaneous tiles.
- `main.dart:73` configures nine HLS decoders.
- The decoder pool only controls `VideoPlayerController` HLS instances; WebRTC renderers and the standalone VLC player are not pooled.
- Switching from a multi-grid to 1x1 removes other tiles, disposes their sessions, and switching back recreates them, causing network and decoder churn.

Nine or sixteen live 1080p feeds are beyond the reliable hardware-decoder budget of many phones. WebRTC sessions are effectively unlimited by the current pool.

Required fix:

- Create one global media-session budget covering WebRTC, HLS, and VLC.
- Use camera sub-streams in multi-grid and main-stream only in focus mode.
- Pause invisible tiles without destroying them immediately; apply a short keep-alive window.
- Adapt the available grid sizes to device capability and measured thermals/memory.

### P1: Continuous visual effects add avoidable GPU work

Evidence:

- Each live tile owns a blinking animation controller: `video_tile.dart:473-515`.
- The selected grid slot paints a pulsing border and shadow continuously: `live_grid_page.dart:1709-1797`.
- Bottom navigation places a blur over a live-video screen: `live_grid_page.dart:609-664`.
- Seven `BackdropFilter` instances and six animation controllers exist in the app.
- Login animates the main form tree for 2.2 seconds.

Required fix:

- Replace continuous status animation with a static state indicator or a low-frequency animation.
- Remove blur over video surfaces; use an opaque/translucent solid surface.
- Honor reduced-motion accessibility settings.
- Keep animations below 200-300 ms for routine transitions.

### P1: Mandatory animation makes startup and login feel artificially slow

Evidence:

- Login entrance animation lasts 2.2 seconds: `login_page.dart:64-102`.
- OTP transition adds 700 ms.
- Successful verification adds a 1 second animation plus a 300 ms delay before navigation: `login_page.dart:310-325`.

Even instant demo authentication therefore feels delayed. These waits do not represent useful work.

Required fix:

- Show the usable form immediately; animation should not gate interaction.
- Navigate immediately after successful authentication, or cap confirmation feedback at about 200-300 ms.
- Use the native splash only for actual startup work.

### P1: Debug APK and native media libraries are very large

Observed artifacts:

- Universal debug APK: 331.88 MiB.
- ABI-specific debug APKs: 116.60-147.92 MiB.
- Largest native payload is VLC (`libvlc.so`), followed by Flutter, WebRTC, and barcode-scanner native libraries.
- App image assets total only 2.99 MiB, so image compression is not the main size problem.

This is a debug-build measurement, not Play Store download size. Running the app in debug also adds JIT, assertions, service protocol, and instrumentation overhead, so judging final smoothness from `flutter run` debug mode is misleading.

Required fix:

- Profile performance with `flutter run --profile` on the interview phone.
- Distribute an arm64 release APK or Android App Bundle, not the universal debug APK.
- Use ABI splits for sideloading.
- Long term, decide whether both embedded VLC and embedded WebRTC are required in the production flavor.

### P1: H.265 gateway transcoding can saturate the PC

Evidence:

- Each incompatible stream launches a separate software `libx264` process.
- No resolution, bitrate, frame-rate, or thread ceiling is applied.
- Smart Gateway defaults to `transcode: always`, so even H.264 can be unnecessarily re-encoded.
- Gateway permits four streams by default.

Four 1080p H.265-to-H.264 software transcodes can consume substantial CPU, producing delayed frames and buffering.

Required fix:

- Use `auto` by default and transcode only H.265/incompatible sources.
- Add configurable output resolution/FPS/bitrate, especially for grid sub-streams.
- Prefer available hardware encoders after capability detection; keep software fallback.
- Expose CPU/load and per-stream FFmpeg failure reason in gateway diagnostics.

## UX and product issues

### P0: Several controls claim success without performing the action

Examples in `live_grid_page.dart`:

- Global play/pause only toggles `_isPlaying`; it does not control players.
- HD/SD only changes a label.
- Mute, star, talkback, local recording, and instant playback mostly change local UI state.
- Snapshot shows a placeholder and reports saved/shared without capturing a frame.
- One PTZ overlay sends real repository calls, while a second overlapping PTZ overlay only shows snackbars.
- Panic, PTZ, and integrity-related repository methods swallow failures or return demo success.

This is the biggest interview risk: an evaluator can tap a professional-looking control and discover that it is simulated.

Required fix:

- Remove or visibly label unavailable controls in the demo build.
- Keep only actions that are fully wired end to end.
- Never show “saved”, “dispatched”, “verified”, or “success” before confirmed completion.

### P0: Demo and production behavior are mixed

Evidence:

- Login is fully detached from the backend and accepts mock credentials.
- Demo credentials and OTP are prefilled and shown in helper text.
- Alarms are always mock data.
- Device discovery and onboarding only wait 600/500 ms and return fixtures/do nothing.
- Camera, playback, and export repositories sometimes call a real backend and sometimes silently fall back.
- Demo stream fallback defaults to enabled at compile time.

Required fix:

- Create explicit app flavors with a visible `DEMO` badge.
- Production flavor must never silently convert a failed operation into fake success.
- Centralize fixture repositories behind interfaces instead of embedding fallback in production repositories.

### P0: Stream input is fragile for real-world CCTV URLs

Evidence:

- URL validation is case-sensitive for the scheme.
- Credentials containing reserved characters such as `@` are not normalized/encoded.
- The RTSP URL field displays credentials as ordinary text.
- The preview header becomes green as soon as a source object exists, before the stream is actually live.

Required fix:

- Normalize scheme casing and safely encode user-info while preserving the final host separator.
- Mask credentials in the field, error messages, analytics, and logs.
- Add a show/hide button and a sanitized URL preview.
- Drive preview status from actual player state: connecting, live, fallback, failed, stopped.

### P1: Navigation is inconsistent and contains a broken route

Evidence:

- Live Grid and Cameras show both drawer and bottom navigation.
- Playback, Alarms, and Exports use back navigation instead of the same app shell.
- Diagnostics has a drawer but no bottom navigation.
- Bottom navigation mixes `go` and `push`, creating inconsistent back-stack behavior.
- Playback redirects to `/export`, but only `/exports` is declared: `playback_page.dart:66` versus `router.dart:112`.

Required fix:

- Use a `StatefulShellRoute` or one shared scaffold for primary tabs.
- Use one navigation policy and retain each tab's state.
- Treat onboarding and stream diagnostics as secondary routes.

### P1: Accessibility is not implemented

Evidence:

- No explicit `Semantics`, `MergeSemantics`, or semantic labels were found in app code.
- Multiple PTZ and toolbar targets are 28-32 px and use `shrinkWrap`, below the normal 44-48 px touch target.
- Important state relies heavily on color and 8-11 px text.
- Continuous animation does not respect reduced-motion preferences.

Required fix:

- Add semantic labels, roles, selected/live/error state, and logical focus order.
- Enforce at least 48x48 logical-pixel touch targets.
- Raise operational text to readable sizes and supplement color with text/icons.
- Test at large font scale and with TalkBack/VoiceOver.

### P1: Visual design is split between two systems

Evidence:

- A centralized forest-green `VmsTheme` exists.
- Older screens still hardcode blue/slate colors, shapes, type sizes, snackbars, and backgrounds.
- Source contains 391 hardcoded color declarations.
- The largest pages contain 45-85 color declarations each.

Result: Stream Diagnostics looks like a newer product than Live Grid, Cameras, Playback, Alarms, and Exports.

Required fix:

- Move all surfaces, spacing, radii, typography, state colors, and control sizes into design tokens.
- Build shared app shell, page header, status badge, error/empty/loading state, and bottom sheet components.
- Apply the design system screen-by-screen after functional stabilization.

### P1: Information architecture is too dense for a phone

- Live Grid stacks an assignment bar, video grid, two action rows, camera status, alarm drawer, bottom navigation, and panic overlay on one screen.
- In 3x3/4x4 mode, labels and controls become too small to operate reliably.
- Camera cards show technical IDs/IP/profile/codec but do not open a details or live-view action.
- Error messages often expose exception strings rather than telling the operator what to do next.

Required fix:

- Make video the dominant surface.
- Show actions contextually for the selected camera in a bottom sheet.
- Keep only layout, mute, focus, snapshot, and overflow in the main toolbar.
- Make camera rows actionable: preview, details, edit, diagnostics.
- Convert errors into concise cause + next action + retry/details.

### P2: Connectivity banner is wrong for a local-only VMS

`connectivity_service.dart:31-44` resolves `dns.google` every 10 seconds. A phone can have no internet but still reach the CCTV and gateway over LAN, so the app may display “network lost” while local video works. The lookup also wakes the radio periodically.

Required fix:

- Track internet, control-plane, gateway, and camera reachability separately.
- Show only the status relevant to the current feature.
- Trigger checks from connectivity changes and exponential backoff, not permanent fixed polling.

## Architecture and code-health findings

The mobile `lib` folder currently contains 74 Dart files and about 14,680 lines. High-risk pages are:

| File | Lines | `setState` calls | Concern |
|---|---:|---:|---|
| Live Grid | 1,797 | 24 | Streaming, PTZ, panic, grid, alarms, nav, and controls in one state object |
| Export | 1,080 | 13 | Form, history, polling, dialogs, and cards coupled together |
| Playback | 987 | 22 | Player lifecycle, timeline, trimming, export, selectors, and UI coupled |
| Login | 887 | 4 | Large animated tree and three animation workflows |
| Stream Diagnostics | 809 | 4 | Better structured, but still a large single page file |

Additional findings:

- There are 88 `setState` calls and 26 silent `catch (_)` blocks in app source.
- UI pages access GetIt repositories directly, making cancellation, caching, testing, and state reuse harder.
- Camera data is fetched independently by Live Grid, Cameras, Playback, and Export instead of through a cached shared store.
- The app lifecycle observer logs pause/resume but does not actually pause video, WebSocket, polling, or decoders.
- Auth state and user session are not restored on startup, despite having secure refresh-token infrastructure.
- The global alarm bloc is reused and receives `FetchAlarms` as a route-builder side effect, which can replace real-time state.
- Search filters and groupings are recomputed inside build; harmless for nine demo cameras, but not scalable to hundreds/thousands.
- Decoder disposal in the pool is fire-and-forget, allowing short periods of overlapping old and new decoder resources.

Recommended architecture:

1. Shared application shell and design system.
2. Explicit repository interfaces with separate demo and real implementations.
3. Feature controllers/blocs for Live Grid, Playback, Export, and Diagnostics.
4. A single media-session coordinator managing decoder budget, quality, app lifecycle, cancellation, and telemetry.
5. Cached camera/site store shared by all screens.
6. Small view widgets using selectors so only affected regions rebuild.

## Gateway reliability and security findings

### High priority

- Gateway token is optional while binding to `0.0.0.0`.
- CORS allows every origin.
- MediaMTX RTSP, HLS, WebRTC, and API-related ports are exposed on the host without an app-level access policy.
- An unauthenticated LAN client can request an arbitrary RTSP target when no token is configured, creating SSRF/compute-abuse risk.
- There is no TTL/idle reaper. If the phone closes unexpectedly and DELETE is not delivered, FFmpeg can continue running and consume one of four slots.
- Failed/stopped stream records remain in the manager map for the process lifetime.
- FFmpeg stderr is discarded, making camera/auth/codec failures hard to diagnose.

Required fix before anything beyond a controlled interview LAN:

- Require a generated token by default.
- Restrict accepted RTSP targets to approved private subnets/hosts.
- Add session TTL, heartbeat/lease renewal, idle cleanup, and process reaping.
- Keep sanitized bounded logs and expose a diagnostic status endpoint.
- Do not expose MediaMTX control/publisher surfaces beyond what the app needs.
- Add per-IP rate limits and concurrent-probe limits.

## Android/iOS configuration findings

- Android enables cleartext traffic for the entire release application, not just the local gateway.
- Release currently signs with the debug key.
- Application ID and label are still generic (`com.vms.app`, `app`).
- iOS has camera permission text, but no local-network usage description/Bonjour declaration and no ATS exception strategy for HTTP LAN gateway access.
- Talkback UI exists without microphone permission or a real media path.
- Web/desktop folders exist, but `dart:io`, the IO Dio adapter, and platform-specific media plugins mean those platforms are not truly supported as currently structured.

Required fix:

- Restrict Android cleartext with a network-security config or a dedicated demo flavor.
- Add real release signing and product identifiers.
- Add correct iOS local-network/transport configuration before claiming iOS gateway support.
- Remove unsupported platform claims or provide platform adapters.

## Testing and observability gaps

Existing tests are useful for logic and widget smoke coverage, but the following are missing:

- No end-to-end test from RTSP input through gateway to rendered first frame.
- No physical-device performance baseline.
- No startup, frame-build/raster, memory, thermal, or decoder-count benchmark.
- No long-running reconnect/packet-loss/background-resume soak test.
- No golden/responsive/accessibility test suite.
- No gateway test for timeout mismatch, process crash, TTL cleanup, concurrent limit, auth, or malicious targets.
- No production monitoring/crash reporting; errors are mainly console logger output.

Verification note: the latest completed project baseline before this audit was analyzer-clean with 85/85 tests passing. During this audit, new Flutter analyzer/test commands became blocked by a local Flutter/Dart tool process hang; no source changes were made, and the stuck audit-spawned processes were terminated. A clean sequential rerun is required before optimization implementation begins.

## Recommended execution order

### Phase 0: Measure and protect the demo (half to one day)

- Create explicit `demo-local` build configuration.
- Run profile mode on the exact interview phone.
- Capture startup time, time-to-first-frame, UI/raster frame times, memory, CPU, and reconnect time.
- Hide every nonfunctional action from the interview build.

### Phase 1: Fix P0 configuration and reliability (one to two days)

- Unify `AppConfig`/`AppConstants` and fix TLS trust behavior.
- Remove unreachable-backend retry from demo mode.
- Normalize real RTSP URLs and mask credentials.
- Fix gateway/client timeout contract and `/export` route typo.
- Make preview status reflect actual player state.

### Phase 2: Optimize streaming lifecycle (two to four days)

- Introduce the global media-session budget.
- Use sub-streams for grids and main stream for focus.
- Isolate/throttle controller-driven rebuilds.
- Pause/resume media on lifecycle changes.
- Add gateway TTL cleanup, diagnostics, and adaptive transcoding.

### Phase 3: Simplify UX and architecture (three to five days)

- Build a common navigation shell.
- Split the large Live Grid, Playback, Export, and Login pages.
- Replace direct GetIt calls in UI with feature state/controllers.
- Consolidate theme tokens and reusable states/components.
- Remove duplicate/fake controls and reduce visual density.

### Phase 4: Production hardening (two to four days)

- Security configuration, release signing, and gateway authorization.
- Accessibility and responsive testing.
- Integration, performance, reconnect, and soak tests.
- Release/AAB size analysis and observability.

Estimated effort:

- Interview-demo stabilization: 1-2 focused developer days.
- Noticeably faster and cleaner app: 5-8 developer days.
- Full production-oriented optimization/hardening: roughly 10-15 developer days, excluding unfinished backend APIs.

## Acceptance targets

Targets must be measured in profile/release mode on the intended phone and LAN:

- Login form interactive in under 1 second after native splash.
- No artificial delay after successful demo authentication.
- Camera list cached content visible immediately; network refresh happens in background.
- Direct LAN RTSP first frame target: under 3 seconds when the camera responds normally.
- Gateway first frame target: under 6 seconds for a warm H.264 path and under 10 seconds for software H.265 transcoding, with visible stages.
- No more than one full-screen rebuild per second during playback; video position/status widgets may update independently.
- No sustained UI/raster frame overruns during 1x1 and 2x2 playback.
- Returning from 1x1 to grid does not reconnect every previously visible camera.
- Memory returns close to baseline after ten connect/disconnect cycles.
- Backgrounding the app releases or pauses media and polling according to policy.
- Every visible action either works end to end or is clearly disabled/unavailable.

## Final conclusion

The current app is not slow because of one bad widget. It feels slow because failed backend calls wait too long, animations gate useful work, video listeners rebuild too much UI, and stream sessions are repeatedly created/destroyed without a unified media budget. UX quality is reduced further by simulated actions and inconsistent navigation/design systems.

The correct first implementation step is not a cosmetic redesign. It is a demo/real-mode split plus networking and streaming lifecycle stabilization. After that, rebuild isolation and a shared app shell will deliver the largest visible performance and UX improvement without breaking the working CCTV gateway path.
