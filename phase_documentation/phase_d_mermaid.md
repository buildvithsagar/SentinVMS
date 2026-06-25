# Phase D: Mermaid Diagrams (Timeline Playback, Alarms & Exports)

This document contains the raw Mermaid diagram source code for **Micro-Phase D: Timeline Playback, Alarms & Exports (Operations)**.

---

## 1. Sequence Diagram: Real-Time WebSocket Alarm Ingestion Flow

```mermaid
sequenceDiagram
    autonumber
    participant WSS as WebSocketService
    participant Main as Main Entry (Listener)
    participant Bloc as AlarmBloc Singleton
    participant UI as AlarmListPage UI

    Note over WSS: Connection is ACTIVE
    WSS->>Main: Pushes event: {'event': 'alarm', 'data': {...}}
    Main->>Bloc: add(AlarmReceived(alarmData: data))
    
    Note over Bloc: Current state = AlarmLoaded
    Bloc->>Bloc: Prepend new alarm to list
    Bloc->>UI: Emit AlarmLoaded(updatedList)
    UI->>UI: Animated rebuild of list item card
```

---

## 2. Block Diagram: Operations Flow

```mermaid
graph TD
    subgraph UI [Operations UI Viewports]
        Playback[PlaybackPage Viewport]
        Scrubber[TimelineScrubber Painter]
        Speed[PlaybackSpeedControl]
        Alarms[AlarmListPage Cards]
        ExportWiz[ExportPage Wizard Form]
    end

    subgraph Data [Data & Core State]
        PRepo[PlaybackRepository]
        ARepo[AlarmRepository]
        ERepo[ExportRepository]
        ABloc[AlarmBloc Singleton]
    end

    Playback --> Scrubber
    Playback --> Speed
    Alarms --> ABloc
    
    Scrubber -->|Fetches segments| PRepo
    ABloc -->|Fetches/Acks| ARepo
    ExportWiz -->|Creates jobs| ERepo
```
