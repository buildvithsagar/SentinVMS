# Implementation Plan — Micro-Phase C: Live Grid & Decoder Semaphore (Video Rendering)

This plan outlines the technical design and implementation steps for **Micro-Phase C** of the Enterprise VMS Flutter Client. This phase introduces hardware decoder limiting via a custom semaphore pool, HLS video tile rendering, and grid layouts.

---

## User Review Required

> [!IMPORTANT]
> **Decoder Pool Size & Auto-Eviction:**
> To prevent platform hardware decoder starvation (which causes app crashes on Android/iOS), the client enforces a maximum limit of **4 active players** using a `DecoderPool` manager.
> If a 5th video player attempts to play, the oldest active player will be **evicted** (automatically paused and disposed), and its tile UI will transition to an "Evicted" overlay (allowing the user to manually click to resume/re-claim a lease).

> [!NOTE]
> **Repaint Boundary Isolation:**
> Live video frames render at 25–60 FPS. To prevent these paint updates from forcing repaint cycles across the entire mobile UI tree (which ruins scroll performance and wastes CPU), each `VideoTile` widget is wrapped inside a strict `RepaintBoundary`.

---

## Open Questions
No open blocking questions. We will use the REST endpoint `GET /api/v5/recordings/stream?siteId={siteId}&cameraId={cameraId}` to fetch signed HLS `.m3u8` URLs as defined in the specifications.

---

## Proposed Changes

### Core Video Infrastructure

#### [NEW] [decoder_pool.dart](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/lib/core/video/decoder_pool.dart)
*   Create a singleton `DecoderPool` that tracks active streaming leases.
*   Enforce a maximum capacity limit: `static const int maxDecoders = 4`.
*   Maintain a FIFO queue of active leases: `final List<DecoderLease> _leases = [];`.
*   Expose `Future<DecoderLease> acquire({required String cameraId, required VideoPlayerController controller, required VoidCallback onEvicted})`:
    *   If `_leases.length >= maxDecoders`, take the oldest lease (index 0), call its `evict()` callback, dispose its controller, and remove it from the pool.
    *   Create a new `DecoderLease`, add it to `_leases`, and return it.
*   Expose `void release(DecoderLease lease)`:
    *   Locate the lease in the queue, dispose its controller, and remove it.

---

### Camera Repository Expansion

#### [MODIFY] [camera_repository.dart](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/lib/features/camera/data/camera_repository.dart)
*   Add `Future<String> getLiveStreamUrl({required String siteId, required String cameraId})`:
    *   Calls `GET /api/v5/recordings/stream` passing query parameters `siteId` and `cameraId`.
    *   Parses and returns the signed `hlsUrl` from the response body.

---

### Video Rendering & Presentation Layer

#### [NEW] [video_tile.dart](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/lib/features/live_view/widgets/video_tile.dart)
*   Create `VideoTile` representing a single HLS player tile.
*   States to display:
    *   **Loading:** Skeleton loader or centered spinner while fetching stream URL and initializing.
    *   **Playing:** Renders the HLS stream using `VideoPlayer`.
    *   **Offline/Error:** Error overlay detailing why it failed to load.
    *   **Evicted:** Custom overlay stating: *"Playback paused to save hardware resources. Tap to play."*
*   **Performance:** Wrap the entire player tree in a `RepaintBoundary` to prevent paint propagation to parent pages.
*   **PTZ Controls Stub Overlay:** If `camera.ptzCapable == true`, display overlay buttons (up, down, left, right arrows, and zoom in/out icons) in a subtle translucent layout. Clicking them will show a toast/log statement (since they are non-functional UI stubs in Phase 1).

#### [NEW] [live_grid_page.dart](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/lib/features/live_view/live_grid_page.dart)
*   Renders a grid viewport supporting **1x1** (single camera focus) and **2x2** (4 concurrent feeds) grid layouts.
*   Allow operators to select/replace camera channels in each grid slot from a pop-up camera directory picker.
*   Styled in the low-contrast Matte Dark Industrial theme.

#### [MODIFY] [router.dart](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/lib/app/router.dart)
*   Wire the `/live_grid` route to return the `LiveGridPage` layout.
*   Provide GoRouter navigation transitions between `CameraListPage` and `LiveGridPage` (e.g. bottom navigation bar or drawer).

---

## Verification Plan

### Automated Tests
We will add unit and widget tests:

*   **DecoderPool Lease Allocation Tests:**
    *   Assert that acquiring 4 leases succeeds.
    *   Assert that acquiring a 5th lease triggers auto-eviction of the oldest lease, calling its `onEvicted` callback.
    *   Assert that releasing a lease decreases the active count and frees up slots.
*   **VideoTile State Transitions:**
    *   Verify that `VideoTile` displays skeleton loaders during initialization, switches to `VideoPlayer` when ready, and shows the "Evicted" overlay when evicted.
*   **Grid Layout Rendering Tests:**
    *   Assert that switching between 1x1 and 2x2 grid configurations changes the widget tree layout structure correctly.

### Manual Verification
*   **Decoder Eviction Performance Test:** Run a debug layout, load a 2x2 grid (4 streams playing), and try to open a 5th camera stream to verify that the oldest stream is immediately paused/released without app lag or media player crash.
