# Phase C: Mermaid Diagrams (Live Grid & Decoder Semaphore)

This document contains the raw Mermaid diagram source code for **Micro-Phase C: Live Grid & Decoder Semaphore (Video Rendering)**.

---

## 1. Sequence Diagram: Decoder Lease Allocation & FIFO Eviction Flow

```mermaid
sequenceDiagram
    autonumber
    participant UI as LiveGridPage / VideoTile
    participant Pool as DecoderPool
    participant LeaseOld as Oldest DecoderLease
    participant UI_Old as Evicted VideoTile UI

    UI->>Pool: acquire(cameraId: "cam_5", controller)
    Note over Pool: Current active leases = 4 (Max Cap)
    
    Pool->>Pool: Identify oldest lease (index 0)
    Pool->>Pool: Remove oldest lease from queue
    Pool->>LeaseOld: evict()
    LeaseOld->>UI_Old: onEvicted callback triggered
    UI_Old->>UI_Old: Set isEvicted = true & redraw UI (Paused Overlay)
    LeaseOld->>LeaseOld: Dispose controller
    
    Pool->>Pool: Create new DecoderLease for cam_5
    Pool->>Pool: Append to active leases queue
    Pool-->>UI: Return new lease
    UI->>UI: Start playback (controller.play())
```

---

## 2. Block Diagram: Rendering Architecture

```mermaid
graph TD
    subgraph Grid [Live Grid Page Viewport]
        Layout[1x1 Focus or 2x2 Grid Layout]
        Slots[4 Grid Slots]
        Control[Slot Control Panel]
    end

    subgraph Tile [Video Tile Widget]
        Repaint[RepaintBoundary Isolation Layer]
        Player[VideoPlayer widget]
        EvictUI[Playback Paused Overlay]
        ErrorUI[Stream Error Overlay]
        PTZ[PTZ Control Overlay stubs]
    end

    subgraph Core [Video Core Services]
        Repo[CameraRepository getLiveStreamUrl]
        DPool[DecoderPool Singleton]
    end

    Layout --> Slots
    Slots -->|Empty Slot| Dash[DashedBorder Card]
    Slots -->|Occupied Slot| Tile
    
    Tile -->|Calls| Repo
    Tile -->|Acquires Lease| DPool
    
    Repaint --> Player
    Repaint --> EvictUI
    Repaint --> ErrorUI
    Repaint --> PTZ
    
    classDef pageStyle fill:#0D0E12,stroke:#02965E,stroke-width:2px,color:#E2E8F0;
    classDef widgetStyle fill:#14161F,stroke:#70788C,stroke-width:1px,color:#E2E8F0;
    classDef serviceStyle fill:#14161F,stroke:#E65100,stroke-width:1.5px,color:#E2E8F0;
    
    class Grid,Layout,Slots,Control pageStyle;
    class Tile,Repaint,Player,EvictUI,ErrorUI,PTZ,Dash widgetStyle;
    class Repo,DPool serviceStyle;
```
