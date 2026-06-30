# Phase E: Premium Dark Glassmorphism & 3x3 Grid Implementation Plan

## Proposed Changes
1. **Dependency Injection (`lib/main.dart`):**
   - Configured `DecoderPool` singleton initialization to instantiate with `maxDecoders: 9`.
2. **Dashboard Layout (`lib/features/live_view/live_grid_page.dart`):**
   - Increased camera directory storage array size to 9.
   - Replaced layout boolean with `_layoutGridSize` integer.
   - Built a 3x3 grid slot matrix helper rendering up to 9 slots.
   - Integrated a new 3x3 toggle button to switch layouts.
3. **Tests (`test/widget/live_grid_page_test.dart`):**
   - Added widget test case asserting correct rendering of 9 slots upon tapping the 3x3 View toggle.

## Verification Plan
1. **Static Analysis:**
   - Execute `flutter analyze` inside the `mobile` workspace (must output "No issues found!").
2. **Automated Testing:**
   - Execute `flutter test` to ensure all 54 widget and unit tests pass successfully.
