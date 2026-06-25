# VMS Flutter Client — Micro-Phase C Tasksheet Checklist

## ── Micro-Phase C: Live Grid & Decoder Semaphore (Video Rendering) ──
- `[x]` C.1: Implement `DecoderPool` semaphore service (cap of 4 concurrent streams)
- `[x]` C.2: Implement FIFO/LRU auto-eviction logic in `DecoderPool`
- `[x]` C.3: Build `VideoTile` widget using native `Texture` rendering and `RepaintBoundary`
- `[x]` C.4: Build Live Grid Viewport supporting 1x1 and 2x2 grid views
- `[x]` C.5: Integrate non-functional PTZ overlay stub controls (arrows & zoom UI)
- `[x]` C.6: Write unit tests for DecoderPool lease limits and auto-eviction behaviors
