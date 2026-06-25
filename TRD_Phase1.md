# Technical Requirements Document (TRD)

## Enterprise Video Management System — Phase 1 SaaS Multi-Tenant Edition

| Field            | Value                           |
| ---------------- | ------------------------------- |
| Document Version | 1.1 (Revised SaaS Architecture) |
| Status           | Baseline — Phase 1 Locked       |
| Date             | June 2026                       |
| Tech Lead        | Vivek Ranjan                    |
| Classification   | Internal / Confidential         |
| SRS Reference    | v5.1 (Shared B2B SaaS Edition)  |
| PRD Reference    | PRD_Phase1.md v1.1              |
| Standard         | IEEE Std 830-1998               |

---

## Table of Contents

1. Technical Overview
2. System Architecture (Phase 1)
3. Component Specifications
4. API Contract (Phase 1)
5. Data Architecture
6. Infrastructure & Deployment
7. Non-Functional Requirements
8. Security Requirements
9. Integration Contracts (Cross-Owner)
10. Testing Requirements
11. CI/CD & DevOps Requirements
12. Observability Requirements
13. Phase 1 Technical Constraints
14. Technical Debt Register

---

## 1. Technical Overview

### 1.1 Architectural Model

Phase 1 deploys a centralized cloud-native, shared B2B multi-tenant SaaS architecture. Two physical boundaries are strictly enforced:

**On-Premises (Edge Layer Appliance):**

- IP cameras deployed on local networks (ONVIF S/G/T/M).
- L2/L3 switches supporting IGMPv3 Snooping operations.
- Native C++ Edge Agent application instances (Hardened Debian 12 minimal environment co-owned by Shubham + Saurabh) — executing dynamic auto-discovery, local PTZ command loops, and local ANR storage partition caching.

**Centralized Cloud Platform Cluster (Kubernetes):**

- C++ Cloud Media Core (Shubham + Saurabh ownership) — frame ingestion, transcoding graphs, and continuous fMP4 stream segment chunking into object stores.
- NestJS Control Plane Engine (Vivek ownership) — 3 process-isolated infrastructure deployment setups.
- Target Patroni PostgreSQL 16 Cluster — Core relational storage engineered upfront with strict multi-tenant database partitioning keys to seamlessly ingest historical configurations data loops from legacy accounts.
- Redis 7 Cluster — Active user presence tracking caches, pub/sub signals, and multi-tenant async alerting streams pipelines.
- MongoDB 7 PSS Cluster — Immutable append-only operational security audit logs history.
- MinIO Infrastructure — Multi-tenant partitioned hot/warm object buckets layout.
- HashiCorp Vault Cluster — Key management service initializing Root to Intermediate CA hierarchies (RSA-2048).

### 1.2 Process Isolation Mandate (Pillar 4 — Non-Negotiable)

NestJS must run as THREE structurally separate Kubernetes Deployments from Day 1 to ensure system resilience:

Deployment 1: vms-api-gateway
— Handles: Multi-tenant API REST endpoints gateway (/api/v5/\*), active WebSocket connection entrypoints, identity JWT verification, and dynamic entitlements gating.
— Does NOT: Consume Redis Streams, run heavy background jobs, or process asynchronous microservice alerts.

Deployment 2: vms-event-workers
— Handles: Asynchronous processing of incoming AIEYE webhook payloads intercepted directly inside partitioned Redis Streams, managing system health updates, and rules execution.
— Does NOT: Serve public HTTP request channels or handle active user WebSocket allocations.

Deployment 3: vms-ws-broadcaster
— Handles: Dynamic real-time alerts fan-out to active operators UI layout blocks based on site token validation.
— Does NOT: Execute transactional backend logic or ingest telemetry event streams directly.

Rationale: High-throughput backpressure inside the Redis micro event bus or processing spikes in background workers must NEVER introduce latency bottlenecks or choke interactive public API traffic. Violation of this deployment isolation boundary is a critical architectural gate failure.

### 1.3 Locked Technology Stack

| Layer                        | Technology Platform               | Version Baseline                  | Sovereign Team Owner    |
| ---------------------------- | --------------------------------- | --------------------------------- | ----------------------- |
| Media Ingest Engine          | C++ 17 + GStreamer Framework      | GStreamer 1.22, CMake 3.25        | Shubham + Saurabh       |
| Edge Gateway Appliance       | C++ 17, Hardened Operating Loop   | Debian 12 minimal configuration   | Shubham + Saurabh       |
| SaaS Control Plane           | Node.js + NestJS Framework Core   | Node 20 LTS, NestJS 10, Prisma    | Vivek                   |
| Web Management Portal        | React + TypeScript + Vite         | React 18, TS 5 strict, Vite 5     | Vivek                   |
| Operator Workstation UI      | Electron Shell Container Client   | Electron 28 + WebGPU Canvas       | Vivek                   |
| Video Matrix Wall Core       | Linux Thin Client + Hardware SDK  | Native multi-monitor loop drivers | Vivek                   |
| Solo Cross-Platform Mobile   | Flutter + Dart SDK Infrastructure | Flutter 3.x, Dart 3.x execution   | Sagar (Solo Track Lead) |
| Relational Database          | High Availability PostgreSQL Core | PostgreSQL 16 + Patroni Cluster   | Vivek                   |
| Real-time Event Bus / Cache  | Redis Enterprise Cluster          | Redis 7, ioredis client module    | Vivek                   |
| Immutable Audits Ledger      | MongoDB Replica Set Configuration | MongoDB 7, strict Mongoose model  | Vivek                   |
| Multi-Tenant Object Pools    | MinIO S3-Compatible Framework     | Erasure-coded deployment          | Shubham + Vivek         |
| Identity Cryptography Engine | HashiCorp Vault Cluster Setup     | Vault 1.16, Raft Consensus        | Vivek                   |
| Cloud Orchestration Mesh     | Kubernetes Orchestration Tier     | K8s 1.29+, Helm, Argo CD          | Vivek                   |
| Monitoring & Observability   | Prometheus, Loki, Tempo, Grafana  | Latest stable production stacks   | Vivek                   |

**Stack is frozen. Substitutions require written CCB approval.**

---

## 2. System Architecture (Phase 1)

### 2.1 Component Interaction Map

