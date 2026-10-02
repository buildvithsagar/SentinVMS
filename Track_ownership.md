# Saurabh — Phase 1 Ownership: C++ Cloud Media Core & Streaming Pipelines

**Role:** Co-Owner of Media Engine & Edge Appliances Group (Shubham + Saurabh)
**Primary Code Focus:** Track A — Cloud Native Media Core Services, Ingest Muxers, and Export Gateways
**Phase:** 1 Standard SaaS Revision
**Features Lead:** F01 (ONVIF Camera Discovery — Media Core side), F02 (Media Core Live Streaming Engine), F03 (PTZ Command Bridge — Media Core side), F04 (Continuous Recording segmenters), F06 (Secure Evidence Clip Export Assembly), F08 (Redis Streams Telemetry Publishing)

---

## Architectural Mandate

- **Group 2 Sovereign Repositories:** Saurabh and Shubham jointly own the native media infrastructure repository (`vms-media-engine/`). All Flutter Mobile code layers are completely out of scope for Saurabh; Sagar holds sovereign lead over the mobile repo.
- **Deployment Boundaries:** The Cloud Media Core services run EXCLUSIVELY inside centralized hosted Kubernetes clusters fitted with dedicated GPU acceleration node pools. Phase 1 Standard SaaS deployment targets validation of **1,000 concurrent streaming camera nodes sharded across 2 distinct mock corporate tenants**.
- **Data Isolation Pillar 1:** Every stream routing parameter, S3 object block, tracking registry index, and event notification string handled by the media stack must prepend the canonical multi-tenant sharding root-key: `{customer_id}:{site_id}:{camera_id}`. Un-namespaced bare lookups are strictly prohibited.
- **Asynchronous Decoupling (Non-Negotiable):** The C++ Media Core processes communicate with Vivek's central NestJS Control Plane strictly via partitioned Redis Streams or pub/sub channel hooks. Executing synchronous HTTP backend blocking requests from media pods is completely banned.

---

## Group 2 Target Work Distribution Split

To guarantee zero development collisions or git tree merge conflicts inside the shared native repository, Group 2 explicitly partitions its functional task tracks as follows:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       VMS NATIVE MEDIA CODE REPOSITORY                      │
├──────────────────────────────────────┬──────────────────────────────────────┤
│ Track A: Cloud Media Core Services   │ Track B: On-Premises Edge Agent      │
│ Primary Owner: SAURABH               │ Primary Owner: SHUBHAM               │
├──────────────────────────────────────┼──────────────────────────────────────┤
│ — GStreamer cloud ingest pipelines   │ — SOAP over UDP WS-Discovery loops   │
│ — Stream Router Redis maps engine    │ — Profile T/M IGMPv3 loopback proxy  │
│ — HLS / WebRTC Gateway engines       │ — Local x86_64 / arm64 cross-builds  │
│ — continuous fMP4 segmenting chunkers│ — Local SQLite ANR caching databases │
│ — Tamper-Evident MP4 clip exports    │ — Off-peak WAN sync throttling hooks │
└──────────────────────────────────────┴──────────────────────────────────────┘
```

---

## Sub-Phase 1.1 — Cloud Media Core Service Architecture (Primary: Saurabh)

### Task 1.1.1 — Cloud Pipeline Core & Monorepo Layout Setup
- Construct the primary streaming engine infrastructure inside `vms-media-engine/cloud-media-core/` using CMake 3.25+ and C++17 compilers.
- Ingest dependencies securely using the Conan package manager: GStreamer 1.22 plugins, `hiredis`, `spdlog`, and the AWS C++ SDK for object storage communication.
- **Unified Project Directory Layout (Shared Monorepo Base):**
```
vms-media-engine/                           -- Consolidated Native Media Repository Root
├── CMakeLists.txt                          -- Root CMake orchestrator (CMake 3.25+, C++17)
├── conanfile.txt                           -- Shared dependency matrix locks
│
├── cloud-media-core/                       -- Target 1: Cloud-Native Media Core Services
│   ├── CMakeLists.txt
│   └── src/
│       ├── main.cpp
│       ├── stream_router/                  -- {customer_id}:{site_id}:{camera_id} assignment loop
│       ├── ingestion/                      -- GStreamer pipeline configurations
│       ├── live/                           -- WebRTC Gateway & HLS Gateway
│       ├── recording/                      -- Continuous fMP4 segmenting chunkers
│       └── export/                         -- Secure MP4 Evidence assembly & Watermarking
│
└── edge-agent/                             -- Target 2: On-Premises Edge Agent Appliance
    ├── CMakeLists.txt
    ├── docker/
    │   └── Dockerfile.edge-agent           -- Debian 12 Minimal headless image (<200MB)
    └── src/
        ├── main.cpp
        ├── discovery/                      -- SOAP over UDP WS-Discovery loops
        ├── proxy/                          -- Profile T/M IGMPv3 loopback proxy
        └── telemetry/                      -- gRPC Health Telemetry publishing loops
