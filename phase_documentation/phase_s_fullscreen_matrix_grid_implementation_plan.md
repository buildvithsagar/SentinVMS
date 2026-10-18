# Phase S — Implementation Plan: Fullscreen Responsive Matrix Grid & Viewport Auto-Fitting

## 1. Objectives
- Implement dynamic viewport matrix calculation for 1x1, 2x2, 3x3, and 4x4 grids.
- Ensure mathematically exact cell aspect ratio allocation in both normal viewport and fullscreen.
- Integrate `SafeArea` in fullscreen Scaffold to eliminate hardware notch/punch-hole collision.
- Enable smooth orientation handling.

## 2. Technical Modifications
1. [`LiveGridPage`](file:///c:/Users/SAGAR/vmsapp/SentinVMS/mobile/lib/features/live_view/presentation/pages/live_grid_page.dart):
   - Replace `_build2x2Grid`, `_build3x3Grid`, `_build4x4Grid` with unified `_buildMatrixGrid(int gridSize)`.
   - Wrap fullscreen Scaffold body in `SafeArea`.
   - Update `_toggleFullScreen()` orientation list to include all device orientations.

## 3. Verification
- `flutter analyze`: Zero static analysis issues.
- `flutter test`: 100% test suite pass rate (69/69 tests).
