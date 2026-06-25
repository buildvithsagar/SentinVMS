# Context & Operations Boundaries — Micro-Phase D: Timeline Playback, Alarms & Exports

This document defines the architectural context, operations boundaries, and real-time synchronization invariants for **Micro-Phase D: Timeline Playback, Alarms & Exports (Operations)**.

---

## 1. Timeline Scrubber & Playback Context

Micro-Phase D implements operational controls for timeline playback of recorded footage, real-time AI alarms, and video export management.

```mermaid
graph TD
    subgraph Client [Mobile Client Environment]
        Scrubber[TimelineScrubber Widget]
        Speed[PlaybackSpeedControl Widget]
        Alarms[AlarmListPage Viewport]
        Exports[ExportPage Wizard]
        ABloc[AlarmBloc Singleton]
    end

    subgraph Server [Central SaaS Gateway]
        Gateway[vms-api-gateway REST]
        VivekWSS[Vivek WebSocket Broadcaster]
    end

    Scrubber -->|1. Request segments| Gateway
    Gateway -->|Returns segments JSON| Scrubber
    Scrubber -->|2. Renders segments| Paint[CustomPainter Track]
    
    ABloc <-->|3. Foreground Stream| VivekWSS
    ABloc -->|4. Dispatch Ack| Gateway
    Alarms -->|5. Render list| ABloc
    
    Exports -->|6. Trigger export job| Gateway
    
    classDef clientStyle fill:#0D0E12,stroke:#02965E,stroke-width:2px,color:#E2E8F0;
    classDef serverStyle fill:#14161F,stroke:#70788C,stroke-width:1px,color:#E2E8F0;
    
    class Scrubber,Speed,Alarms,Exports,ABloc clientStyle;
    class Gateway,VivekWSS serverStyle;
```

---

## 2. Color-Coded Timeline Representation (F05)

Recording segments on the timeline are represented visually based on their type classification:
*   **Continuous:** `#1565C0` (Blue)
*   **Motion:** `#E65100` (Orange)
*   **Scheduled:** `#02965E` (Green)

The timeline track calculates horizontal coordinates by projecting segments from $t_{\text{start}}$ to $t_{\text{end}}$ onto the 24-hour horizontal space using time-to-offset mapping:
$$X = \text{Padding} + \frac{t - t_{\text{day\_start}}}{86400} \times \text{TrackWidth}$$

---

## 3. Real-time Alarm Ingestion (F08)

The client subscribes to foreground WebSocket events from Vivek's broadcaster. When the app is in the background, FCM messages deliver notification payloads. The `AlarmBloc` reconciles state on resume by fetching the alarm log (`GET /api/v5/alarms`), preventing telemetry loss.
