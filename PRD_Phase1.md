# Product Requirements Document (PRD)

## Enterprise Video Management System — Phase 1 SaaS Multi-Tenant Edition

| Field            | Value                                        |
| ---------------- | -------------------------------------------- |
| Document Version | 1.1 (Revised SaaS Multi-Tenant Architecture) |
| Status           | Baseline — Phase 1 Locked                    |
| Date             | June 2026                                    |
| Product Owner    | Vivek Ranjan                                 |
| Classification   | Internal / Confidential                      |
| SRS Reference    | v5.1 (Shared B2B SaaS Edition)               |
| Delivery Target  | End of Month 3 (Sprint 6)                    |

---

## Table of Contents

1. Executive Summary
2. Product Vision & Strategic Context
3. User Personas & Characteristics
4. Phase Roadmap (4-Phase Overview)
5. Phase 1 — Feature Requirements
6. User Stories & Acceptance Criteria
7. Out of Scope (Phase 1)
8. Success Metrics & KPIs
9. Assumptions & Dependencies
10. Risks & Mitigations
11. Open Questions

---

## 1. Executive Summary

The Enterprise Video Management System (VMS) is a highly available, centralized Shared-Control-Plane B2B Multi-Tenant SaaS platform designed for city-scale deployment, corporate enterprise tracking, and mission-critical public safety infrastructure across India.

Phase 1 delivers the Standard SaaS Edition — a production-deployable baseline hosted entirely on centralized cloud infrastructure. It replaces the legacy single-station model with a scalable multi-tenant environment optimized to process a validation workload target of 1,000 concurrent streaming camera nodes mapped across 2 distinct mock corporate tenants running stably for 7 continuous days. It establishes the core functional primitives — secure multi-tenant identity directories, dynamic workspace canvas mapping, continuous cloud media fragment recording, timeline scrubbing archives, watermarked clip exports, and the critical async interception loop for 12 primary AIEYE inference alert models.

Phase 1 represents our foundational commercial baseline. It must achieve demonstrable stability, absolute row-level data isolation, and low-latency interface responses usable by non-technical security operators. It is not a proof-of-concept; it ships officially as v1.1 SaaS Baseline.

---

## 2. Product Vision & Strategic Context

### 2.1 Vision Statement

Provide corporate enterprise clients, site administrators, and public safety agencies a single, unified, cost-effective interface to monitor, record, investigate, and respond to events across their entire camera network — from localized dynamic workspaces to distributed regional nodes — with zero compromise on evidence isolation, cross-tenant data boundaries, data sovereignty, or operator experience.

### 2.2 Strategic Context

**Problem being solved:**

- Legacy infrastructure nodes manage CCTV cameras via vendor-locked on-premises NVR/DVR systems with zero centralized monitoring, no structural data sharding, no secure multi-tenant isolation boundaries, and no court-grade evidence export pipelines.
- Existing standalone frameworks are highly prone to physical single-point failures resulting in irreversible recording loss.
- Legacy system data transformations and migrations are manual and high-overhead, causing major operational disruptions during infrastructure upgrades.

**Market Position & Compliance Edge:**

- **India-First Engineering Core:** Strict compliance with the Digital Personal Data Protection (DPDP) Act 2023 directives, ensuring all relational data tables, cryptographic tokens, log entries, and media fragment segments remain housed strictly within the territory of India; cross-border replication mirrors are completely banned.
- **Historical Data Ingestion Pipeline:** Target PostgreSQL schemas are engineered upfront to seamlessly map and ingest legacy configurations data loops. When current AIEYE subscribers upgrade their accounts to full VMS enterprise capabilities (Multi-tile live grids, continuous recording, timeline playback, clip exports), their historical user profiles remain active and uninterrupted on our centralized hosted instance.
- **Procurement Advantage:** Full source-code auditability for government procurement tracks and competitive tender evaluation advantages over traditional monolithic competitors.