```
┌──────────────────────────────────────────────────────────────────┐
│  SAAS CLIENT INTERACTION ENVIRONMENT                             │
│  React Portal UI (Vivek)    Electron WebGPU Matrix (Vivek)    Solo Flutter App (Sagar)            │
| Dynamic Custom Sites       Multi-Monitor Video Canvas Panel  Secure Enclave Storage                                                   |
│  Monitoring | Archives     Login | HLS Live View                │
│  Admin | Dashboards        1×1 and 2×2 grids                    │
└──────────────┬─────────────────────────┬────────────────────────┘
               │ HTTPS / WSS             │ HTTPS / HLS
               │ TLS 1.3                 │ TLS 1.3

┌───────────────────────▼───────────────────────────────────────────────▼────────────────┐
│  NGINX INGRESS CONTROLLER (TLS 1.3 Termination, Central cert-manager Routing)   │
└───────────────────────┬────────────────────────────────────────────────────────────────┘
│ Secure Internal Microservices Load Balancing
┌───────────────────────▼────────────────────────────────────────────────────────────────┐
│  SHARED-CONTROL-PLANE NESTJS INFRASTRUCTURE (ns: control-plane)           │
│                                                                                        │
│  ┌──────────────────────────┐  ┌──────────────────────────┐  ┌───────────────────────┐ │
│  │     vms-api-gateway      │  │    vms-event-workers     │  │   vms-ws-broadcaster  │ │
│  │ REST + WebSocket ingress │  │ Redis Streams Ingestion  │  │ User Session Fan-Out  │ │
│  │ JWT + RBAC Enforcement   │  │ AIEYE Payload Processing │  │ Site Token Matching   │ │
│  │ Scoped Email Unique index│  │ XCLAIM Crash Recovery    │  │ Sticky Session IP     │ │
│  └────────────┬─────────────┘  └────────────┬─────────────┘  └───────────┬───────────┘ │
└───────────────┼─────────────────────────────┼────────────────────────────┼─────────────┘
│ Prisma Client Queries       │ Event Bus Processing       │ Active WS Channels
┌───────────────▼─────────────────────────────▼────────────────────────────▼─────────────┐
│  ISOLATED DATA INFRASTRUCTURE (ns: data)                                     │
│  PostgreSQL 16 HA (Patroni)        Redis 7 Cluster Database        MongoDB 7 PSS       │
│  Every Row: customer_id  vms:ai-event:{customer_id}      Immutable auditLogs │
└───────────────┬────────────────────────────────────────────────────────────────────────┘
│ Multi-Tenant Context Injection & Ingestion Pipelines
┌───────────────▼────────────────────────────────────────────────────────────────────────┐
│  CLOUD MEDIA CORE INGEST ENGINE (ns: media — Shubham + Saurabh Joint Ownership)│
│  Stream Routing Load Balancing | GStreamer Fragmented continuous fMP4 segmenting chunkers│
│  Central HA coturn TURN Fleet (N+1 Redundancy) | HLS Adaptive Bitrate Stream Gateways │
└───────────────┬────────────────────────────────────────────────────────────────────────┘
│ TLS 1.3 Secure WAN Tunnel (High-Band Sustained Capability ≥ 100 Mbps)
┌───────────────▼────────────────────────────────────────────────────────────────────────┐
│  ON-PREMISES DISTRIBUTED EDGE LAYER (Debian 12 Hardened Appliance — Shubham + Saurabh)│
│  ONVIF WS-Discovery engine | Dynamic Live Video Ingest Forwarders | PTZ Command Relay  │
│  512 GB Local ANR Partition Cache with Automated Off-Peak Asynchronous WAN Delta Sync  │
└───────────────┬────────────────────────────────────────────────────────────────────────┘
│ Switch Enforced IGMPv3 Snooping Layer Protocols
┌───────────────▼────────────────────────────────────────────────────────────────────────┐
│  LOCAL CAMERA NETWORK INFRASTRUCTURE                                         │
│  ONVIF S/G/T/M IP Hardware Nodes ➔ Dynamic Frontend Form Mapping Layouts   │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Three Independent Data Flows

**Media Flow (Profile T/M cameras):**
Camera → UDP multicast (LAN) → Operator workstations (live view via WebGPU)
→ Edge Agent loopback proxy subscriber
→ WAN tunnel → Media Core → MinIO HOT tier  
**Media Flow (Profile S cameras):**
Camera → RTSP unicast → Edge Agent → TLS tunnel → Media Core → MinIO HOT tier  
**Control Flow:**
Client → API Gateway → Control Plane → Redis pub/sub → Edge Agent → Camera
(PTZ, config, discovery commands)  
**Event Flow (Including Intercepted AIEYE Payloads):**
Media Core / AIEYE Webhook → Redis Streams → Event Workers → PostgreSQL / MongoDB
→ Redis pub/sub → WS Broadcaster → Clients

### 2.3 Kubernetes Namespace Layout

ns: ingress — NGINX Ingress Controller, cert-manager orchestration
ns: control-plane — api-gateway (2+ replicas), event-workers (2+), ws-broadcaster (2+)
ns: media — media-core pods (GPU node pool, 2+ replicas matching N+1)
ns: data — PostgreSQL primary + standby, Redis Cluster (6 nodes), MongoDB PSS (3 nodes)
ns: storage — MinIO (4+ nodes, erasure-coded cluster infrastructure)
ns: security — Vault (Raft multi-node cluster, RSA-2048 initialization engine)
ns: observability — Prometheus, Loki, Tempo, Grafana, Alertmanager stack

---

## 3. Component Specifications

### 3.1 NestJS API Gateway (`apps/api-gateway`)

**Runtime:** Node.js 20 LTS, NestJS 10, TypeScript 5 strict mode
**Framework modules:** `@nestjs/jwt`, `@nestjs/passport`, `@nestjs/typeorm`, `@nestjs/mongoose`, `@nestjs/swagger`, `nestjs-pino`, `@willsoto/nestjs-prometheus`, `@opentelemetry/sdk-node`

**Responsibilities:**

- TLS termination via NGINX ingress; api-gateway itself runs HTTP internally.
- JWT verification via Passport `JwtStrategy` on every single protected route.
- Default-deny RBAC via `RolesGuard`. Every route must declare access variables; undeclared routes return HTTP 403 to ALL callers.
- Enforces tenant-scoped unique user validation constraints: `CONSTRAINT unique_tenant_email UNIQUE (customer_id, email)`.
- Redis blacklist token check on every single request to intercept revoked sessions.
- Rate limiting via Redis sliding window (5 failures/IP/min on auth endpoints).
- Cryptographic key verification extraction: reads and validates `mfa_secret_ref` pointers directed at Vault.
- Attachment of `AuditInterceptor` loops to all state-changing transactional controllers.

**What it must NOT do:**

- Consume Redis Streams or execute backend event bus routines.
- Run background jobs, cron tasks, or schedulers.
- Subscribe to Redis pub/sub channels directly.

**HPA configuration:**

- Scale metric: CPU utilisation ≥ 70%
- Min replicas: 2; Max replicas: 10
- PodDisruptionBudget: `minAvailable 1`

**Resource limits:**

- CPU request: 250m; limit: 1000m
- Memory request: 512Mi; limit: 1Gi

### 3.2 NestJS Event Workers (`apps/event-workers`)

**Runtime:** Node.js 20 LTS, NestJS 10
**Responsibilities:**

- Redis Streams consumption: `vms:camera-status`, `vms:recording-lifecycle`, and `vms:ai-event:{customer_id}:{site_id}` payload queues.
- Recording index serialization to PostgreSQL rows on active lifecycle triggers.
- Camera health status updates inside PostgreSQL tables based on incoming edge telemetry.
- Job Scheduler: Nightly storage retention cleanups and capacity allocation reporting.
- `XCLAIM`-based crash recovery routine execution (30-second pending task timeout metrics).
- Batch processing configuration ceiling: `COUNT 50` elements per `XREADGROUP` tick.
- Enforces libuv thread pool protection: mandatory `setImmediate()` execution yield after every batch iteration to prevent loop starvation.

**What it must NOT do:**

- Serve public HTTP REST gateways or expose WebSocket server loops.
- Handle direct client authentication verification.

**HPA configuration (Phase 1):**

- Scale metric: Manual HPA based on CPU/Memory metrics (KEDA deferred to Phase 2).
- Min replicas: 2; Max replicas: 5.

### 3.3 NestJS WebSocket Broadcaster (`apps/ws-broadcaster`)

**Runtime:** Node.js 20 LTS, NestJS 10, `@nestjs/websockets`, `socket.io`
**Responsibilities:**

- Maintain persistent real-time WebSocket communication channels per authenticated operator.
- Subscribe to multi-tenant scoped Redis pub/sub channels: `ws:camera:{customer_id}:{site_id}`, `ws:alarm:{customer_id}:{site_id}`.
- Fan-out live system telemetry alerts to connected operator UI view layouts matching target token contexts.
- Session-aware isolation: drops or restricts broadcasts to connections lacking valid states inside the Redis session cache.

**Sticky sessions:** Strictly Required — WebSocket handshakes must hit the same container replica node. Kubernetes Service configuration parameter: `sessionAffinity: ClientIP`.
**Phase 1 capacity:** Sized to maintain ≤ 50 concurrent active connections during validation cycles.

### 3.4 C++ Cloud Media Core (Co-Owners: Shubham + Saurabh)

**Language Stack:** C++17, GStreamer 1.22 pipelines, `hiredis`, AWS C++ SDK (MinIO target integration), gRPC
**Build Tooling:** CMake 3.25+, Conan package manager
**Node pool:** Dedicated NVIDIA GPU (T4/L4/A10 cluster nodes); automatic software decode fallback on CPU clusters.

**Phase 1 pipeline responsibilities:**

- Profile S: RTSP media ingest → network jitter buffer → hardware acceleration decode → adaptive HLS and WebRTC output streams.
- Profile T/M: Capture direct multicast stream data forwarded from local Edge Agent loops ➔ process fragmented continuous fMP4 recording segment creation.
- Stream Router: Dynamically binds stream targets and tracks recorder allocations, indexing configurations via the master composite signature: `{customer_id}:{site_id}:{camera_id}` inside Redis.
- HLS Gateway engine: Generates 2-second encrypted streaming segment slices served over HTTP, checking client authentication tokens via gRPC loops with the control core.
- WebRTC Gateway orchestration: ICE handling via central coturn TURN cluster; SDP signalling data routed through NestJS broadcaster.
- Continuous Recording segmenter: Emits ISO BMFF / fMP4 clips in 15-minute intervals (adjustable 5–60 min), pushing segments directly to MinIO HOT buckets.
- Emits real-time event updates to the micro event bus: `vms:camera-status` on edge changes, and `vms:recording-lifecycle` on segment closure.

**Kubernetes deployment configuration:**

- `nodeSelector`: `nvidia-gpu-node-pool` cluster nodes.
- Resource caps: GPU 1, CPU 4, Memory 8Gi (Hard execution boundaries).
- Resiliency: Stream Router enforces an automatic 30-second camera reallocation map on pod cluster node failures.
- Safety headroom buffer: Container load limits must never cross a 90% threshold.

### 3.5 C++ Edge Agent Appliance (Co-Owners: Shubham + Saurabh)

**Language & Environment:** C++17, GStreamer 1.22, gSoap, `hiredis`, SQLite 3, running inside a minimalist, hardened Debian 12 footprint.
**Compilation Targets:** Cross-compiled native binaries for `x86_64` and `aarch64` architectures.
**Security Signing Gate:** Enforces RSA cryptographic signature verification at boot; unsigned files are rejected immediately.

**Phase 1 responsibilities:**

- ONVIF WS-Discovery engine: Loops continuously in 60-second intervals, scanning network subnets delivered via Vault, deduplicating devices via target UUID arrays.
- Camera registration mapping: Emits discovered hardware configurations to the backend control layers via secure mTLS gRPC communication paths.
- Profile T/M local loopback: Subscribes direct to local LAN switch multicast groups, captures frame data chunks, and transfers payload parameters over WAN interfaces.
- Profile S media proxying: Pulls unicast RTSP streams from hardware endpoints and forwards data pipelines securely over TLS tunnels to Cloud Media Core.
- Advanced Network Replenishment (ANR): If WAN interface disconnection events trigger, it automatically isolates fMP4 stream clips inside localized `/var/vms/anr/{customer_id}/{site_id}/` storage paths. Upon interface restoration, it initiates an off-peak delta sync cycle restricted to an 80 Mbps maximum ceiling to block line contention.
- Local SQLite tracking: Manages a resilient data table tracking local ANR slices state `(customer_id, site_id, camera_id, local_path, synced_flag)`.
- PTZ execution bridge: Collects control actions sent from operators via Redis pub/sub channels and transforms parameters into direct ONVIF PTZ commands.

### 3.6 React Web Client (`apps/web-client` — Vivek Ownership)

**Core Architecture Stack:** React 18 functional components and hooks execution only, TypeScript 5 strict mode, Zustand for volatile token state isolation, React Query, Tailwind CSS 3.

**Dynamic Site Layout Model (Form Ingestion Pattern):**

- Static, rigid checking constraints or hardcoded database lists for `site_type` are completely removed.
- The user interface dashboard introduces an open, flexible alphanumeric form layout where the Tenant Admin typed entries are captured directly.
- The portal components dynamically manage and map variable multi-tile camera allocations to those custom UI-generated site definitions without triggering backend database validation crashes.

**Mandatory Client Guidelines:**

- Encapsulate all route-level containers within custom React Error Boundaries to isolate rendering exceptions.
- Implement a complete Skeleton Loader UX treatment on all asynchronous data-fetching layout contexts.
- Volatile Session Rule: Banned saving or caching JWT authentication material inside local web memory buckets (`localStorage`/`sessionStorage`).

### 3.7 Solo Cross-Platform Mobile App (`mobile/` — Sagar Solo Track Lead)

**Runtime Environment:** Single-repository Flutter 3.x and Dart 3.x configuration, managed under sovereign development lines.
**State Architecture:** Clean implementation of the `flutter_bloc` design pattern and `GetIt` dependency injectors.
**Video Compositor Engine:** Handles active streaming frame layouts using the native `video_player` plugin mapped inside a structural `Texture` widget canvas; rendering media via loose `PlatformView` elements is forbidden.

**Mandatory Platform Patterns:**

- **DecoderPool Semaphore:** Implements a hardware decoder state machine that caps maximum concurrent active decoders at a hard ceiling of 4. This system component must be fully integrated and verified via unit tests before any UI layout code is pushed.
- **RepaintBoundary Isolation:** Wraps individual video tile modules explicitly to isolate high-throughput 30fps streaming paint cycles away from the root UI thread compositor layer.
- **Hardware-Backed Cryptographic Isolation:** Connects via native platform channels to keep security tokens and credentials locked within hardware-isolated cryptoprocessors: Android Keystore preferences and iOS Secure Enclave Keychain services (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`).
- **SPKI Cryptographic Hash Pinning:** Enforces absolute transport validation inside network clients (`NSURLSession` and `OkHttp`), executing Subject Public Key Info hash pinning against the base64 SHA-256 token of our Vault Intermediate CA; binding finger-prints to changing leaf nodes is banned.
- Prevents concurrent refresh token race condition errors across multi-tile widgets using a global async `RefreshLock` built on a Dart `Completer` routine.

