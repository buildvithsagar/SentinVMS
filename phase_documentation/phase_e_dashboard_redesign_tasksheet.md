# Phase E: Dashboard Redesign Tasksheet (Feature 30)

- `[x]` E.1.1: Implement empty slot indicators with centered `+` and subtle top-left number index (1-9).
- `[x]` E.1.2: Add CCTV Control Row 1 (Play/Pause, SD/HD chip toggle, speaker mute, favorite star, layout size, fullscreen trigger).
- `[x]` E.1.3: Add CCTV Action Row 2 (Prominent Playback redirect button, mic talkback, local record, snapshot, PTZ crosshair centering).
- `[x]` E.1.4: Provide `AlarmBloc` globally to `/live_grid` route inside `AppRouter` configuration.
- `[x]` E.1.5: Build sliding bottom drawer for "Alarm Message" containing collapsible chevron, calendar filter icon, and real-time WebSocket event list.
- `[x]` E.1.6: Rewrite widget tests inside `live_grid_page_test.dart` to mock `AlarmBloc` and set a larger virtual surface size to bypass layout virtualization.
- `[x]` E.1.7: Run `flutter analyze` and `flutter test` to ensure zero compilation and verification failures.