### 2.3 Deployment Context — Phase 1 SaaS Validation Target

```
Centralized Cloud Platform Cluster (Hosted SaaS Kubernetes Mesh)
├── ns: ingress        → NGINX/Traefik, TLS 1.3 Termination
├── ns: control-plane  → Multi-Tenant NestJS API Gateways (Vivek Ownership)
│                         NestJS Event Consumer Workers (Isolated Stream Processors)
│                         NestJS WebSocket Broadcaster (Sticky Sessions Routing)
├── ns: media          → C++ Cloud Media Core streaming nodes (Shubham + Saurabh Co-Ownership)
├── ns: ai-ingress     → AIEYE Webhook Receiver Ingestion Gateway
├── ns: data           → PostgreSQL 16 HA (Patroni Cluster Sharded via customer_id)
│                         Redis 7 Cluster Event Bus + MongoDB 7 PSS Audit Pools
└── ns: storage        → MinIO Multi-Tenant Partitioned S3 Buckets Layout

Distributed Edge Infrastructure (On-Premises per Site)
└── Hardened Debian 12 Edge Appliance Agent Loop (Shubham + Saurabh Co-Ownership)
    ├── ONVIF WS-Discovery engine + Local PTZ command execution bridge
    └── 512 GB local ANR storage partition cache (WAN outage protection)
```

---

## 3. User Personas & Characteristics

### 3.1 Persona 1 — Control-Room Operator (Primary)

| Attribute         | Detail                                                                                  |
| ----------------- | --------------------------------------------------------------------------------------- |
| Role              | Monitors live multi-tile camera grids, reviews telemetry, acknowledges alerts           |
| Tenancy Scope     | Scoped strictly to the specific site allocations embedded inside the validated JWT      |
| Technical skill   | Low — Trained on VMS platform interactions, consumer-grade desktop user                 |
| Language          | Hindi primary; English secondary                                                        |
| Primary interface | Web Client Portal layout / Electron Matrix Canvas via WebGPU canvas loop                |
| Working pattern   | 8-hour shifts, 3 shifts/day, 24×7 high-alert operational cycles                         |
| Critical need     | View any namespaced camera feed in real time with an execution speed under 500ms on LAN |

**Phase 1 SaaS Jobs-To-Be-Done:**

- Access authorized camera feeds without exposure to cross-tenant data lines.
- Switch between 1, 4, 8, or 16 multi-tile layout blocks instantly without page reloads.
- Play back footage from the last 30 days using a highly responsive, color-coded timeline grid.
- Export watermarked evidence clips securely, automatically triggering append-only transaction logging.
- Identify real-time camera connectivity dropouts instantly via high-visibility dashboard warning overlays.

### 3.2 Persona 2 — Tenant Administrator (Secondary)

| Attribute         | Detail                                                                          |
| ----------------- | ------------------------------------------------------------------------------- |
| Role              | Manages local users, provisions devices, configures dynamic recording schedules |
| Technical skill   | Moderate — Familiar with IP addressing, networking, camera hardware management  |
| Primary interface | Central Portal UI (Administration Workspace)                                    |
| Critical need     | Onboard new cameras and configure flexible custom site fields on the fly        |

**Phase 1 SaaS Jobs-To-Be-Done:**

- Add physical camera channels via ONVIF auto-discovery subnets or manual text parameter entry.
- Type custom, unrestricted alphanumeric site definitions straight into the portal form layout (VARCHAR 100 data target with zero database-level hard enums or CHECK lists).
- Provision sub-operator accounts with tenant-scoped unique index constraints (`UNIQUE(customer_id, email)`) to eliminate multi-tenant account collision bugs.
- Monitor live storage hot/warm tier utilization rates and define retention policies.

### 3.3 Persona 3 — Field Officer (Mobile Track)

