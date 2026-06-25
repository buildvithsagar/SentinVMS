# Shubham — Phase 1 Ownership: C++ Edge Agent Appliance & Monorepo Build Base

**Role:** Co-Owner of Media Engine & Edge Appliances Group (Shubham + Saurabh)
**Primary Code Focus:** Track B — On-Premises Edge Agent Appliance Operating Loops & Monorepo Base Setup
**Phase:** 1 Standard SaaS Revision
**Features Lead:** F01 (ONVIF Device Auto-Discovery — Edge), F03 (PTZ Command Execution Bridge — Edge side), F04 (Local ANR Caching), F08 (gRPC Real-Time Health Telemetry Streaming)

> **Boundary Clarity per project.md Section 8 (F03):**
> - Shubham owns: **Edge PTZ execution** — receives PTZ commands via Redis pub/sub and issues ONVIF PTZ calls to physical cameras.
> - Saurabh owns: **Media Core PTZ routing** — relays PTZ commands from control plane to Edge via Redis channels.
> - Vivek owns: **Web portal PTZ UI** — directional/zoom buttons, DOM visibility logic (hidden for non-PTZ cameras).

---

## Architectural Mandate

- **Group 2 Sovereign Boundaries:** Shubham and Saurabh jointly own the native media infrastructure repository (`vms-media-engine/`). Shubham holds primary execution lead over the on-premises Edge Agent application code targets.
- **Deployment Boundaries:** The Edge Agent application runs EXCLUSIVELY on-premises within specialized appliance hardware (Hardened minimal Debian 12 env). Running cloud-native media servers, dynamic HLS gateways, or stream routers is completely out of scope for Shubham; those belong strictly to Saurabh's Track A.
- **Stream Overhead Elimination:** Cameras emit exactly ONE physical stream onto the local LAN. For Profile T/M devices, the Edge Agent joins the local network switch multicast group via kernel socket protocols as a standard loopback proxy subscriber, capturing and chunking archive fragments without double-streaming.
- **Bandwidth & Line Throttling (Pillar 5):** Edge ingestion uploads and ANR data replenishment sync tasks must strictly honor the network line capacity constraints. High-Band streaming is cloud-direct; off-peak background delta replication is strictly capped at an 80 Mbps maximum ceiling.

---

## Group 2 Functional Task Track Partitioning

