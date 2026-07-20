# Phase I Context - Single Camera Screen View, PTZ Control Scoping & Diverse Mock Streams

## Overview
Phase I enhances the Live Viewport Grid in SentinVMS mobile application by introducing intuitive camera focus transitions, scoping PTZ (Pan-Tilt-Zoom) controls strictly to single camera view, and diversifying mock video streams with real public, street, building, interior, and datacenter footage.

## Key Changes
1. **Single Camera Focus Transition**:
   - In multi-camera viewport grid layouts (2x2 grid / 4 cameras, 3x3 grid / 9 cameras), clicking/tapping on any assigned camera tile expands that camera stream into 1x1 Single View focus mode.
   - Empty slots continue to trigger the camera picker sheet.

2. **PTZ Control Scoping**:
   - PTZ controls are scoped exclusively to the 1x1 Single View screen layout (`_layoutGridSize == 1`).
   - PTZ overlays and D-pad directional controls are hidden in 4-camera and 9-camera layouts to prevent visual clutter and accidental touches.
   - The toolbar PTZ button dynamically switches layout to 1x1 focus mode when engaged.

3. **Diverse Mock Stream Data**:
   - `CameraRepository` provides unique, distinct public, building, traffic, and facility video streams for all 9 camera channels (`cam-001` to `cam-009`).

## Key Files Affected
- `mobile/lib/features/camera/data/camera_repository.dart`
- `mobile/lib/features/live_view/widgets/video_tile.dart`
- `mobile/lib/features/live_view/live_grid_page.dart`
- `mobile/test/widget/live_grid_page_test.dart`