| Attribute           | Detail                                                                                                                                                                           |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Role                | Surveillance monitoring on the move, remote situational awareness from the field                                                                                                 |
| Technical skill     | Low — Standard smartphone consumer                                                                                                                                               |
| Primary interface   | Solo Cross-Platform Flutter Mobile Application (Sagar Solo Ownership)                                                                                                            |
| Critical need       | View secure live camera video feeds on Android or iOS hardware without complex technical setup.                                                                                  |
| Phase 1 Constraints | Phase 1 Mobile Scope Gate: Standard user authentication, session validation, and adaptive HLS live view streaming only. Zero WebRTC/ICE or dynamic PTZ actions in Phase 1 build. |

### 3.4 Persona 4 — Auditor / Compliance Officer

| Attribute         | Detail                                                                                                                                                              |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Role              | Inspects log files, verifies evidence chain-of-custody tracking data                                                                                                |
| Technical skill   | Moderate — Familiar with compliance tracking and regulatory frameworks                                                                                              |
| Primary interface | Web Portal UI (System Status + Audit Export Pane)                                                                                                                   |
| Phase 1 Need      | Export immutable audit records as structured CSV files to enforce regulatory compliance, verifying that 100% of state-mutating operations are permanently recorded. |

---

## 4. Phase Roadmap (4-Phase Multi-Tenant Overview)

| Phase Milestone       | Target Camera Scale                               | Core Architectural Unlock Elements                                                                                                                                                    | Phase Release      |
| --------------------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ |
| **Phase 1** ← Current | **1,000 Validation Scale / 50k Global Fleet Cap** | Shared B2B SaaS architecture baseline, Patroni database partitioning keys, dynamic open site layout models, and the **AIEYE 12-Models async alert ingestion loop** via Redis Streams. | v1.1 SaaS Baseline |
| Phase 2               | 2,000 Core Cluster Nodes                          | Advanced relational RBAC authorization enforcement tables, multi-site active routing tables, and mobile push notification integrations.                                               | v2.0 Mid Scope     |
| Phase 3               | 5,000 Large Scale Mesh                            | OpenSearch cluster analytical investigation indexing, full-text search pipelines, and Electron WebGPU Operator Console deployment.                                                    | v3.0 Advanced      |
| Phase 4               | 50,000 Production Tier                            | Full cluster disaster recovery warm-standby promotion testing, transport layer cryptographic hardening, and Common Criteria validation.                                               | GA Production      |

---

## 5. Phase 1 — Feature Requirements (SaaS Revision)

### 5.1 F01 — Camera Integration & Discovered Asset Ingestion

**What it does:** Discovers, registers, and maps IP cameras using strict multi-tenant composite primary lookup indexes: `(customer_id, site_id, camera_id)`.

**Business value:** Administrators onboard cameras directly without vendor support or technical bottlenecking. Any ONVIF-compliant camera from any manufacturer works out of the box in a secure tenant-isolated environment.

**Requirements:**

- Auto-discover ONVIF profiles S, G, T, and M devices using localized Edge Agent 60-second scanning loops executing subnets fetched from Vault.
- Discovered devices must be pushed via secure mTLS gRPC communication pipelines directly to the NestJS Control Plane.
- Provide a manual onboarding form interface allowing administrators to input target IP addresses, RTSP URLs, and credentials blocks.
- Real-time network presence tracking: changes in camera connectivity must be captured and logged within an execution latency window of ≤ 30 seconds.
- Ensure deleting a camera configuration completely preserves the historical video index data blocks, setting the device reference to null to guard historical continuity.
- Grouping: Support organizing cameras into named local categories sharded by tenant context keys.

---

### 5.2 F02 — Live View Micro-Tile Video Engine

**What it does:** Displays real-time video feeds from one or more namespaced cameras in a browser, desktop console, or mobile app.

**Business value:** Core operational surveillance interface. Security operators must achieve situational awareness across active channels within seconds of launching the application canvas.

**Requirements:**