---

## 4. API Contract (Phase 1 Multi-Tenant Revision)

### 4.1 Base URL & Versioning

Production Environment: https://api.vms.serviceprovider.com/api/v5 Staging Testing Mesh: https://api.staging.vms.serviceprovider.com/api/v5  
All Module Route Paths: /api/v5/{resource}

### 4.2 Authentication Endpoints

#### `POST /api/v5/auth/login`

- **Description:** Entry path for multi-tenant operator logins.
- **Body Request Payload:**

````json
  {
    "customer_id": "tenant-uuid-v4-string",
    "email": "operator@customer.com",
    "password": "secure_password_string",
    "totpCode": "123456"
  }
- **Success Response (200):** Emits a short-lived token to application memory and injects a secure identity tracking cookie:
  ```json
  {
    "accessToken": "ey...volatile_short_lived_token_string",
    "user": {
      "userId": "uuid-v4-string",
      "customer_id": "tenant-uuid-v4-string",
      "username": "shubham_admin",
      "baseRole": "ADMIN"
    }
  }
  ```
- **Response Headers:**
  ```http
  Set-Cookie: vms_refresh=sha256_token_hash; HttpOnly; Secure; SameSite=Strict; Path=/api/v5/auth/refresh; Max-Age=2592000
  ```
- **Errors Enforced:**
  - **HTTP 401:** Unauthorized access triggers (generic responses masking invalid fields).
  - **HTTP 429:** Sliding window rate-limiting block (triggered on 5 sequential errors per IP per minute).

#### `POST /api/v5/auth/refresh`

- **Description:** Rotates active access tokens via secure cookies.
- **Cookie Dependency:** `vms_refresh` (HttpOnly constraint — processed automatically by transport layer).
- **Success Response (200):**
  ```json
  {
    "accessToken": "ey...new_rotated_string"
  }
  ```
  *(emits a new cookie token bundle)*
- **Errors Enforced:**
  - **HTTP 401:** If token references are expired, revoked, or missing from the Redis blacklist cache.

#### `POST /api/v5/auth/logout`

- **Header Required:** `Authorization: Bearer {accessToken}`
- **Success Response (204):** No Content.
- **Immediate Side Effects:** Commits a synchronous block record to the Redis session blacklist (`SET jwt:blacklist:{sessionId} 1 EX {remaining_ttl}`) and mutates the relational token status column to disabled.

#### `GET /api/v5/auth/me`

- **Header Required:** `Authorization: Bearer {accessToken}`
- **Success Response (200):** Returns full profile model payload `UserProfileDto`.

### 4.3 User Management Endpoints

#### `GET /api/v5/users`

