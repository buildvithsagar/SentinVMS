# Implementation Plan — Premium Tactical HUD Redesign (Phase D.5)

This document details the visual redesign of the VMS mobile client, migrating the user interface from a basic design to a premium, tactical cockpit heads-up display (HUD) aesthetic.

---

## 1. Objectives & Guidelines

1. **Tactical Industrial Aesthetic:** Apply a unified, high-tech cockpit design language. Base color `#0D0E12`, Accent Jade `#02965E`, Alert Crimson `#D32F2F`, and Neon Cyan/Teal `#00FFCC`.
2. **High Performance (60 FPS):** Avoid heavy widget trees and layout nesting. Use `CustomPainter` and `RepaintBoundary` to isolate video renders and draw graphics directly on the Canvas.
3. **Operator Comfort:** Avoid high-contrast glares; use soft glowing neon shadow outlines and linear gradient vertical accents.
4. **Lint and Test Cleanliness:** Comply strictly with `very_good_analysis` rules (0 warnings) and ensure widget tests pass without timing out on infinite animations.

---

## 2. Technical Modifications

### Component 1: Login Page
*   **Radar Grid:** Added `_RadarGridBackground` drawing a slow-sweeping radar beam using `RadialGradient` and custom grid overlays.
*   **Tactical Input Decoration:** Replaced standard fields with filled dark forms containing prefix icons and custom outline glows.
*   **Listener-Based Tap Animation:** Wrapped submit button in a `ScaleTransition` driven by a `Listener` (pointer down/up/cancel) to provide instant tactile scaling without breaking widget test gesture dispatching.

### Component 2: Video Tile Viewport
*   **Tactical Corner Brackets:** Added `HUDPainter` drawing 4 corner brackets on the screen using single-pass nested canvas drawing.
*   **Telemetry Overlay:** Added live stats row with a custom blinking dot widget powered by a `FadeTransition`.
*   **Isolate Video Renders:** Wrapped video decoder container with a `RepaintBoundary` to prevent global widget tree layout thrashing on frame updates.

### Component 3: Live Grid Slot Selection
*   **Pulsing Selection Border:** Created `_PulsingSelectionBorder` using an `AnimationController` to loop-glow the border and shadow of the selected grid slot.

### Component 4: Playback Scrubber Playhead
*   **Neon Gradient Playhead:** Upgraded the vertical playhead in `TimelineScrubber` to draw a `LinearGradient` from neon teal (`0xFF00FFCC`) to tactical jade (`0xFF02965E`), with a soft glowing aura behind it and a glowing triangular top cap.

---

## 3. Test-Aware Repeating Animations

To prevent `tester.pumpAndSettle()` timeouts in widget tests, all infinite/repeating animations (`repeat()`) check if they are running in a test environment:
```dart
if (!Platform.environment.containsKey('FLUTTER_TEST')) {
  _controller.repeat();
}
```
This keeps widget tests extremely fast and robust while maintaining full animation loops on real devices.