- The Web client portal handles 1, 4, 8, and 16 simultaneous stream layouts without page reloads.
- Layout transitions must pass through animated skeleton placeholders during buffering cycles to eliminate blank states.
- Hardware-backed canvas tracking: live video layout tiles on desktop consoles execute frames over high-performance WebGPU canvas rendering loops inside Electron containers to eliminate browser thread blocking.
- Global Multi-Tenant Namespace Guard: Every active media player instance must append the root tenant parameter prefix: `{customer_id}:{site_id}:{camera_id}` to all stream routing requests.
- Offline or errored stream tiles must display a clearly labeled error overlay stating the underlying connectivity defect instead of a blank black frame.
- Cross-platform Flutter mobile applications render adaptive HLS streaming files (`.m3u8`) inside 1×1 and 2×2 grid views, explicitly bounded by the client-side `DecoderPool` semaphore capping active hardware decoders at a hard limit of 4.
- Latency Bounds: LAN WebRTC streams P95 ≤ 500ms; TURN relayed streams P95 ≤ 1.5s; Mobile fallback HLS paths ≤ 5s.

---

### 5.3 F03 — PTZ Control

**What it does:** Allows operators to pan, tilt, and zoom motorized cameras from the web interface.

**Business value:** Operators can redirect a camera to follow a person or vehicle without leaving the control room.

**Requirements:**

- System detects PTZ capability via ONVIF at camera registration time.
- PTZ controls (directional arrows, zoom in/out, stop) appear only for PTZ-capable cameras.
- Controls are hidden from the DOM (not just CSS-hidden) for non-PTZ cameras.
- Play/stop video controls must be present on all tiles regardless of PTZ capability.
- Phase 1 mobile: PTZ UI buttons are rendered as stubs (visible but non-functional).

**Not in Phase 1:**

- PTZ presets management (Phase 2).
- Joystick hardware integration (Phase 3 — Operator Console).
- Mobile PTZ wired to camera (Phase 3).

---

### 5.4 F04 — Multi-Tenant Continuous Recording & Local ANR Outage Caching

**What it does:** Records camera video streams to centralized cloud object storage continuously, on schedule, or on manual override while ensuring edge resilience.

**Business value:** Guarantees absolute court-grade reviewability for all critical events. Multi-tenant data sharding rules ensure video data chunks are completely isolated at the storage layer.

**Requirements:**

- **fMP4 Standardization:** Cloud Media Core chunker modules process streaming frames through GStreamer graphs, converting continuous video data into fragmented, watermarked fMP4 (ISO BMFF) 15-minute segment clips pushed straight to MinIO HOT buckets.
- **Scheduled Recording Routing:** Support user-configured scheduling structures (Start time, end time, specific days of week, and timezone offsets) mapped per individual device profile.
- **Manual Recording Overrides:** Allow operators with valid privilege levels to manually invoke or terminate real-time recording tasks on any live camera tile.
- **Edge Advanced Network Replenishment (ANR):** If WAN line disconnection events trigger, the on-premises Edge Agent immediately isolates and caches fMP4 video data chunks inside local 512 GB storage partitions. Upon network line recovery, it initiates an off-peak delta sync pipeline capped at an 80 Mbps maximum throughput ceiling to protect production lines.
- **Nightly Retention Cleanup:** Relational scheduling engines track validity parameters; an automated background worker purges cold object storage items past their configured retention thresholds (default 30 days).

---

### 5.5 F05 — Timeline Playback Scrubbing Engine

**What it does:** Lets operators and investigators scrub through recorded multi-tenant footage with color-coded timeline navigation.

**Business value:** Critical post-event investigation tool. Authorized officers must quickly isolate, view, and analyze historical windows without crossing multi-tenant data lines.

**Requirements:**