- **Authorized Role Requirement:** `ADMIN`
- **Query Filters:** `?siteId=uuid&page=1&limit=50`
- **Success Response (200):** `PaginatedDto<UserResponseDto>` (Returns context records filtered strictly by the caller's tenant token profile).

#### `POST /api/v5/users`

- **Authorized Role Requirement:** `ADMIN`
- **Body Request Payload:**
  ```json
  {
    "email": "manager@tenant-a.com",
    "password": "temporary_password_string",
    "baseRole": "OPERATOR",
    "siteId": "uuid-v4-string"
  }
  ```
- **Success Response (201):** Returns the generated profile row. System processes creation tasks under the multi-tenant index rule (`UNIQUE(customer_id, email)`), completely eliminating cross-tenant collision blocks.

#### `PATCH /api/v5/users/:userId`

- **Authorized Role Requirement:** `ADMIN`
- **Body Request Payload:**
  ```json
  {
    "baseRole": "SUPERVISOR",
    "isActive": true
  }
  ```
- **Success Response (200):** Updated profile configuration payload.

#### `DELETE /api/v5/users/:userId`

- **Authorized Role Requirement:** `ADMIN`
- **Success Response (204):** Triggers a soft-delete database routine (`is_active = FALSE`) and clears corresponding session maps inside Redis.

#### `POST /api/v5/users/:userId/mfa/totp/enroll`

- **Authorized Role Requirement:** `ADMIN`, or self enrollment workflows (`OPERATOR`, `VIEWER`).
- **Success Response (200):**
  ```json
  {
    "secret": "vault_encrypted_string_stub",
    "qrCodeDataUrl": "data:image/png;base64..."
  }
  ```

#### `POST /api/v5/users/:userId/mfa/totp/verify`

- **Body Request Payload:**
  ```json
  {
    "totpCode": "543210"
  }
  ```
- **Success Response (200):** Activates cryptographic MFA verification tracking on the target account.

### 4.4 Camera Management Endpoints

#### `GET /api/v5/cameras`

- **Authorized Role Requirement:** `VIEWER`, `OPERATOR`, `ADMIN`
- **Query Filters:** `?siteId=uuid&status=CONNECTED&page=1&limit=100`
- **Enforcement Parameter:** For non-admin accounts, the `customer_id` and site scope fields are extracted strictly from the validated JWT signature; manual override params are ignored to block escalation tricks.
- **Success Response (200):** `PaginatedDto<CameraResponseDto>`

#### `POST /api/v5/cameras`

- **Authorized Role Requirement:** `OPERATOR`, `ADMIN`
- **Body Request Payload:**
  ```json
  {
    "siteId": "uuid-v4-site-token",
    "name": "Main Entrance Camera 1",
    "ipAddress": "192.168.10.25",
    "rtspUrl": "rtsp://admin:pass@192.168.10.25:554/stream1",
    "onvifProfile": "T",
    "codec": "H264",
    "ptzCapable": true
  }
  ```
- **Success Response (201):** Camera configuration row mapped under composite multi-tenant database links.

#### `POST /api/v5/cameras/discover`

- **Authorized Role Requirement:** `OPERATOR`, `ADMIN`
- **Body Request Payload:**
  ```json
  {
    "siteId": "uuid-string",
    "subnets": [
      "192.168.1.0/24"
    ]
  }
  ```
- **Success Response (202):**
  ```json
  {
    "jobId": "discovery-job-uuid"
  }
  ```
  *(Asynchronous task tracking; discovered nodes are broadcasted over WebSockets)*

#### `POST /api/v5/cameras/discovered` *(Internal Protocol — mTLS Enforced)*

- **Description:** Pathway for C++ Edge Agent data drops.
- **Body Request Payload:**
  ```json
  {
    "siteId": "uuid-string",
    "ipAddress": "192.168.1.50",
    "onvifProfile": "M",
    "rtspUrl": "rtsp://...",
    "uuid": "hardware-device-uuid-string",
    "manufacturer": "Hikvision"
  }
  ```
- **Success Response (200 | 201):** Acknowledged and indexed.

#### `PATCH /api/v5/cameras/:cameraId`

- **Authorized Role Requirement:** `OPERATOR`, `ADMIN`
- **Enforcement Parameter:** Statement statements require the complete multi-tenant composite lookup tuple: `(customer_id, siteId, cameraId)`.
- **Body Request Payload:**
  ```json
  {
    "name": "Updated Entrance Name",
    "codec": "H265"
  }
  ```
- **Success Response (200):** `CameraResponseDto`

#### `DELETE /api/v5/cameras/:cameraId`

- **Authorized Role Requirement:** `ADMIN`
- **Success Response (204):** Removes device hardware profiles; video index parameters are preserved with a null reference to guard historical recording segments continuity.

#### `GET /api/v5/cameras/:cameraId/health`

- **Authorized Role Requirement:** `VIEWER`, `OPERATOR`, `ADMIN`
- **Success Response (200):**
  ```json
  {
    "status": "CONNECTED",
    "fps": 25,
    "bitrateKbps": 2048,
    "packetLossPct": 0.02,
    "lastSeenAt": "ISO-8601-Timestamp"
  }
  ```

### 4.2 Core Multi-Tenant Ingestion Endpoints

#### `POST /api/v5/auth/login`

- **Description:** Entry path for multi-tenant operator logins.
- **Body Request Payload:**
  ```json
  {
    "customer_id": "tenant-uuid-v4-string",
    "email": "operator@customer.com",
    "password": "secure_password_string",
    "totpCode": "123456"
  }
  ```
- **Success Response (200):** Emits a short-lived token to application memory and injects a secure identity tracking cookie:
  ```json
  {
    "accessToken": "ey...volatile_short_lived_token_string",
    "user": {
      "userId": "uuid-v4-string",
      "customer_id": "tenant-uuid-v4-string",
      "username": "shubham_admin",
      "baseRole": "ADMIN"
    }
  }
  ```
- **Response Headers:**
  ```http
  Set-Cookie: vms_refresh=sha256_token_hash; HttpOnly; Secure; SameSite=Strict; Path=/api/v5/auth/refresh; Max-Age=2592000
  ```
- **Errors Enforced:**
  - **HTTP 401:** Unauthorized access triggers (generic responses masking invalid fields).
  - **HTTP 429:** Sliding window rate-limiting block (triggered on 5 sequential errors per IP per minute).

#### `POST /api/v5/users`

- **Access Control:** `ADMIN`
- **Body Request Payload:**
  ```json
  {
    "email": "string",
    "password": "string",
    "baseRole": "string",
    "siteId": "string"
  }
  ```
- **Behavior:** Schema maps incoming identities under the tenant composite constraint rule, completely eliminating multi-tenant account collision bugs.

#### `POST /api/v5/cameras`

- **Access Control:** `OPERATOR`, `ADMIN`
- **Body Request Payload:**
  ```json
  {
    "siteId": "string",
    "name": "string",
    "ipAddress": "string",
    "rtspUrl": "string",
    "groupToken": "string"
  }
  ```
- **Behavior:** Explicitly structures camera mappings using the multi-tenant composite primary lookup index.

#### `GET /api/v5/recordings/stream`

- **Access Control:** `VIEWER`, `OPERATOR`, `ADMIN`
- **Query Parameters:** `?siteId=uuid&cameraId=uuid`
- **Response (200):**
  ```json
  {
    "hlsUrl": "string"
  }
  ```
  *(Signed streaming parameter, valid for exactly 1 hour)*
- **Security Rule (FR-PBK011):** Client platforms are strictly forbidden from connecting directly to raw Media Core stream endpoints; the NestJS control gateway executes authentication validation first before issuing signed media path references.

### 4.5 Recording Endpoints

#### `GET /api/v5/recordings`

- **Authorized Role Requirement:** `VIEWER`, `OPERATOR`, `ADMIN`
- **Query Filters:** `?siteId=uuid&cameraId=uuid&date=2026-06-24&type=CONTINUOUS`
- **Success Response (200):** `RecordingSegment[]` *(Returns array models matching target tenant partition)*

#### `POST /api/v5/recordings/start`

- **Authorized Role Requirement:** `OPERATOR`, `ADMIN`
- **Body Request Payload:**
  ```json
  {
    "siteId": "uuid-string",
    "cameraId": "uuid-string"
  }
  ```
- **Success Response (200):**
  ```json
  {
    "segmentId": "generated-segment-uuid"
  }
  ```

#### `POST /api/v5/recordings/stop`

- **Authorized Role Requirement:** `OPERATOR`, `ADMIN`
- **Body Request Payload:**
  ```json
  {
    "siteId": "uuid-string",
    "cameraId": "uuid-string"
  }
  ```
- **Success Response (200):** `Complete`

#### `GET /api/v5/recordings/stream`

- **Authorized Role Requirement:** `VIEWER`, `OPERATOR`, `ADMIN`
- **Query Filters:** `?siteId=uuid&cameraId=uuid`
- **Success Response (200):**
  ```json
  {
    "hlsUrl": "https://media.serviceprovider.com/hls/cust-id/site-id/cam-id/live.m3u8?token=signed_signature"
  }
  ```
- **Critical Security Constraint (FR-PBK011):** Clients never negotiate directly with Media Core. The NestJS Control plane validates credentials first, passing back a signed temporary asset reference token.

#### `GET /api/v5/recordings/:segmentId/stream`

- **Authorized Role Requirement:** `VIEWER`, `OPERATOR`, `ADMIN`
- **Success Response (200):**
  ```json
  {
    "hlsPlaybackUrl": "https://media.serviceprovider.com/playback/..."
  }
  ```
  *(Signed, 1-hour lifecycle token)*

#### `POST /api/v5/recordings/:segmentId/export`

- **Authorized Role Requirement:** `OPERATOR`, `ADMIN`
- **Body Request Payload:**
  ```json
  {
    "watermark": true,
    "reason": "Incident investigation investigation loop"
  }
  ```
- **Success Response (202):**
  ```json
  {
    "exportId": "export-task-uuid"
  }
  ```
  *(Triggers async assembly of scattered fMP4 clip segments into an integrated MP4 wrapper)*

#### `GET /api/v5/recordings/exports/:exportId`

- **Authorized Role Requirement:** `OPERATOR`, `ADMIN`
- **Success Response (200):**
  ```json
  {
    "status": "COMPLETE",
    "downloadUrl": "https://vms-exports.s3.com/..."
  }
  ```
  *(Download URL remains active for exactly 24 hours)*

### 4.6 Schedule Endpoints

#### `GET /api/v5/schedules`

- **Authorized Role Requirement:** `OPERATOR`, `ADMIN`
- **Query Filters:** `?siteId=uuid&cameraId=uuid`
- **Success Response (200):** `RecordingSchedule[]`

#### `POST /api/v5/schedules`

- **Authorized Role Requirement:** `ADMIN`
- **Body Request Payload:**
  ```json
  {
    "siteId": "uuid-string",
    "cameraId": "uuid-string",
    "name": "Standard Night Shift Continuous Recording Schedule",
    "startTime": "22:00:00",
    "endTime": "06:00:00",
    "daysOfWeek": [1, 2, 3, 4, 5],
    "timezone": "Asia/Kolkata",
    "retentionDays": 30
  }
  ```
- **Success Response (201):** Generated schedule configuration block.

#### `PATCH /api/v5/schedules/:scheduleId`

- **Authorized Role Requirement:** `ADMIN`
- **Body Request Payload:**
  ```json
  {
    "isEnabled": false
  }
  ```
- **Success Response (200):** `RecordingSchedule`

#### `DELETE /api/v5/schedules/:scheduleId`

- **Authorized Role Requirement:** `ADMIN`
- **Success Response (204):** Operation complete.

### 4.7 Health Endpoints

#### `GET /api/v5/health/cameras`

- **Authorized Role Requirement:** `VIEWER`, `OPERATOR`, `ADMIN`
- **Query Filters:** `?siteId=uuid`
- **Success Response (200):** `CameraHealthSummary[]`

#### `GET /api/v5/health/storage`

- **Authorized Role Requirement:** `OPERATOR`, `ADMIN`
- **Query Filters:** `?siteId=uuid`
- **Success Response (200):**
  ```json
  {
    "hotPct": 65.4,
    "warmPct": 22.1,
    "coldPct": 0.0,
    "alertThreshold": 80.0
  }
  ```

#### `GET /api/v5/health/system`

- **Authorized Role Requirement:** `ADMIN`
- **Success Response (200):**
  ```json
  {
    "apiGateway": "OK",
    "eventWorkers": "OK",
    "wsBroadcaster": "OK",
    "mediaCore": "OK",
    "databaseMesh": "OK"
  }
  ```

#### `GET /metrics` *(Observability Scrape Node — Internal network policy bound)*

- **Authorization Bypass:** None required for Prometheus scraping containers.
- **Success Response (200):** Prometheus standard text exposition dataset formats.

### 4.8 Audit Endpoints

#### `GET /api/v5/audit`

- **Authorized Role Requirement:** `ADMIN`
- **Query Filters:** `?userId=uuid&action=CAMERA_DELETE&from=ISO-Time&to=ISO-Time&page=1&limit=100`
- **Success Response (200):** `PaginatedDto<AuditLogEntry>` *(Strictly isolates logs extraction under caller company token boundaries)*

#### `GET /api/v5/audit/export`

- **Authorized Role Requirement:** `ADMIN`
- **Success Response (200):** Emits plaintext structured `.csv` payload streams.
- **Content Headers:**
  ```http
  Content-Disposition: attachment; filename="audit_export_20260624.csv"
  ```

### 4.9 Workspace Layouts Endpoints
  GET /api/v5/workspaces
    - Authorized Role Requirement: VIEWER, OPERATOR, ADMIN
    - Success Response (200): WorkspaceLayout[] (Dynamically loads multi-tile custom grid views belonging to the individual profile identity)

  POST /api/v5/workspaces
    - Body Request Payload: { "name": "Main Wall 4x4 Grid View", "tileCount": 16, "layoutJson": "{...}" }
    - Success Response (201): Workspace entity record saved.

  PATCH /api/v5/workspaces/:layoutId
    - Body Request Payload: { "isDefault": true }
    - Success Response (200): Complete.

    - DELETE /api/v5/workspaces/:layoutId
    - Success Response (204): Destroyed.

### 4.10 WebSocket System Events (vms-ws-broadcaster pipeline)

Gateway Connection Endpoint URL: wss://api.vms.serviceprovider.com/ws?token={accessToken}
Client ➔ Server Event Signals Allowed:

{ "event": "subscribe:site", "data": { "siteId": "uuid-string" } }

{ "event": "unsubscribe:site", "data": { "siteId": "uuid-string" } }

Server ➔ Client Event Push Broadcast Payloads:

Camera State Telemetry: { "event": "camera.status", "data": { "cameraId": "uuid", "siteId": "uuid", "status": "CONNECTED", "timestamp": "ISO-8601" } }

Storage Cap Alert: { "event": "storage.alert", "data": { "siteId": "uuid", "tier": "vms-hot", "usedPct": 84.2, "threshold": 80.0 } }

Recording Core Active Trigger: { "event": "recording.start", "data": { "cameraId": "uuid", "siteId": "uuid", "segmentId": "uuid" } }

Asynchronous AI Event Alert: { "event": "ai.alert.triggered", "data": { "customer_id": "uuid", "siteId": "uuid", "cameraId": "uuid", "model": "ANPR_WITH_SPEED", "payload": {...} } }


### 4.11 Standard Response Envelopes
TypeScript
// Standardized Success Paginated Container
interface PaginatedDto<T> {
  data:  T[];
  total: number;
  page:  number;
  limit: number;
}

// Standardized Compliance Error Structure
interface ErrorResponseDto {
  statusCode: number;
  code:       string;    // E.g., 'INVALID_TENANT_SIGNATURE', 'CAMERA_NOT_FOUND'
  message:    string;    // Human-readable generic statement, zero stack leaking
  path:       string;    // Request endpoint context
  timestamp:  string;    // ISO 8601 formatting
  requestId:  string;    // X-Request-ID token linking Loki logging pools
}


## 5. Data Architecture

### 5.1 PostgreSQL — Primary Entities Summary

SaaS multi-tenancy rules enforce that every single transactional database row, primary key index, and structural relationship must be bound to a root-level **`customer_id`** token to guarantee total logical data isolation between tenants.

| Table Name | Primary Index Structure | Foreign Key Dependencies & Constraints | Phase Scope |
|---|---|---|---|
| `customers` | `customer_id` (UUID Primary) | Contains `client_id` (8-char unique alphanumeric business tracker, e.g., `73121701`) | Phase 1 Core |
| `vms_modules` | `module_id` (UUID Primary) | Master SaaS modules registry catalog (`LIVE_GRID`, `PLAYBACK_ENGINE`, `EXPORT_ENGINE`) | Phase 1 Core |
| `customer_module_entitlements` | `entitlement_id` (UUID Primary) | `FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE` | Phase 1 Core |
| `users` | `user_id` (UUID Primary) | `FOREIGN KEY (customer_id) REFERENCES customers`. Contains `mfa_secret_ref` pointer. | Phase 1 Core |
| `sites` | `site_id` (UUID Primary) | `FOREIGN KEY (customer_id) REFERENCES customers`. **`site_type VARCHAR(100)` with no enums/CHECK constraints.** | Phase 1 Core |
| `user_site_permissions` | `permission_id` (UUID Primary) | `FOREIGN KEY (user_id) REFERENCES users`, `FOREIGN KEY (site_id) REFERENCES sites`. | Phase 1 Core |
| `cameras` | **`(customer_id, site_id, camera_id)`** | **Composite primary key layout.** Enforces strict multi-tenant namespace isolation. | Phase 1 Core |
| `recording_schedules` | `schedule_id` (UUID Primary) | `FOREIGN KEY (customer_id, site_id, camera_id) REFERENCES cameras`. | Phase 1 Core |
| `recordings` | `segment_id` (UUID Primary) | `FOREIGN KEY (customer_id, site_id, camera_id) REFERENCES cameras`. | Phase 1 Core |
| `edge_servers` | **`(customer_id, site_id, server_id)`** | `FOREIGN KEY (customer_id) REFERENCES customers`, `FOREIGN KEY (site_id) REFERENCES sites`. | Phase 1 Core |
| `workspace_layouts` | `layout_id` (UUID Primary) | `FOREIGN KEY (user_id) REFERENCES users`. | Phase 1 Core |

**Global Composite Key Enforcements (Non-Negotiable):**
1. Every table referencing a camera asset MUST use the composite FK tuple: `FOREIGN KEY (customer_id, site_id, camera_id) REFERENCES cameras(customer_id, site_id, camera_id)`. Standalone lookups on `camera_id` without its parent multi-tenant namespace are structurally blocked at the DB constraint layer.
2. **Dynamic UI Site Forms Mapping Rule:** To fully support custom front-end portal layout configurations, `site_type` inside the `sites` table must remain a relaxed, open string field (`VARCHAR(100)`) without any database-level hardcoded constraints or enums. Form validation and field parameters are strictly handled at the application logic tier.
3. **MFA Secret Vaulting:** The transactional user table completely removes raw `mfa_secret` text lines, replacing them with **`mfa_secret_ref VARCHAR(255)`**, which exclusively stores the reference tracking string mapping to our external HashiCorp Vault infrastructure.

### 5.2 MongoDB — Phase 1 Collections

| Collection Name | Architecture Ingestion Strategy | Write Concern Parameter | Lifecycle TTL Policy |
|---|---|---|---|
| `auditLogs` | Append-only tracking database logs. Relational data mutations are intercepted via `AuditInterceptor` and pushed to this collection. Modifying or deleting documents is blocked at the database permission layer. | `{ w: 'majority', j: true }` | 7 Years Archive Policy |
| `aiEventsLogs` | Ingests and archives the raw JSON alert payloads received from the 12 AIEYE inference engines webhook channel for historical lookup and search. | `{ w: 1, j: false }` | 90 Days Auto-Expiry TTL |

**auditLogs Append-Only Enforcement Rules:**
- The MongoDB security group profile explicitly blocks the following operations for application workers: `update`, `delete`, `drop`, and `replaceOne`.
- The NestJS database repository modules do not expose any update or delete interfaces for this collection. Fire-and-forget logs are classified as a critical security bug.

### 5.3 Redis Key-Space & Event Bus Partitioning (Phase 1)

All real-time keys, micro event bus channels, and caches must enforce strict tenant partitioning via composite namespaces to prevent cross-tenant information leakage.

Core State Caches
cust-{customer_id}:usr-{user_id}:session:{sessionId}              ➔ JSON    TTL: 28800s (8h)
cust-{customer_id}:jwt:blacklist:{sessionId}                       ➔ "1"     TTL: Volatile Token Window
cust-{customer_id}:site-{site_id}:cam:status:{camera_id}          ➔ JSON    TTL: 120s
cust-{customer_id}:site-{site_id}:alert:storage:{tier}            ➔ "1"     TTL: 300s
cust-{customer_id}:stream:assignment:{site_id}:{camera_id}        ➔ STRING  TTL: None (Managed by StreamRouter)
rate:login:ip:{ipAddress}                                         ➔ INT     TTL: 60s

Asynchronous Micro Event Bus (Redis Streams)
vms:camera-status                                                 ➔ MAXLEN 5000, consumer-group: health-group
vms:recording-lifecycle                                           ➔ MAXLEN 20000, consumer-group: recording-group
vms:ai-event:{customer_id}:{site_id}                              ➔ MAXLEN 50000, consumer-group: ai-alerts-group

Real-time WebSocket Broadcaster Channels (Pub/Sub)
ws:camera:{customer_id}:{site_id}                                 ➔ Camera status modifications ➔ ws-broadcaster
ws:alarm:{customer_id}:{site_id}                                  ➔ Live AI alerts triggers ➔ ws-broadcaster
media:cmd:{customer_id}:{site_id}                                 ➔ Control Plane ➔ Media Core commands
edge:config:{customer_id}:{site_id}:{server_id}                   ➔ Control Plane ➔ Edge Agent configurations
### 5.4 MinIO Object Storage Layout

Multi-tenant data partitioning rules require that separate tenant assets remain strictly isolated within designated, encrypted S3 object paths.

| Bucket Identifier | Scope & Target Contents | Storage Performance Tier | Lifecycle Retention Policy |
|---|---|---|---|
| `vms-hot` | fMP4 continuous recording streams fragments | High-throughput NVMe SSD array | Automated transition to warm tier at 48 hours |
| `vms-warm` | Historical archive stream fragments | High-capacity enterprise HDD pool | Automated object deletion after 30 days |
| `vms-exports` | Watermarked, assembled MP4 evidence clips | Standard SSD pool | Automated object purging after 7 days |
| `hls-segments` | Transcoded real-time mobile fallback files | Volatile RAM disk / SSD pool | Object TTL 60 seconds (Auto-expire) |

**Object Path Naming Convention Constraints (Enforced Globally):**
- **Continuous Stream Fragments:** `/recordings/{customer_id}/{site_id}/{camera_id}/{YYYY-MM-DD}/{epoch_ms}.fmp4`
- **Assembled Evidence Clips:** `/exports/{customer_id}/{exportId}.mp4`
- **Real-time Mobile Fallback:** `/hls/{customer_id}/{site_id}/{camera_id}/live/{sequence}.ts`
- **AI Alert Frame Snapshots:** `/snapshots/{customer_id}/{site_id}/{camera_id}/{epoch_ms}.jpg`

---

## 6. Infrastructure & Deployment

### 6.1 Kubernetes Resource Quotas (Phase 1 — SaaS Validation Scale)

The shared B2B SaaS platform infrastructure is resource-optimized from Day 1 to comfortably handle an active validation workload target of **1,000 concurrent active video streams mapped across 2 distinct mock corporate tenants** running stably for 7 continuous days.

| Deployment Target Pod | Min Replicas | Max Replicas | CPU Allocation (Request/Limit) | Memory Allocation (Request/Limit) | Dedicated GPU Resources |
|---|---|---|---|---|---|
| `vms-api-gateway` | 2 | 10 | 250m / 1000m | 512Mi / 1Gi | None |
| `vms-event-workers` | 2 | 5 | 250m / 1000m | 512Mi / 1Gi | None |
| `vms-ws-broadcaster` | 2 | 5 | 100m / 500m | 256Mi / 512Mi | None |
| `vms-media-core` | 2 | 8 | 2000m / 4000m | 4Gi / 8Gi | 1× Dedicated NVIDIA L4 GPU |
| `postgres-primary` | 1 | 1 | 1000m / 2000m | 4Gi / 8Gi | None |
| `postgres-standby` | 1 | 1 | 500m / 1000m | 2Gi / 4Gi | None |
| `redis-cluster-node` | 6 | 6 | 250m / 500m | 1Gi / 2Gi | None |
| `mongodb-node` | 3 | 3 | 500m / 1000m | 2Gi / 4Gi | None |
| `minio-node` | 4 | 4 | 500m / 1000m | 1Gi / 2Gi | None |
| `vault-node` | 3 | 3 | 100m / 250m | 256Mi / 512Mi | None |

### 6.2 GitOps Deployment Pipeline

Developer Push ➔ git push feature/VMS-XXX
➔ GitHub Actions Workflow: Code Linting ➔ Strict Typechecking ➔ Jest Unit Test Engine
➔ Security Scans Stage: SAST Analysis (SonarQube) ➔ Dependency Vulnerability Check (Snyk/Trivy)
➔ Automated Architecture Schema Validation (Antigravity verification gate)
➔ Build Layer: Docker Cross-Compilation ➔ Ship Verified Images to GitHub Container Registry (GHCR)
➔ Pull Request Creation ➔ Requires 1 explicit review sign-off ➔ Squash Merge to develop branch
➔ Argo CD Deployment Controller: Automatically triggers update hook on develop branch changes
➔ Pulls helm value modifications ➔ Direct deployment onto staging cluster namespace
➔ Automated DAST Testing Loop: OWASP ZAP execution fires against the live staging cluster endpoints
➔ Release Gate: Requires 2 Senior approvals ➔ Final deploy tracking pushed straight to production cluster env


### 6.3 Helm Chart Structure

charts/
vms-umbrella/                                 # Centralized umbrella management stack
Chart.yaml, values.staging.yaml, values.prod.yaml
charts/
vms-api-gateway/                          # Multi-tenant API gateway endpoints chart
templates/: deployment.yaml, service.yaml, hpa.yaml, pdb.yaml, ingress.yaml, vault-agent-sidecar.yaml
vms-event-workers/                        # Isolated async stream event processing workers chart
templates/: deployment.yaml, service.yaml, hpa.yaml, custom-keda-scaler-stub.yaml
vms-ws-broadcaster/                       # Real-time WebSocket fan-out broadcaster chart
templates/: deployment.yaml, service.yaml (sessionAffinity: ClientIP)
vms-media-core/                           # Native C++ streaming node charts with GPU configurations
templates/: statefulset.yaml, service.yaml, node-selector-gpu.yaml


### 6.4 Vault Secret Paths (Phase 1 Core)

secret/data/vms/jwt-signing-key         ➔ Master identity JWT HMAC-SHA256 signature key parameters
secret/data/vms/postgres-credentials    ➔ Relational database root passwords and connection targets
secret/data/vms/redis-credentials       ➔ Cache system master access authorization AUTH tokens
secret/data/vms/mongodb-uri             ➔ Append-only transaction audit logs database strings
secret/data/vms/minio-credentials       ➔ Master S3 access identifiers and bucket properties keys
secret/data/vms/tenants/{customer_id}   ➔ Scoped licensing vectors and active entitlements slots mapping

PKI Engines Mounting Configuration
pki_int/issue/vms-internal              ➔ Distributes dynamic short-lived certificates for internal mTLS
pki_int/issue/vms-client                ➔ Houses the Intermediate CA Certificate bundle data for Sagar’s mobile SPKI hash pinning.
---


## 7. Non-Functional Requirements

### 7.1 Performance Benchmarks

| NFR Identifier | Explicit System Requirement | Target Bound Threshold | Performance Measurement Rule |
|---|---|---|---|
| **NFR-P01** | LAN Operator Canvas live-view latency | P95 ≤ 500ms glass-to-glass | WebGPU multi-tile rendering load test |
| **NFR-P02** | Mobile client fallback streaming latency | P95 ≤ 5s end-to-end | Flutter video player log metrics on 4G WAN |
| **NFR-P03** | Central API Gateway interaction latency | P95 ≤ 500ms standard operations | Prometheus request histogram metrics |
| **NFR-P04** | API Gateway structural latency under event load | P95 ≤ 500ms during event surge | Load tests passing 50k alerts into message bus |
| **NFR-P05** | Timeline playback scrub rendering latency | P95 ≤ 2s to paint target video frame | Asynchronous fMP4 slice retrieval query |
| **NFR-P06** | Hardware node failure event propagation | Latency ≤ 30s from drop to UI state shift | Automated heartbeat extraction interval |

### 7.2 Scalability (Phase 1 SaaS Ceilings)

- **NFR-S01 (Active Stream Ceiling):** System architecture is engineered to run a validation workload of 1,000 active concurrent camera streams distributed across 2 separate mock corporate tenants.
- **NFR-S04 (Asynchronous Processing Load):** NestJS event consumer worker instances must achieve a baseline throughput of **≥ 500 alert events per second** per pod on the `vms:ai-event:*` queues.
- **NFR-S05 (Storage Ingestion Speed):** Multi-tenant MinIO hot storage layout must maintain an uninterrupted write ingestion velocity of: `1000 cameras × 2 Mbps = 2.0 Gbps sustained bandwidth`.

### 7.3 Availability & Self-Healing Loops

- **NFR-A01 (Core System Up-time):** The multi-tenant hosted cluster ecosystem must maintain an overall availability metric of **≥ 99.0%** throughout the Sprint verification testing phases.
- **NFR-A03 (Automatic Database Promotion):** Patroni cluster monitoring routines must execute automatic failover transitions within a boundary of **≤ 30 seconds** on database node failures.
- **NFR-A05 (Media Core Recovery Loop):** The stream routing mesh must automatically isolate failed container nodes and redistribute streaming allocations across the remaining N+1 pool within **≤ 30 seconds**.
- **NFR-A06 (On-Premises Outage Caching):** The Edge Appliance agent loops must guarantee zero data capture loss during complete WAN interface failures, diverting video data to local ANR partitions instantly.

### 7.4 Data Reliability & Durability

- **NFR-R01 (Audit Trail Protection):** Operational log indexing requires a MongoDB write concern configuration set to `majority + journal`, ensuring zero logging data drops on infrastructure nodes loss.
- **NFR-R02 (Media Assets Redundancy):** Continuous recording fragments require erasure-coded object cluster definitions across a minimum of 4 nodes, preventing video segment destruction on single hardware node faults.

---

## 8. Security Requirements

### 8.1 Network & Transport Layer Protections

| Security Requirement | Implementation Rule | Operational Target Engine |
|---|---|---|
| **SEC-T01** | Public edge interaction security | Enforce TLS 1.3 encryption constraints exclusively. Legacy TLS 1.2 handshakes are dropped at the ingress layer. |
| **SEC-T02** | Cluster service communication isolation | Compulsory mutual TLS (mTLS) configuration between all transactional backend worker pods. |
| **SEC-T03** | Distributed appliance infrastructure security | On-premises Edge Agent connection streams encrypt parameters safely over a secure TLS 1.3 WAN tunnel. |
| **SEC-T04** | Mobile application transport validation | Sagar’s Flutter engine extracts the base64-encoded SPKI SHA-256 public key hash of our Vault Intermediate CA; leaf-level pinning is banned. |
| **SEC-T05** | Browser header protection | Enforce HTTP Strict Transport Security: `max-age=31536000; includeSubDomains`. |

### 8.2 Authentication, Cryptography & Token Protection

- **SEC-A01 (Identity Encryption):** Relational user directory credentials encryption requires standard `bcrypt` hashing with a minimum work cost factor parameters set to **`>= 12`**.
- **SEC-A03 (Volatile Token Rule):** Public web clients must contain active identity JWT variables strictly within short-lived application memory objects (Zustand context state). Caching authentication tokens inside persistent browser local or session targets (`localStorage`/`sessionStorage`) is strictly prohibited.
- **SEC-A05 (Refresh Token Segregation):** User refresh token states are handled via a 64-byte randomized string hash verified inside PostgreSQL tables, delivered to web browsers via a protected `HttpOnly Secure SameSite=Strict` cookie mechanism. On mobile clients, persistence rules are bound to secure storage layers backed by native hardware cryptoprocessors.
- **SEC-A07 (Brute-force Ingress Interception):** Public identity endpoints enforce a Redis sliding-window filter mechanism: 5 consecutive validation failures within a 60-second window trigger an immediate HTTP 429 rate-limiting block.
- **SEC-A09 (TOTP Protection):** Multi-factor enrollment parameters are handled via RFC 6238 compliance checking hooks, and secrets are encrypted via Vault references before being committed to PostgreSQL data tables.

### 8.3 Fine-Grained SaaS Authorization

- **SEC-Z01 (Default-Deny Gateway Policy):** Every single microservice controller route definition must explicitly announce its security intercept properties via `@Roles()` or `@Public()` parameters. All unmapped or missing endpoints match an implicit default-deny layout returning an HTTP 403 Forbidden intercept to all callers.
- **SEC-Z03 (Data Domain Isolation Constraint):** Non-admin system users are bound to a strict tenant-isolation guard rail. Every camera lookup, playback scrub, alarm verification, or workspace layout pull automatically intersects database queries with the token parameters extracted from the verified JWT:
  ```sql
  WHERE customer_id = token.customer_id AND site_id = token.site_id
````

- **SEC-Z04 (Untrusted Source Isolation):** Core backend services are forbidden from parsing tenancy identifiers, user roles, or context boundaries from user request bodies or public query arguments; data verification is derived strictly from the validated JWT signature.

### 8.4 Data Security & Regulatory Compliance

- **SEC-D01 (Zero Cleartext Secret footprint):** Application configurations files, committed code bases, and environment variables files (.env) are forbidden from holding cleartext passwords, tokens, or security keys. Secret keys are injected dynamically into volatile execution instances at system launch via HashiCorp Vault agent sidecars.
- **SEC-D05 (Log Sanitization Rule):** Transactional payload elements, user password strings, and active security signatures must be completely sanitized and rewritten out as [REDACTED] variables before data blocks hit the immutable MongoDB audit ledger.

SEC-D06 (Data Residency Compliance): To guarantee full compliance with the Digital Personal Data Protection (DPDP) Act 2023 directives, all relational records, log tables, media fragment buckets, and identity indices remain strictly bound to infrastructure pools hosted physically within the territory of India; cross-border data replication mirrors are completely banned.

### 8.5 CI/CD Security Gates (Every Build)

| Gate                 | Tool                   | Blocking Threshold                       |
| -------------------- | ---------------------- | ---------------------------------------- |
| SAST                 | SonarQube              | Critical findings block merge            |
| SCA (dependencies)   | Trivy                  | Critical CVEs block merge                |
| DAST (staging)       | OWASP ZAP              | High findings block release branch       |
| Secret scanning      | GitHub secret scanning | Any detected secret blocks merge         |
| Container image scan | Trivy                  | Critical CVEs in base image block deploy |

---

## 9. Integration Contracts (Cross-Owner)

### 9.1 Shubham + Saurabh (Media Core) ➔ Vivek (Control Plane)

All core event-driven infrastructure notifications from the streaming cluster must pass through the asynchronous Redis micro event bus. C++ Media Core processes are strictly prohibited from executing synchronous HTTP API calls targeting the NestJS platform.

#### `vms:camera-status` Stream Contract Payload:

```typescript
// Published by: Media Core (C++) — Jointly owned by Shubham + Saurabh
// Consumed by:  vms-event-workers (NestJS health-consumer-group)
{
  customer_id: string, // UUID Master Tenant Token
  site_id:     string, // UUID Dynamic Site Identification
  camera_id:   string, // UUID Specific Camera Identifier
  status:      'CONNECTED' | 'DISCONNECTED' | 'STREAMING_ERROR',
  fps:         string, // Ingest frame rate float serialized as string
  bitrateKbps: string, // Ingest throughput integer serialized as string
  packetLoss:  string, // Network packet loss float serialized as string
  timestamp:   string  // ISO 8601 strict format
}
vms:recording-lifecycle Stream Contract Payload:
TypeScript
// Published by: Media Core (C++) on segment closure after MinIO HOT S3 push
// Consumed by:  vms-event-workers (NestJS recording-index-group)
{
  customer_id: string, // UUID Master Tenant Token
  site_id:     string, // UUID Dynamic Site Identification
  camera_id:   string, // UUID Specific Camera Identifier
  segment_id:  string, // UUID segment tag generated by Media Core
  filePath:    string, // Canonical MinIO S3 object path key
  fileSize:    string, // Segment capacity metric in bytes as a string
  state:       'CLOSED', // Only closed, verified fragments are processed
  timestamp:   string  // ISO 8601 execution time
}
media:cmd:{customer_id}:{site_id} Pub/Sub Channel Payload:
TypeScript
// Published by: NestJS Control Plane (api-gateway / event-workers)
// Subscribed by: Media Core (Internal C++ hiredis subscriber loop)
{
  action:    'START_RECORDING' | 'STOP_RECORDING' | 'ASSIGN_CAMERA' | 'RELEASE_CAMERA',
  customer_id: string,
  site_id:     string,
  camera_id:   string,
  params:      Record<string, unknown> // Channel configuration credentials, RTSP tokens
}
9.2 Vivek (Control Plane) ➔ Shubham + Saurabh (Media Core)
GET /api/v5/recordings/stream (Internal Microservice Verification Endpoint)
Invocation Context: Called internally by Media Core gateways via highly optimized gRPC paths before delivering streaming signatures to client devices.
MD

Request Payload Interface:

TypeScript
  interface MediaStreamVerifyRequest {
    customer_id: string;
    site_id: string;
    camera_id: string;
  }
Response Payload Interface:

TypeScript
  interface MediaStreamVerifyResponse {
    isAuthorized: boolean;
    entitlementsActive: boolean;
    hlsUrl: string; // Temporarily signed HLS stream reference token
  }
9.3 Shubham + Saurabh (Edge Agent Appliance) ➔ Vivek (Control Plane)
POST /api/v5/cameras/discovered — [INTERNAL PROTOCOL — mTLS gRPC Enforced]

MD

Description: Encrypted pipeline used by localized hardware appliances running C++ loops to dump auto-discovered devices straight into the control cluster.
MD

Request Body Interface:

TypeScript
  interface DiscoveredCameraDto {
    customer_id: string; // Extracted dynamically from the appliance certificate profile
    siteId: string;
    ipAddress: string;
    onvifProfile: 'S' | 'G' | 'T' | 'M';
    rtspUrl: string;
    xaddrs: string[];
    uuid: string; // Unique ONVIF hardware device token
    manufacturer: string;
    model: string;
  }
Response Body Interface: { registered: boolean, camera_id: string }


MD

9.4 Vivek (Control Plane) ➔ Sagar (Solo Mobile Track Lead)
API Micro-Contracts consumed by Cross-Platform Flutter Clients
:
Public HTTP Endpoint	Protocol Method
Mobile App Execution Context
MD

/api/v5/auth/login	POST
Processes operator login credentials and TOTP entries.
MD

/api/v5/auth/refresh	POST
Automatic access token rotation locked behind the RefreshLock semaphore.
MD

/api/v5/auth/logout	POST
Explicitly kills session states, wiping hardware memory buckets.
MD

/api/v5/cameras	GET
Populates the mobile sidebar camera navigation list (Strictly tenant-scoped).
MD
+ 1

/api/v5/recordings/stream	GET
Fetches temporary signed live HLS paths to feed native Texture view tiles.
MD

Canonical Mobile HLS Endpoint URI Scheme:
https://media.serviceprovider.com/hls/{customer_id}/{site_id}/{camera_id}/live.m3u8?token={signed_signature_string}
MD
+ 2

9.5 Vivek (Vault PKI Core) ➔ Sagar (Mobile SPKI Pinning Verification)
Deliverable Target: Secure handoff of the base64-encoded SHA-256 Subject Public Key Info (SPKI) cryptographic hash string derived from our central HashiCorp Vault Intermediate CA Certificate.
MD
+ 1

Sovereign Execution Dependency: Sagar's solo compilation track Task C.3.1 (Network security handshake layer) remains completely BLOCKED until this hash string is delivered and embedded within the native initialization configuration blocks.
MD
+ 1

10. Testing Requirements Matrix
10.1 Unit Testing Coverage Commit Gates
Microservice Component Layer	Verification Framework	Minimum Coverage Target	Sovereign Code Component Owner
NestJS Business Logic & Controllers
Jest + @nestjs/testing


MD

>= 60% Baseline
MD

Vivek
MD
+ 1

Gateway Security Interceptors & Guards	Jest Mocking suites
100% Absolute
MD

Vivek
MD
+ 1

Flutter Keystore Cryptoprocessors	Flutter Test Suite
>= 80% Verification
MD

Sagar (Solo Mobile Lead)
MD
+ 1

Flutter Hardware DecoderPool	Semaphores execution test	100% (Must pass before UI builds)
Sagar (Solo Mobile Lead)
MD
+ 1

C++ Stream Router Mesh
Google Test (GTest)
MD

>= 70% Verification
MD

Shubham + Saurabh
MD
+ 1

C++ ANR local storage loops
Google Test (GTest)
MD

>= 70% Verification
MD

Shubham + Saurabh
MD
+ 1

10.2 SaaS Multi-Tenant Integration Testing
Multi-Tenant Data Leakage Validation Suite (Sovereign Ownership: Vivek)
Automated backend regression scripts must instantiate multiple concurrent client identity testing cycles using minimum 2 distinct mock tenant profiles (customer_id_01 and customer_id_02) executing cross-domain mutations. Any cross-contamination, missing customer_id indexes filters, leakage traces, or un-namespaced record exposure will trigger an immediate, fatal pipeline rejection block.
MD
+ 3

10.3 Comprehensive Security Verification
SEC-TEST-01 (Auth Bypass Block): E2E testing framework fires missing token requests at every protected gateway route module; check requires a strict 100% yield of HTTP 401 Unauthorized.
MD

SEC-TEST-02 (RBAC Validation): Viewers attempting to trigger operator commands, or operators passing admin tasks automatically receive a strict HTTP 403 Forbidden validation block.

SEC-TEST-03 (Token Storage Inspection): Headless browser automation testing verifies DOM nodes and client memories to guarantee zero JWT trace parameters exist within browser local or session targets (localStorage/sessionStorage).
MD
+ 1

10.4 Load and Stress Testing Sizing Thresholds
The entire system layer is load-tested under a standardized SaaS validation workload target:

SaaS Streaming Benchmark: 1,000 concurrent mock camera streams distributed across 2 distinct mock corporate tenants must process fragments securely into MinIO HOT storage buckets for 24 continuous hours without generating a single recording gap.
MD
+ 1

Event Bus Burst Handling: NestJS event workers must maintain an processing velocity of >= 500 alert events per second per pod under a simulated peak alert payload injection block of 50,000 continuous webhook notifications.
MD
+ 1

11. CI/CD & DevOps Requirements
11.1 Branch Protection Rules Layout
main Branch (Production Baseline):
  - Requires 2 explicit Senior Developer code review sign-off approvals.
  - Requires all automated status check gates to return green.
  - Requires testing branch to match complete up-to-date alignment with target HEAD.
  - Force pushes and deletions are permanently blocked.

develop Branch (Integration Core):
  - Requires 1 explicit review approval sign-off before merge activation.
  - Requires green status check metrics across all static analysis frameworks.
  - Squash and merge execution strategy mandatory to ensure a clean commit log layout.

11.2 Required Automated CI Status Check Gates
✓ lint-and-typecheck        ➔ Rejects silent 'any' types, checks strict TypeScript parameters.
✓ unit-tests                ➔ Verifies NestJS, GTest, and Dart test expectations match baseline coverages.
✓ sub-agent-schema          ➔ Validates that every database query enforces root-level 'customer_id' filtering.
✓ sast-sonarqube            ➔ Static application security testing; critical or high vulnerabilities fail builds.
✓ sca-trivy                 ➔ Analyzes external library dependencies, locking builds on Critical CVEs.

11.3 Docker Image Tagging & Compilation Conventions

Registry Target: GitHub Container Registry (ghcr.io/engine-org/vms/)

Image Namespaces: vms/api-gateway, vms/event-workers, vms/ws-broadcaster, vms/media-core, vms/edge-agent

Tagging Discipline: Every built layer maps an exact Git commit SHA parameter hash; the utilization of the loose :latest string tag is strictly prohibited across all pipelines.

12. Observability Requirements
12.1 Core Metrics Collections (Prometheus Scrape)
NestJS Multi-Tenant Gateway Metrics:
http_request_duration_ms{customer_id, route, method, status} ➔ Histogram analyzing latency thresholds.

active_websocket_connections{customer_id, site_id} ➔ Gauge measuring live operator connection density.

redis_stream_consumer_lag{stream, group} ➔ Gauge monitoring event loop ingestion efficiency.

Media Engine Telemetry

:
media_active_streams_total{customer_id, site_id} ➔ Active incoming video streams count.

media_segment_upload_duration_ms{customer_id} ➔ Ingestion latency monitoring MinIO object push speeds.
MD
+ 1

12.2 Mandated Grafana Monitoring Interfaces (Sprint 1 Bootstrapping)

Dashboard 1 (SaaS Multi-Tenant Overview): Real-time display monitoring active corporate tenants tracking, cross-tenant data isolation verification status, recording gaps anomalies, and central API error frequencies.
MD
+ 1

Dashboard 2 (Media core Performance): Ingestion throughput tracking metrics, GPU node acceleration temperatures, and HLS fragmentation latency performance.

Dashboard 3 (Edge Appliance Health): Multi-site hardware analytics map tracking individual edge gateway loops heartbeat, localized ANR storage exhaustion parameters, and WAN line states.

13. Phase 1 Technical Constraints (HARD ARCHITECTURAL PILLARS)
C01: NestJS core engine components must run as 3 standalone Kubernetes deployment layers. Shared runtime configurations are banned.

C02: Database lookup commands and streaming parameters routing queries must incorporate the root composite multi-tenant namespace tuple: (customer_id, site_id, camera_id). Bare camera queries lacking tenant tracking filters trigger an immediate compilation block.

C03: Recording output constraints require strict standardization on ISO BMFF fragmented MP4 (fMP4) file segmenting structures. Unfragmented file wraps are forbidden.

C04: Multi-Tenant Data Scoping Isolation: Database user creation mechanisms must enforce tenant-scoped email validation rules: UNIQUE(customer_id, email). Global uniqueness rules are banned to mitigate cross-tenant enumeration risk vectors.

C05: Site Management Autonomy: Database rows must preserve the 'site_type' variable as an open string element (VARCHAR(100)) without applying strict check constraints lists or enums. Custom portal configuration validation loops are assigned entirely to application logic modules.

C06: Cryptographic MFA Shield: Transactional identity tables are forbidden from saving cleartext multifactor generation tokens. System schema models must exclusively declare an mfa_secret_ref pointer targeting external HashiCorp Vault infrastructures.

C07: Volatile Web Security: Web client applications are completely banned from caching authentication tokens inside persistent browser modules (localStorage/sessionStorage). JWT assets reside strictly within local scoped volatile runtime memory.

C08: Mobile Cryptographic Containment: Cross-platform Flutter development code loops must isolate session refresh token targets securely within hardware cryptoprocessors via native platform channel bridges.


### 14. Technical Debt Register

debt ID Token	Detailed Technical Debt Description	Scope	Resolution Gate Target	Assigned Code Owner
TDR-01
Horizontal pod autoscaling configurations for async event workers rely on CPU metrics thresholds; event-lag metrics processing deferred.

Phase 1

Phase 2, Sprint 7

Vivek (SaaS Control Plane)

TDR-03
Local edge appliance WAN line optimization routines rely on a hard-coded 80 Mbps maximum ceiling mechanism; real-time dynamic band measurements deferred.

Phase 1

Phase 2, Sprint 8

Shubham + Saurabh (Media Core)

TDR-05	Storage of tenant entitlement structures handles asset mappings inside relational PostgreSQL rows; automated Mongo AI model matrices syncing deferred.	Phase 1	Sprint 1 Week 2
Vivek (SaaS Control Plane)


Document Author & Owner: Vivek Ranjan (SaaS Control Plane & Architecture Lead)
Review Cadence Policy: End of each Sprint cycle iteration.
```
