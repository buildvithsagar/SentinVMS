# Context & Video Rendering Boundaries — Micro-Phase C: Live Grid & Decoder Semaphore

This document defines the architectural context, rendering boundaries, and hardware decoder semaphore invariants for **Micro-Phase C: Live Grid & Decoder Semaphore (Video Rendering)**.

---

## 1. Video Rendering & Semaphore Context

Micro-Phase C establishes the video rendering pipeline on the mobile client. Live streams are rendered using HLS (via `VideoPlayerController`). To prevent system resource exhaustion (starvation of hardware H.264/H.265 decoders, causing crashes), we gate active streams through a thread-safe `DecoderPool` semaphore capped at 4.

```mermaid
graph TD
    subgraph Client [Mobile Client Environment]
        Grid[LiveGridPage Viewport]
        Pool[DecoderPool Singleton]
        Tile[VideoTile Widget]
        Player[VideoPlayer Controller]
    end

    subgraph Server [Central SaaS Gateway]
        Gateway[vms-api-gateway REST]
        Stream[HLS Stream Server]
    end

    Tile -->|1. Fetch URL| Gateway
    Gateway -->|Returns signed HLS URL| Tile
    Tile -->|2. Instantiate| Player
    Tile -->|3. Request lease| Pool
    
    Pool -->|4. If count >= 4, evict oldest| Lease[Oldest Lease]
    Lease -->|Evict callback| TileOld[Old VideoTile Widget]
    TileOld -->|Render pause overlay / dispose controller| PlayerOld[Old Player]
    
    Pool -->|5. Grant new lease| Tile
    Tile -->|6. Play stream| Player
    Player <-->|Renders HLS stream| Stream
    
    classDef clientStyle fill:#0D0E12,stroke:#02965E,stroke-width:2px,color:#E2E8F0;
    classDef serverStyle fill:#14161F,stroke:#70788C,stroke-width:1px,color:#E2E8F0;
    
    class Grid,Pool,Tile,Player clientStyle;
    class Gateway,Stream serverStyle;
```

---

## 2. Hardware Decoder Semaphore Gating (F09)

*   **Decoder Capacity Limit:** The pool is strictly capped at $N = 4$ concurrent active decoders:
    $$\text{Active Leases} \le 4$$
*   **FIFO Lease Eviction:** When a 5th video player attempts to initialize playback, the pool automatically retrieves the oldest lease in the queue, calls `evict()` (which updates the UI to an "Evicted/Paused" state), disposes its controller, and inserts the new lease at the end of the queue.

---

## 3. Repaint Boundary Isolation

Live HLS feeds trigger frame updates at a high rate (e.g., 30 FPS). Without isolation, these updates would trigger repaint passes on parent views (like layout grid, navigation bars, and tabs), causing frame rate drops (layout thrashing) and high CPU load. To prevent this, each `VideoTile` widget wraps its video viewport directly inside a `RepaintBoundary` to construct an isolated display list repaint layer.