To guarantee zero development collisions or git tree merge conflicts inside the shared native repository, Group 2 explicitly isolates its functional paths as follows:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       VMS NATIVE MEDIA CODE REPOSITORY                      │
├────────────────────────────────┬──────────────────────────────────────┤
│ Track A: Cloud Media Core Services   │ Track B: On-Premises Edge Agent      │
│ Primary Owner: SAURABH (Out of Scope)│ Primary Owner: SHUBHAM               │
├────────────────────────────────┼──────────────────────────────────────┤
│ — GStreamer cloud ingest pipelines   │ — SOAP over UDP WS-Discovery loops   │
│ — Stream Router Redis maps engine    │ — Profile T/M IGMPv3 loopback proxy  │
│ — HLS / WebRTC Gateway engines       │ — Local x86_64 / arm64 cross-builds  │
│ — continuous fMP4 segmenting chunkers│ — Local SQLite ANR caching databases │
│ — Tamper-Evident MP4 clip exports    │ — Off-peak WAN sync throttling hooks │
└──────────────────────────────────────┴──────────────────────────────────────┘
```

---

## Sub-Phase 1.1 — Native Media Workspace Foundation & Edge Agent Architecture

### Task 1.1.1 — Monorepo Base Build Orchestrator & Project Layout
- Setup the unified repository workspace root layout inside `vms-media-engine/`, deploying the top-level master orchestrator build files: `CMakeLists.txt` (CMake 3.25+, C++17) and `conanfile.txt` to lock down global dependency matrices.
- Scaffolds the independent application compilation targets directories:
  - `cloud-media-core/` ➔ Mapped exclusively to Saurabh's Track A execution sprints.
  - `edge-agent/` ➔ Mapped sovereignly to Shubham's Track B engineering sprint tasks.
- Connect Google Test (GTest) infrastructure setups, separating cloud cluster unit testing blocks from localized appliance edge testing environments.
- **Unified Project Directory Layout:**
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

### Task 1.1.2 — Hardened Edge Agent Appliance Target Setup & Hardware Profile
- Configure the deployment container environments and cross-compilation pipeline manifests inside `edge-agent/docker/Dockerfile.edge-agent`.
- Targets a minimalist, headless, cross-compiled Debian 12 base layout configuration (< 200 MB memory footprint) supporting both `x86_64` (Intel NUC architectures) and `aarch64` (NVIDIA Jetson edge nodes hardware profiles).
- **Edge Gateway Hardware Specifications:** The underlying edge gateway appliance has the following hardware profile: Intel SOC based chipset, minimum 4 GB RAM, minimum 32 GB SSD storage, 2x HDMI ports, 2x 1G LAN ports, 2x USB ports, 1x PCI Expansion slot. The mounting profiles must support Wall, VESA, or DIN Rail options.
- Integrates binary RSA cryptographic signature verification routines within the agent initialization hook; unsigned or modified binaries are rejected immediately at boot time to preserve data integrity.

---

## Sub-Phase 1.2 — Network Ingestion Protocols & Discovery (Primary: Shubham)

### Task 1.2.1 — ONVIF Camera Auto-Discovery Engine & PTZ Controls
- Implement the core `ONVIFDiscovery` engine class leveraging `gSoap` integration components to scan local subnets dynamically.
- **WS-Discovery Execution Loop:** Spawns background network probes emitting SOAP over UDP multicast signals targeting the standard address boundary: `239.255.255.250:3702` in continuous 60-second intervals.
- Target subnets are pulled dynamically via secure gRPC tunnels from Vault variables; cleartext local `.env` or configuration properties files are forbidden.
- Discovered devices are parsed, validated, and automatically deduplicated locally via hardware ONVIF UUID vectors.
- **PTZ Play/Stop Commands:** Configure the engine to map start and stop motion controls for PTZ cameras. It must handle gRPC control payloads routing direct PTZ commands (e.g. pan, tilt, zoom actions) to physical camera nodes.
- **Asset Registration Path:** Newly discovered camera hardware profiles are instantly serialized as encrypted JSON payloads and shipped securely over the WAN using mTLS gRPC paths (`POST /api/v5/cameras/discovered`) targeting Vivek's control gateways.

### Task 1.2.2 — Profile S Unicast Forwarding Tunnel
- Code the localized stream forwarder modules intercepting unicast RTSP pipelines straight from physical camera LAN interfaces.
- Pipeline: `rtspsrc (ingest LAN) ➔ rtpjitterbuffer ➔ rtph264depay ➔ rtph264pay ➔ rtspsink` targeting the cloud ingest router endpoints.
- The transport layer routes data packets securely through a protected TLS 1.3 tunnel over mTLS gRPC communication interfaces (`grpc+tls://`).
- Implement a network fault connection wrapper running an exponential backoff retry cascade: 5s, 15s, 30s, 60s, capped at a maximum 300s threshold.

---

## Sub-Phase 1.3 — Local LAN Proxying & ANR Caching (Primary: Shubham)

### Task 1.3.1 — Profile T/M Local Multicast Loopback Proxy
- Build the core `MulticastLoopbackProxy` class to capture multicast camera streams securely.
- The appliance kernel joins the local network switch multicast group via standard non-blocking socket level `IP_ADD_MEMBERSHIP` options.
- Ingests UDP multicast data frames blocks, decrypts transport layers via Vault-rotated SRTP mode keys, and routes data straight to the localized fMP4 recording chunker proxy.