- High-responsiveness timeline navigation: dragging or seeking across the interactive timeline bar must fetch and render the target video frame segment within a P95 latency ceiling of ≤ 2 seconds.
- Render color-coded indicator blocks mapping the underlying chunking profile (Continuous streams = Blue, Motion events = Orange, Scheduled timelines = Green).
- Exposes flexible interface filters allowing operators to search historical repositories by custom input site, target camera index, or time window.
- Storyboard generation: Hovering across the interactive timeline bar must fetch the nearest pre-generated frame thumbnail to optimize rapid search workflows.
- Snapshot: Allow operators to download a high-resolution JPEG capture directly from any active playback frame.
- Mobile Integration: Sagar's Flutter engine must provide timeline scrubbing, seek actions, and speed controls inside the mobile playback workspace in Phase 1.

---

### 5.6 F06 — Tamper-Evident Evidence Clip Export

**What it does:** Gathers scattered video segments, embedding secure identity metadata layers into a unified downloadable container.

**Business value:** Extracts authenticated, court-grade evidence clips for judicial case submission. Immutably tracks evidence chain-of-custody.

**Requirements:**

- Compiles a sequential array of fMP4 file chunks into a single authenticated MP4 clip wrapper.
- Mandates the application of hard burned-in text watermarks on every exported frame, compiling specific metadata attributes: Master System Token, Target Camera Hardware String, Operational Export Timestamp, and the Named Operator Identity.
- Emits time-bounded signed download paths (S3 pre-signed references) configured to expire automatically after exactly 24 hours.
- Every single export operation must instantly emit a tracking payload to write an entry to the immutable log ledger.

---

### 5.7 F07 — SaaS Identity Directory & Entitlements Feature Gating

**What it does:** Enforces role-based access control (RBAC), multi-factor isolation, and tenant-scoped user account management.

**Business value:** Guarantees absolute operational tracking. Ensures strict defense-in-depth where users are restricted to their designated functional domains and tenant spaces.

**Requirements:**

- Enforces strict tenant-scoped email resolution constraints via structural validation hooks: `UNIQUE(customer_id, email)`. Global database level email locks are completely banned to mitigate cross-tenant enumeration and denial-of-service exploits.
- Three immutable base system roles: Admin (Full configuration authority), Operator (Monitoring, recording controls, clip exports, health views), and Viewer (Live view and playback read-only access; all writes blocked via HTTP 403).
- **Vault Secret Protection:** The transactional identity schema completely removes raw `mfa_secret` text lines, replacing them with **`mfa_secret_ref VARCHAR(255)`**, which exclusively stores reference tracking strings mapping towards an external HashiCorp Vault cluster.
- Identity access tokens must be contained strictly within volatile application memory blocks (Zustand context state); caching authentication parameters inside persistent local or session web storage targets (`localStorage`/`sessionStorage`) is zero-tolerance banned.
- Deactivating a user profile must synchronously append the active token signature straight to the Redis session blacklist, killing active client sessions within ≤ 1 second.
- **Site-Scoped Visibility Guard rail:** Non-admin operators are dynamically restricted. Every data query automatically intersects requests with the site identifiers extracted from the validated JWT signature.

---

### 5.8 F08 — System Health Telemetry & Storage Tracking

**What it does:** Exposes real-time operational status updates across connected devices, cluster services, and storage arrays.

**Business value:** Enables site administrators to proactively intercept infrastructure failures before recording gaps introduce legal evidence risks.

**Requirements:**

- Ingests active operational metrics and pumps real-time state changes straight to dashboards over WebSocket channels without page reloads.
- Real-time network presence tracking: changes in camera connectivity must be captured and logged within an execution latency window of ≤ 30 seconds.
- Displays hot, warm, and archive storage tier allocation statistics using high-visibility visualization progress bars.
- Triggers high-priority alert banners inside active workspaces immediately when any storage tier passes an 80% capacity utilization threshold.
- Flag and alert on any configured recording channel that fails to instantiate continuous fragment creation within 5 minutes of its scheduled launch window.

---

### 5.9 F09 — Solo Mobile Ecosystem Implementation