```
- Build resilient GStreamer media processing graphs for **Profile S Unicast RTSP Ingestion**:

```
rtspsrc (RTSP Ingest) → rtpjitterbuffer (Jitter Sync) → rtph264depay → h264parse
→ nvh264dec (Hardware NVIDIA GPU Accelerated Decode) / avdec_h264 (CPU Fallback)
→ videoscale → videoconvert
├── [Branch 1] hlssink2 (RAM Disk Mobile Fallback: /hls/{customer_id}/{site_id}/{camera_id}/)
├── [Branch 2] webrtcbin (Low-Latency Web Operators canvas via coturn fleet relay)
└── [Branch 3] splitmuxsink (Continuous fMP4 fragment chunkers targeting MinIO)
```

### Task 1.1.2 — Stream Router Mechanism with Multi-Tenant Keying & N:1 Hot Standby Failover
- Code the specialized `StreamRouter` class to orchestrate load-balancing across recorder pods.
- Persistent assignment data is sharded inside the Redis Cluster using strict tenant composite keys: `cust-{customer_id}:site-{site_id}:stream:assignment:{camera_id}` mapping to target pod strings.
- **Resiliency Constraint:** Implement an automated 30-second camera reallocation map if an individual recorder pod crashes, distributing channels evenly without crossing tenant data domains. Enforce an explicit capacity ceiling: `static constexpr float HEADROOM_FACTOR = 0.90f` (10% permanent safety headroom buffer per pod).
- **N:1 Hot Standby Failover:** Implement failover logic in the router loops. If a primary recording server becomes offline, the router reallocates streams to standby servers, completing the transition within 1 minute with zero loss of live or recorded stream packets.

### Task 1.1.3 — Asynchronous Redis Streams Publisher Engine
- Build the core `StreamPublisher` library using non-blocking asynchronous `hiredis` patterns to dump telemetry metadata directly onto the micro event bus.
- **`vms:camera-status` Payload Contract:**
```cpp
// Fired instantly on camera connectivity fluctuations tracked by heartbeats
{
  "customer_id":  "tenant-uuid-v4-string", // Leading Tenant Key Index
  "siteId":       "location-uuid-v4-string",
  "cameraId":     "camera-uuid-v4-string",
  "status":       "ONLINE" | "OFFLINE" | "ERROR",
  "timestamp":    "ISO-8601-Strict-Format"
}
```

* **`vms:recording-lifecycle` Payload Contract:**
```cpp
// Emitted immediately on 15-minute fragment completion after secure MinIO push
{
  "customer_id":  "tenant-uuid-v4-string",
  "siteId":       "location-uuid-v4-string",
  "cameraId":     "camera-uuid-v4-string",
  "segmentId":    "generated-segment-uuid",
  "filePath":     "recordings/{customer_id}/{site_id}/{camera_id}/{date}/{ts}.fmp4",
  "fileSize":     "bytes-metric-string",
  "state":        "CLOSED" // Only CLOSED segments are picked up by Vivek's index consumers
}
```

### Task 1.1.4 — Instant Replay Rolling Live Buffer
- Develop a high-speed rolling in-memory ring-buffer cache within the Cloud Media Core pipelines.
- The buffer must store a sliding window of the last 60 seconds of incoming H.264 video/audio packets in volatile memory (RAM disk/shared memory) per active camera stream, enabling instant replay playback operations directly from client requests without hitches or object store query latency.

---

## Sub-Phase 1.2 — Fragmented Recording Core & Object Ingestion (Primary: Saurabh)

### Task 1.2.1 — Continuous Cloud Recording Engine & Sizing Constraints
* Standardize all video storage files strictly on **ISO BMFF fragmented MP4 (fMP4)** formats pushed straight to the `vms-hot` bucket pool. Unfragmented MP4 structures are banned.
* **Stream Sizing Constraints:** The default recording streams utilize **H.265 video compression at 4MP resolution and 25 FPS**. Each recording host server must be architected to handle up to **960 Mbps of video bandwidth** concurrently.
* Chunker modules capture incoming frames into precise 15-minute segments, embedding cryptographic runtime parameters derived via the global namespace paradigm: `/recordings/{customer_id}/{site_id}/{camera_id}/{YYYY-MM-DD}/{epoch_ms}.fmp4`.
* **Motion Ingestion Logic:** Ingest motion metadata webhooks asynchronously. When motion indicators shift to active, instantiate an additional sink branch inside the GStreamer tee. On motion cessation, maintain a strict 30-second quiet caching window before segment encapsulation to prevent frame truncation.

### Task 1.2.2 — Playback Scrubbing & Thumbnails Generation
* Develop the playback timeline scrubbing service supporting dynamic speed adjustments up to **16x fast-forward/rewind** speeds.
* Implement a background keyframe extraction pipeline to generate on-the-fly JPEG thumbnails from fMP4 fragments stored on MinIO, serving the scrub preview interfaces.

### Task 1.2.3 — SSD-to-S3 Storage Tiering
* Implement a mixed-drive storage tiering system. Incoming fMP4 segments are cached locally on the recorder node's high-speed NVMe SSD pool for the first 24-48 hours.
* Integrate a background flushing task that sequentially uploads closed segments to the centralized MinIO S3 standard hot storage bucket (30 days retention policy).

### Task 1.2.4 — Evidence Lock Gating
* Design the "Evidence Lock" database schema mapping and MinIO bucket lifecycle overrides.
* When an operator flags an incident clip, the corresponding fMP4 segments in the PostgreSQL index and object storage must bypass the standard 30-day deletion cycle and be securely archived for a minimum of 90 days.

---

## Sub-Phase 1.3 — Tamper-Evident Evidence Clip Export (Primary: Saurabh)

### Task 1.3.1 — Evidence Assembly & Hard Burned-In Watermarking
* Process clip assembly jobs triggered from control gRPC payloads carrying strict tenant sharding filters: `(customer_id, site_id, camera_id, startTime, endTime)`.
* Pull target fMP4 files matching the requested timestamp matrix from MinIO, stitching segments together via optimized GStreamer pipelines into an integrated MP4 file.
* **Anti-Tamper Overlay Filter:** Embed a native `cairooverlaysink` configuration to hard burn un-strippable text overlays directly onto every video frame. The watermarked metadata string must compile: VMS SaaS License Token, Target Camera Hardware String, Operation Export Timestamp, and the Named Operator Profile ID.
* Assembled evidence clips are written to the `vms-exports` storage bucket fitted with a 7-day TTL lifecycle policy. Issuing time-bounded signed URLs to client portals is strictly delegated to Vivek's central Control Plane services.

### Task 1.3.2 — Cryptographic Video Signing
* Apply a digital signature protocol during clip assembly. Generate a SHA-256 hash of the compiled MP4 clip and encrypt it with the VMS platform's RSA-2048 private key (retrieved dynamically from the Vault PKI engine).
* Embed this digital signature as a custom metadata tag inside the exported MP4 container to make it legally admissible and tamper-evident.


---

## Sub-Phase 1.4 — On-Premises Edge Agent Core (Primary Support: Saurabh)

While Shubham holds primary ownership over Track B (Edge Agent deployment binaries), Saurabh provides development support on the streaming proxy loops to ensure architectural consistency:

* **Profile T/M Local Multicast Proxy Integration:** Collate with Shubham to ensure the on-premises Debian Agent correctly joins local LAN switch multicast groups via kernel-level `IP_ADD_MEMBERSHIP` socket options. The proxy captures local frame blocks (decrypting SRTP via Vault keys), preventing double-streaming bottlenecks.
* **Advanced Network Replenishment (ANR):** Ensure the localized SQLite tracking engine cleanly logs offline data clips onto the on-premises partition (`/var/vms/anr/{customer_id}/{site_id}/{camera_id}/`) using the sharded schema tuple:
```sql
CREATE TABLE anr_index (
  customer_id TEXT NOT NULL,
  site_id     TEXT NOT NULL,
  camera_id   TEXT NOT NULL,
  local_path  TEXT NOT NULL,
  synced_flag BOOLEAN NOT NULL DEFAULT 0,
  PRIMARY KEY (customer_id, site_id, camera_id, local_path)
);
```

---

## Group 2 Integration Contracts & Interface Commit Gates

| Interface ID | Delivery System | Directionality | Payload / Schema Structural Requirements |
| --- | --- | --- | --- |
| `vms:camera-status` | Redis Stream Bus | Group 2 Cloud ➔ Group 1 Workers | `{customer_id, siteId, cameraId, status, fps, bitrateKbps, packetLoss, timestamp}` |
| `vms:recording-lifecycle` | Redis Stream Bus | Group 2 Cloud ➔ Group 1 Workers | `{customer_id, siteId, cameraId, segmentId, filePath, fileSize, state: 'CLOSED', timestamp}` |
| `media:cmd:{customer_id}:{site_id}` | Redis Pub/Sub | Group 1 Ingress ➔ Group 2 Core | `{action: 'START_RECORDING' | 'STOP_RECORDING' | 'ASSIGN_CAMERA', customer_id, site_id, camera_id, params}` |
| `POST /api/v5/cameras/discovered` | mTLS gRPC Tunnel | Group 2 Edge ➔ Group 1 Ingress | Encrypted JSON payload pushing newly discovered device profiles directly into PostgreSQL tables. |
