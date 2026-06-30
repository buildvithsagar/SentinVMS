# Phase E: Dashboard Redesign Context (Feature 30)

## Overview
This phase introduces a redesigned, high-utility surveillance dashboard UI (Feature 30) matching references from premium CCTV systems. It features streamlined grid slot index tagging, a dedicated grid controller, tactical actions (Mic, Record, Snapshot, PTZ), a GoRouter navigation link to timeline playback, and a WebSocket-driven collapsible Alarm Messages stream.

## Files Involved
- [live_grid_page.dart](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/lib/features/live_view/live_grid_page.dart): Core presentation file updated with simplified slot indices, control toolbars, and the Alarm Panel.
- [router.dart](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/lib/app/router.dart): Enhanced `/live_grid` route definition to supply both `CameraBloc` and `AlarmBloc` concurrently.
- [live_grid_page_test.dart](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/test/widget/live_grid_page_test.dart): Restructured test assertions to verify slot badges and select button tags, bypassing layout virtualization constraints with expanded surface dimensions.

## Active State Flows
1. **Empty Slots:** Render a subtle badge (e.g. `'1'` to `'9'`) and a centered plus sign.
2. **CCTV Control Bar:** Toggles sound, favorites, HD/SD stream profiles, and registers the active grid size badge (`[1]`, `[4]`, `[9]`).
3. **Actions Row:** Redirects to playback timeline, triggers snackbars for local video record, snapshots, and PTZ centering.
4. **Alarm Panel:** Expands to present the live alarm events list backed by `AlarmBloc` updates.
