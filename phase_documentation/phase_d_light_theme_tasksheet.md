# Tasksheet — Premium Modern Light-Theme Redesign & Real Integration (Phase D.6)

This tasksheet lists all the completed deliverables in the light theme overhaul and real repository binding integration.

---

## 1. Global Color Theme & Typography
- `[x]` Set MaterialApp theme parameters to modern light theme values
- `[x]` Configured scaffold background to soft blue-grey (`#F4F7FC`)
- `[x]` Set default card colors to solid white (`#FFFFFF`)
- `[x]` Configured primary button backgrounds to brand blue (`#2563EB`)
- `[x]` Styled text colors to charcoal (`#1E293B`) and label colors to slate grey (`#64748B`)

## 2. Page & Widget Redesigns
- `[x]` Replaced the login page sweeping radar with a clean linear gradient and updated input styles
- `[x]` Corrected contrast issue on login text fields to use charcoal text on white cards
- `[x]` Removed HUD bracket overlays from `VideoTile` and replaced telemetry with a clean translucent badge
- `[x]` Styled slot placeholder borders with dashed light-grey outlines
- `[x]` Redesigned PTZ arrows and zoom buttons into a modern stacked circular controller
- `[x]` Set `TimelineScrubber` background track to light grey and segments to soft pastel colors

## 3. Real Repository Binding
- `[x]` Refactored `PlaybackPage` to fetch real cameras, load real segments, and stream HLS video
- `[x]` Refactored `ExportPage` to list real cameras, submit real exports, and poll active job progress
- `[x]` Cleaned up all widget lints, unawaited futures, and double literal warnings
- `[x]` Ran `flutter analyze` with 0 issues found and verified all 53 unit/widget tests pass successfully
