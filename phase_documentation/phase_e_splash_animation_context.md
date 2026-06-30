# Phase E: Premium Splash Animation Context

## Overview
The user requested:
1. Cleaning up all temporary/rejected logo assets from the Desktop (`vms_logo_2.png`, `vms_logo_3.png`).
2. Finalizing the app branding by importing the user-uploaded transparent 3D glassmorphic VMS hexagon shield logo.
3. Applying this transparent logo directly to the Android/iOS native App Launcher Icon, native Splash Screen, and Login Page header animation.

## Design Decisions
1. **Transparent 3D Shield Logo:**
   - Imported the high-res transparent logo (no background padding or border boxes) as `assets/logo.png`.
2. **Native App Icon & Splash Screen:**
   - Compiled native launcher icons and splash screens.
   - The transparent hexagon logo now scales perfectly inside the device launcher frames (Phone, Messages, Play Store style) and sits seamlessly in the center of the dark-green native splash screen background.
3. **Test Support:**
   - Verified that the layout adapts correctly and all automated unit/widget tests pass cleanly.
4. **Transition Jank Resolution (Login Entrance):**
   - Replaced the conditional `SizedBox.shrink()` swapping on `_formOpacity` value with a stable `IgnorePointer` widget. This ensures the Form's layout dimensions are calculated from frame 0, completely resolving the layout shift/glitch on transition.
