# Micro-Phase D: Timeline Playback, Alarms & Exports

Micro-Phase D implements operational components including timeline playback controls, real-time AI alarms, and export job management.

## 1. High-Performance Timeline Custom Painting

Instead of rendering standard widgets for timeline blocks (which would saturate the layout tree and cause frame drops during horizontal scrubbing), the `TimelineScrubber` uses a `CustomPainter` (`_TimelinePainter`) to draw:
- The track background.
- Hours and vertical ticks dynamically spaced based on screen width.
- Color-coded recording blocks (Continuous, Motion, Scheduled) with a minimum 1px width clamp.
- The playhead handle and vertical playhead indicator.

The scrubber is wrapped in a `RepaintBoundary` to isolate the paint passes of the timeline track from the parent view hierarchy.

## 2. Dynamic Speed Controls

The `PlaybackSpeedControl` widget provides multipliers ($0.5\times$ to $16\times$) using a custom row of chips to control playback speed. Selected items use the accent green style, while unselected items use dark secondary surfaces.

## 3. Real-Time Alarm Ingestion & Acknowledgement

- **Telemetry Ingestion:** `AlarmBloc` registers a listener on the `WebSocketService` event stream. Incoming alarms are pushed via `AlarmReceived` and prepended immediately to the active alarm state.
- **Repository Integration:** All requests (fetching alarms and acknowledging specific alarm IDs) route through `AlarmRepository` via Dio, returning updated state values.

## 4. Evidence Export Wizard

The `ExportPage` UI implements the wizard workflow:
- **Initiator:** Allows selecting target cameras, and start/end dates and times.
- **Job Status Poller:** Provides list cards for pending, processing, completed, and failed jobs.
- **Platform Share Sheet Integration:** Completed jobs include download triggers with download progress bars.