### Task 1.3.2 — Advanced Network Replenishment (ANR) Outage Cache
- **ANR Fallback Verification Rule:** Edge agent tracking loops process active heartbeats checking mTLS connection states with the central control gateways every 10 seconds. Missing 3 consecutive checks triggers an immediate localized ANR isolation state.
- Cloud upload pipelines are stopped instantly; video fragments are captured as fragmented fMP4 segments and written straight to localized storage partitions: `/var/vms/anr/{customer_id}/{site_id}/{camera_id}/`.
- **Resilient SQLite Index Layout:** Tracks localized file blocks states using a thread-safe SQLite database index engine (`/var/vms/edge/anr_index.db`) mapping the composite tuple layout:
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

### Task 1.3.3 — Off-Peak Background Delta Replication
- Upon WAN interface link restoration, the agent instantiates a background data sync thread loop.
- Extracts local clip records from the SQLite table (`WHERE synced_flag = 0`) and pushes segments sequentially up to Saurabh's Cloud Media Core chunkers.
- **Line Throttling Guard rail:** Data transfer speeds are explicitly throttled at an **80 Mbps maximum bandwidth ceiling** during off-peak hours (e.g. 02:00–06:00 local site time) to completely prevent live video streaming line contention.

### Task 1.3.4 — ONVIF Profile G Gap Sync
- Integrate a gap-checking daemon in the Edge Agent loop. The agent periodically queries the central database (via mTLS gRPC `/recordings/gaps` endpoint) to scan for missing video chunks of continuous feeds on the central server.
- If recording gaps are identified (e.g., from network drops or server downtime), the Edge Agent retrieves the missing video chunks from the local 512GB edge storage and uploads/synchronizes them to the central server using ONVIF Profile G protocols.

---

## Sub-Phase 1.4 — Real-Time Health Telemetry Streaming (Primary: Shubham)

### Task 1.4.1 — Health Telemetry Streaming Engine
- Code the native C++ telemetry engine running on a continuous, strict 10-second cadence window.
- Collects edge appliance system metrics and camera hardware statistics, pushing data streams over binary protobuf message buffers directly to Vivek's background consumers.
- Protobuf metrics schema contracts:

```protobuf
  message CameraHealth {
    string customer_id   = 1; // Root Tenant Partitioning Key
    string site_id       = 2;
    string camera_id     = 3;
    string status        = 4; // ONLINE | OFFLINE | ERROR
    float  fps           = 5;
    uint32 bitrate_kbps  = 6;
    float  packet_loss   = 7;
  }

  message EdgeHealth {
    string customer_id                    = 1;
    string site_id                        = 2;
    string gateway_id                     = 3;
    float  cpu_pct                        = 4;
    float  mem_pct                        = 5;
    uint64 anr_bytes_used                 = 6;
    bool   wan_up                         = 7;
    repeated string multicast_subscriptions = 8;
  }
```

### Task 1.4.2 — Local Ticketing & Exception Queue
- Maintain a local database table `edge_events` in the SQLite engine (`anr_index.db`) storing hardware exceptions, camera connection drops, video losses, and security alerts.
- This queue acts as the local transactional log that is pushed to Vivek's central Alarm and Ticketing module via the mTLS gRPC telemetry stream.

---

## Cross-Owner Interfaces & Protocol Commit Gates (Shubham ➔ Vivek / Saurabh)

| Interface Channel Identifier | Delivery Protocol Layer | Track Destination | Schema Structural Requirements & Payload Links |
| --- | --- | --- | --- |
| `POST /api/v5/cameras/discovered` | mTLS gRPC Tunnel | Vivek Gateway | Serialized JSON payloads parsing newly discovered device hardware profiles directly into sharded database tables. |
| Telemetry Stream Channels | Protobuf gRPC Stream | Vivek Workers | Routes active `CameraHealth` and `EdgeHealth` data structures inside isolated loops every 10s. |
| Local Loopback Proxy Keys | Vault Secret Engine | Saurabh Cloud ➔ Shubham Edge | Fetches rotated LAN SRTP counter-mode decryption keys dynamically from Vault at multicast socket binding intervals. |