**What it does:** Renders standard surveillance streaming operations inside a highly protected mobile client environment.

**Business value:** Provides senior officers and field teams secure mobile situational awareness without tying them to physical control room desktop terminals.

**Requirements:**

- **Sovereign Track Code Isolation:** Fully compiled from a single clean Flutter 3.x and Dart 3.x code repository, managed strictly under solo mobile developer execution boundaries.
- **Cryptographic Sandbox Isolation:** Invokes native platform channels to keep sensitive authentication tokens, signing elements, and access assets locked within hardware cryptoprocessors: Android Keystore preferences and iOS Secure Enclave Keychain services.
- **Absolute Certificate Pinning:** Enforces transport validation loop metrics within mobile network clients, executing Subject Public Key Info (SPKI) hash pinning against the base64 SHA-256 token of our Vault Intermediate CA; binding fingerprints to changing leaf nodes is banned.
- Incorporates a thread-safe token refresh mechanism (`RefreshLock`) built on a Dart `Completer` routine to safely block concurrent data hydration race conditions across active streaming grid canvas tiles.

---

### 5.10 F10 — AIEYE 12-Models Alert Ingestion Core

> **F10 Naming Clarification:** `project.md` Section 8 labels F10 as "System Encryption & Audits (mTLS, HashiCorp CA)". This PRD uses F10 to describe the **AIEYE alert ingestion feature** — a product-level capability. Both refer to **Vivek's ownership** only. The encryption/audit infrastructure (Vault PKI, mTLS, JWT signing, audit logs) is an always-on baseline that underpins ALL features and is not a standalone PRD feature — it is captured in project.md's architecture pillars. The product-visible feature delivered by Vivek's `vms-event-workers` is the AIEYE ingestion pipeline described below.

**What it does:** Intercepts external deep learning metadata notifications asynchronously, mapping event properties to tenant log collections.

**Business value:** Powers the ingestion core of the VMS control plane, allowing the system to act as a high-performance event receiver for legacy AI deployments without modifying underlying inference nodes.

**Requirements:**

- Ingests incoming real-time JSON alert webhook payloads emitted from the external AIEYE inference cluster nodes.
- Automatically serializes and routes incoming notifications asynchronously through highly optimized message bus queues partitioned dynamically via: **`vms:ai-event:{customer_id}:{site_id}`**.
- Maps alert payloads to the 12 primary analytical metadata filters verified from the core licensing matrix: `ANPR_WITH_SPEED`, `CAMERA_TAMPERING`, `CROWD_DETECTION`, `FACE_DETECTION`, `FALLEN_DETECTION`, `FIRE_SMOKE`, `INTRUSION`, `MISSING_OBJECT`, `PIPE_DETECTION`, `TAILGATING`.
- Every incoming transaction writes an immutable tracking record out to the MongoDB system log collection for historical audit lookup.

---

## 6. User Stories & Acceptance Criteria (SaaS Revision)

### 6.1 Authentication & Multi-Tenant Access

**US-001:** As a Multi-Tenant Operator, I want to authenticate via the SaaS login portal so I can safely interact with my company's namespaced camera fleet.

- **AC1:** Valid entries return a volatile in-memory token and inject an encrypted `HttpOnly Secure SameSite=Strict` cookie wrapper; zero trace variables hit `localStorage` or `sessionStorage`.
- **AC2:** Validation failures return generic HTTP 401 strings masking structural error fields to block brute-force directory enumeration.
- **AC3:** Incurring 5 consecutive authentication faults triggers an automatic 30-minute account lockout block.
- **AC4:** Successful entry mutations automatically emit log payloads to append a metadata log line to the append-only ledger.

**US-002:** As a Tenant Administrator, I want to provision an Operator account so an officer can log into our corporate site space.

- **AC1:** Accounts are generated under the tenant-scoped constraint rule (`UNIQUE(customer_id, email)`), completely eliminating cross-tenant collision blocks.
- **AC2:** Multifactor authentication assets are extracted as reference hashes (`mfa_secret_ref`), isolating raw keys away from relational database schemas.

