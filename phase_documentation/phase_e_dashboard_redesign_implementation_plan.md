# Phase E: Dashboard Redesign Implementation Plan (Feature 30)

## Proposed Changes
1. **Empty slots simplification:** Replace the text labels and icons with index indicators `1`-`9` in the top-left and a centered `+`.
2. **CCTV Control Bar:** Add play/pause, SD/HD chip toggle, speaker volume toggle, favorite star, grid size text badge, and fullscreen toggle.
3. **Tactical Action Bar:** Add Playback redirect button, microphone talkback, record start/save, camera snapshot, and PTZ centering trigger.
4. **Alarm Messages panel:** Collapsible sliding card that displays real-time alarms list with `AlarmBloc` WebSocket sync.

## Verification
- Run `flutter analyze` to guarantee zero compile issues.
- Run `flutter test` to ensure all widget/unit tests are completely passing.