### 6.2 Flexible Custom Sites Management

**US-003:** As a Tenant Administrator, I want to create custom site descriptions on our portal dashboard so I can freely map hardware configurations matching our physical deployment layouts.

- **AC1:** The user interface form provides an unrestricted alphanumeric input text field mapping directly to an open database string (`VARCHAR(100)`), completely free of rigid CHECK list bounds or database-level enums.
- **AC2:** Operators can dynamically assign and group variable counts of distinct camera profiles to these user-generated site definitions via interactive drag-and-drop dashboard panes without causing validation runtime exceptions.

### 6.3 Media Core Streaming & Playback

**US-004:** As a Control-Room Operator, I want to view live video feeds from 16 concurrent camera channels so I can maintain high-alert surveillance across our site space.

- **AC1:** Renders frames over high-performance WebGPU canvas rendering loops inside Electron containers to eliminate browser thread blocking under maximum tile layout load.
- **AC2:** Moving or re-arranging micro-tile components must automatically fall back to animated skeleton loaders during fragment buffering.

**US-005:** As an Investigator, I want to scrub through yesterday's footage from camera 17 to find the 3pm incident.

- **AC1:** Dragging scrubber to 3pm begins playback of that timestamp within 2 seconds.
- **AC2:** Hovering across the interactive timeline bar must fetch the nearest pre-generated frame thumbnail storyboard dynamically.

**US-006:** As an Operator, I want to control a PTZ camera so I can follow a suspect.

- **AC1:** PTZ controls visible only for cameras where ONVIF PTZ query returned positive.
- **AC2:** PTZ command reaches camera within 2 seconds of button press.
- **AC3:** PTZ controls absent from DOM (not hidden) for non-PTZ cameras.

---

## 7. Out of Scope — Phase 1 (SaaS Specification)

The following capabilities are explicitly deferred. Introducing code loops or logic for these elements during active Phase 1 sprints constitutes an automatic quality gate failure.

| Technical Capability / System Module                                                       | Deferred Milestone Target                                 |
| ------------------------------------------------------------------------------------------ | --------------------------------------------------------- |
| Deep learning machine learning inference model retraining loops                            | Deferred Permanently (AIEYE core runs as-is)              |
| Relational data table structural modifications (Rigid DB CHECK lists/enums on site fields) | Banned Permanently (Application layer handles validation) |
| Advanced relational RBAC authorization enforcement tables & multi-site routing             | Deferred to Phase 2 Mid Scope                             |
| Automated horizontal pod autoscaling based on Redis Stream consumer group lag (KEDA)       | Deferred to Phase 2 Mid Scope                             |
| OpenSearch cluster analytical indexing & full-text search investigation pipelines          | Deferred to Phase 3 Advanced Release                      |
| Native multi-monitor display controllers & Electron WebGPU Operator Console deployment     | Deferred to Phase 3 Advanced Release                      |
| Full cluster warm-standby disaster recovery promotion testing loops                        | Deferred to Phase 4 Enterprise Tender                     |
| Biometric hardware enrollment, SRTP transport enforcement, and OOBM integration            | Deferred to Phase 4 Enterprise Tender                     |

---

## 8. Success Metrics & KPIs (Phase 1 Exit Validation Gate)

### 8.1 Hard Architectural Quality Gates (Must Pass For Phase 2 Sign-off)

| Critical Metric Target      | Target Operational Boundary                                | Verification Audit Rule                                                                           |
| --------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| **Sustained Scale Load**    | **1,000 Concurrent Active Video Streams across 2 Tenants** | Must process data streams smoothly into object store fragments for 7 continuous days with 0 gaps. |
| **Multi-Tenant Leakage**    | **Zero Tolerance Boundary (Absolute Isolation)**           | Automated regression suite validates zero data cross-contamination or unauthorized row queries.   |
| **LAN View Latency**        | **P95 Ceiling ≤ 500ms Glass-to-Glass**                     | Synthetically verified via WebGPU multi-tile rendering load trackers.                             |
| **Mobile Fallback Latency** | **P95 Ceiling ≤ 5s End-to-End Transport**                  | Measured via Flutter adaptive streaming player profiles on real 4G WAN lines.                     |
| **Audit Log Completeness**  | **100% Comprehensive Coverage**                            | Automated suite ensures all mutations write entries to the append-only MongoDB schema.            |
| **Code Validation Green**   | **>= 60% NestJS Coverage / 0 Critical Flaws**              | Enforced via SonarQube static analysis, Trivy SCA, and Snyk container image scans.                |

### 8.2 Operator Experience Performance Targets

- **Live View Initialization:** Maximum time to render active video tiles post-login must not exceed 10 seconds.
- **Incident Retrieval Window:** Operators must successfully isolate any 60-minute historical recording block within a maximum 2-minute search window.
- **Assembled Clip Assembly:** Assembling and watermarking a 10-minute continuous evidence clip must complete in ≤ 5 minutes.

---

## 9. Assumptions & Dependencies

- **A01 (Orchestration Readiness):** Multi-tenant SaaS Kubernetes cluster nodes and ingress engines are fully provisioned before Sprint 1 initialization.
- **A02 (Object Storage Availability):** MinIO distributed multi-node erasure-coded storage arrays are configured and active from Day 1 to receive continuous stream payloads.
- **A03 (Mobile Handoff Link):** Cryptographic verification hash signatures (SPKI SHA-256 base64 strings) derived from our Vault Intermediate CA are delivered to Sagar before the end of Sprint 1 Week 1 to unblock mobile code compilation.
- **A04 (DPDP Regulatory Baseline):** Centralized synchronization clocks rely on stable local NTP servers to ensure absolute consistency across relational data rows, event streams, and evidence logs.

---

## 10. Risks & Mitigations Matrix

| Risk Identifier | Core Technical Threat Description                                                                                      | Probability | Impact | Assigned Strategic Mitigation Rule                                                                                                                            |
| --------------- | ---------------------------------------------------------------------------------------------------------------------- | ----------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **R01**         | Running complex multi-tenant query layers introduces libuv event loop blocks or backpressure surges.                   | Medium      | High   | **Enforce Pillar 4 Mandate:** Deploy NestJS as 3 standalone process-isolated Kubernetes containers from Day 1 to isolate gateway APIs away from workers.      |
| **R02**         | Lower-end or mid-range Android mobile devices encounter memory crashes during multi-tile rendering.                    | Medium      | Medium | **Sagar Solo Track Constraint:** The `DecoderPool` semaphore mapping must be fully validated to enforce a strict hardware decoding ceiling of 4 active items. |
| **R03**         | Complex structural TypeORM/Prisma migrations introduce development database lockups or multi-tenant entity collisions. | Low         | High   | Every developer works on an isolated local Docker Compose container instance; schemas are sharded cleanly via root-level identifiers.                         |

---

## 11. Open Questions

- **OQ-01 (Appliance Network Footprint):** Will the localized multi-tenant Edge Agent deployment utilize a completely isolated management VLAN or traverse the site’s primary production pipeline network switches?
- **OQ-02 (Mobile Device Footprint):** What is the exact minimum hardware cryptoprocessor threshold required on field officer mobile smartphones to support native Keystore/Secure Enclave configurations smoothly?
- **OQ-03 (DPDP Regulatory Directives):** Are cold-tier backup object storage archives required to maintain real-time compliance validation APIs for automated auditor query actions after the 30-day hot retention window passes?

---

_Document Owner: Vivek Ranjan (SaaS Control Plane & Architecture Lead)_
_Review Cadence Policy: End of each Sprint cycle iteration._
