# CLAUDE.md — Enterprise VMS — Master Agent Rules

> This file is read by ALL agents and sub-agents before any task initiation.
> Rules here are ABSOLUTE unless explicitly overridden by a higher-priority instruction in the same session.
> Non-compliance by any agent is flagged as a CRITICAL audit event breaking core system constraints.

---

## 1. Project Identity

- **Project:** Enterprise Video Management System (VMS)
- **Deployment Model:** Centralized Shared-Database Shared-Control-Plane B2B Multi-Tenant SaaS Platform
- **Scale Infrastructure:** 50,000-camera aggregate cluster federation target
- **SRS Version:** v5.1 (Revised Multi-Tenant Edition — FROZEN)
- **Standard Reference:** IEEE 830-1998

---

## 2. Team and Ownership Map

Three process-isolated engineering groups. No cross-group code ownership. No exceptions allowed.

---

### Group 1 — Core Control Plane & Client Ecosystem (Owner: Vivek)

Vivek owns the entire centralized multi-tenant backend engines and all heavy web/desktop client surfaces.

**Backend Engine & Multi-Tenant Databases:**

- NestJS API Gateway infrastructure (Isolated deployment containers for HTTP/WS Gateway, Stream Workers, Broadcasters)
- Auth Service, Dynamic Tenant Gating via Entitlements Matrix, JWT state, MFA Vault integration
- Patroni PostgreSQL 16 — Multi-tenant schema design, row-level sharding, and structural composite keys
- Redis Cluster — Multi-tenant alerting pipelines, active presence state tracking, Redis Streams orchestration
- MongoDB PSS — Append-only immutable audit loops, telemetry processing, AI detection metadata history
- HashiCorp Vault — Secret fetching backend, RSA-2048 Root/Intermediate CA PKI engine, `mfa_secret_ref` tracking
- OpenSearch — Multi-tenant search clustering and analytical investigation indexing (Phase 3)
- Core Central Services: Alarm Engine, Notification Routing, Incident Management, Billing/License Matrix

**Desktop & Web Client Frontends:**

- Vite React 18 + TypeScript SPA Portal Client — Dynamic site layout management interfaces
- Electron 28 Dedicated Operator Console — Multi-tile high-throughput video matrix grid via WebGPU canvas loop
- Linux Thin Client Multi-Monitor Video Wall controller modules

> Vivek = Me. I sovereignly own the entire central backend Control Plane AND all rich client applications.

---

### Group 2 — Media Engine & Edge Appliances (Co-Owners: Shubham + Saurabh)

Shubham and Saurabh jointly own the native streaming architecture, fragment processors, and localized edge devices.

- Native C++ Cloud Media Core streaming architecture — GStreamer ingest pipelines, transcoding graphs
- Continuous Cloud Recording engine — Assembling continuous fMP4 stream fragments safely inside MinIO storage
- WebRTC Gateway pipelines, HLS streaming generation layers, coturn fleet integrations
- Hardened C++ Edge Agent Appliance running on Debian 12 minimal
  - ONVIF auto-discovery protocol layer, local PTZ command routing loops
  - 512 GB local ANR storage partition management with asynchronous off-peak WAN upload scheduling
- Redis Streams publishers mapping internal system telemetry: `vms:camera-status`, `vms:recording-lifecycle`
- Ingesting and proxying raw video data frames securely to the hosted AI analytics webhook layer

---

### Group 3 — Solo Mobile Track (Owner: Sagar)

Sagar single-handedly owns the entire cross-platform Mobile Application codebase. No other member touches this repo.

- Single-codebase Flutter 3.x (Dart) repository — Android API 29+ and iOS 15+ compilation targets
- Native platform channels exposing cryptographic isolation components: Android Keystore and iOS Secure Enclave
- Hardware JWT isolation: Access tokens in volatile container memory only; Refresh tokens in native secure wrappers
- Public Key Pinning (SPKI) execution against our HashiCorp Vault Intermediate CA base64 SHA-256 hash token
- Global `RefreshLock` handling via Dart `Completer` to prevent concurrent token refresh race conditions
- Phase 1 Mobile Scope Gate: Standard user authentication, session verification, and HLS live view streaming only

---

### External — AI Analytics Layer (AIEYE Ingest Loop)

- The 12 active machine learning deep inference models running on AIEYE host nodes continue operating as-is.
- VMS Control Plane acts strictly as a high-performance event receiver intercepting webhook alerts payloads.
- Every incoming alert must be processed asynchronously through partitioned Redis Streams: **`vms:ai-event:{customer_id}:{site_id}`**.
- Vivek owns the background consumer workers; Shubham + Saurabh own the Media Core trigger compliance.

---

**Cross-Group Interface Implementation Rules:**

| From                             | To                    | Interface Layer Protocol                                           |
| -------------------------------- | --------------------- | ------------------------------------------------------------------ |
| Shubham + Saurabh (Media Engine) | Vivek (Control Plane) | Partitioned Redis Streams only — No synchronous request blockades  |
| Shubham + Saurabh (Media Engine) | Sagar (Solo Mobile)   | Centralized HLS `.m3u8` streaming endpoints execution              |
| Vivek (Control Plane)            | Sagar (Solo Mobile)   | Multi-tenant REST API requests Gateway `/api/v5/*` + WSS endpoints |
| AIEYE Inference Gateway          | Vivek (Event Workers) | Async JSON event webhook triggers dumped into Redis Streams queues |

---

## 3. Frozen Architecture Pillars (v5.1 — SaaS Core)

1. **Global Multi-Tenant Namespacing** — Every single transactional record, directory asset, index row, or event string must strictly bind to the composite schema layout: `{customer_id}:{site_id}:{camera_id}`. No bare references allowed.
2. **Active-Warm Standby DR** — Automatic Patroni database promotion loops ensuring RTO < 5 minutes and RPO < 30s same-city.
3. **Two-Tier Media Ingest with Edge Loopback** — UDP multicast direct capture on local LAN using Vault-rotated SRTP keys; Edge proxy subscribers routing archive segments to Cloud Media Core without double-streaming.
4. **NestJS Process Isolation Engine** — API Gateways run in fully independent operating containers and execution loops away from consumer background streams and notification workers to block system backpressure.
5. **Flexible Dynamic Site Mapping** — `site_type` must be configured as a relaxed `VARCHAR(100)` column with zero hard database CHECK lists or enums. Custom configurations form validations are delegated entirely to the application layer.
6. **Locality-Split Latency Targets** — LAN WebRTC streams P95 <= 500ms; TURN relayed streams P95 <= 1.5s; Mobile fallback HLS paths <= 5s.
7. **Centralized HA TURN Infrastructure** — 2 active coturn instances running behind a dedicated load balancer matching N+1 redundancy constraints.
8. **Secure Client Sandbox Containers** — Access tokens kept out of application local storage elements. Privilege control policies enforce default-deny routines via the centralized entitlements matrix.

---

## 4. Locked Technology Stack

```
Media Core Architecture:   C++ 17 + GStreamer 1.22 (Cloud native processing clusters)
Control Plane Engine:      Node.js 20 LTS + NestJS 10 (Deployment isolated containers from Day 1)
Web & Desktop Client:      React 18 + TS (Vite SPA) & Electron 28 + WebGPU Operator Workspace
Mobile Platform:           Flutter 3.x + Dart (Single codebase managed exclusively by Sagar)
Relational Infrastructure: High Availability PostgreSQL 16 running a Patroni Cluster core
Cache / Micro Event Bus:   Redis 7 Cluster Architecture (3 Masters + 3 Replicas layout)
Immutable Audits & Logs:   MongoDB 7 Replica Set (PSS deployment configuration mapping)
Object Storage Framework:  MinIO Core Cluster (Erasure-coded multi-node configuration)
Secrets Management System: HashiCorp Vault Cluster (Raft-backed storage engine deployment)
Orchestration:             Kubernetes 1.29+ + Docker + Helm + Argo CD
Observability:             Prometheus + Loki + Tempo + Grafana + Alertmanager
```

---

## 5. Data Store Discipline (HARD COMPLIANCE RULES)

| Data Classification | Canonical Store Target | Prohibited Data Allocation Landmines |
|---|---|---|
| Tenant profiles, users identity keys, metadata `sites` layouts, `cameras` tracking configurations, dynamic module entitlements matrix. | **PostgreSQL 16 Cluster** | Flat unpartitioned tables lacking `customer_id` hooks, loose unstructured JSONB permission blobs, raw text `mfa_secret` fields. |
| Dynamic session states, user presence cache tracking, JWT revocation tokens list, real-time alert pipelines. | **Redis Cluster** | Storing transactional long-term historical records. |
| Append-only security audit entries, historical telemetry metrics logs, AI metadata detections tracking history. | **MongoDB PSS** | Relational data configurations mapping, core auth routing tables. |
| Fragmented video files (fMP4), evidence packages, event trigger frames snapshots. | **MinIO S3 Buckets** | Application configurations files, raw textual database logs. |
| Cryptographic keys, Intermediate CA sign certificates, Vault tracking tokens, `mfa_secret_ref` strings. | **HashiCorp Vault** | Standard plaintext `.env` properties rows, standard Kubernetes config maps files. |

---

## 6. Delivery Phases & Validation Sizing targets

**STRICT RULE: Never commit code loops or logic for Phase N+1 during active Phase N sprints.**

| Phase Milestone | Workload Scaling Ceiling | Authorized Sprint 1 Focus Core |
|---|---|---|
| **Phase 1 — Standard Standard SaaS Release** | **1,000 Concurrent Active Streams across 2 Mock Tenants** | Tenant onboarding modules, Vault PKI activation, dynamic site configurations mapping, continuous recording, and the **AIEYE 12-Models Alert Ingestion Integration Loop** via Redis Streams.
| **Phase 2 — Mid Scope Integration** | 2,000 cameras cluster deployment | Advanced relational RBAC authorization enforcement, multi-site active routing configurations, mobile push messaging integrations.
| **Phase 3 — Advanced Cluster Release** | 5,000 cameras aggregate scale | OpenSearch cluster analytics indexing execution, full full-text search investigation pipelines.
| **Phase 4 — Enterprise Tender Production** | 50,000 production class cameras | Full cluster disaster recovery promotion testing loops, full transport layer cryptographic hardening.

---

## 7. Code Quality Rules (ALL AGENTS ENFORCE)

### TypeScript / NestJS
- TypeScript strict mode (`"strict": true`) — NO silent `any` types or structural escapes.
- All API endpoints must enforce incoming data DTOs compiled with `class-validator` decorators.
- All structural DTO transformations must use `class-transformer` for exact type coercion hooks.
- All controller microservices must implement explicit Guards (`AuthGuard`, `RolesGuard`) at execution entry.
- All service routes return strictly typed response DTO wrappers — never output raw entity database tables.
- Rely exclusively on Interceptors for structural response shaping instead of ad hoc object template spreads.
- Prisma client engine handles all PostgreSQL queries — raw SQL is banned unless performance-critical and verified.
- Mongoose schemas for MongoDB cluster logs must explicitly enforce structural strict parameters (`strict: true`).
- All Redis keys must follow the composite multi-tenant pattern layout: `cust-{customer_id}:site-{site_id}:{service}:{entity}:{id}`.
- Inline SQL operations and text string-template syntax lookups are strictly prohibited.
- Custom application exceptions must extend standard NestJS `HttpException` or base `DomainException` models.
- Every infrastructure service operation performing a database write must emit a tracking event to the audit bus.

### C++ (Media Core / Edge Agent)
- No raw pointer memory allocations without structural encapsulation inside a native RAII container wrapper.
- GStreamer orchestration logic and stream pipelines must implement explicit state reclamation cleanup loops.
- Inter-thread message handling must process strictly via non-blocking queues — zero shared mutable state execution.
- Leverage memory-mapped I/O operations for high-write continuous recording fragment (fMP4) caching loops.
- RTSP endpoint connection failure routines must process via exponential backoff intervals: 5s, 10s, 20s, 40s, 80s, 160s, capped at a maximum 300s window.

### React / TypeScript (Web Frontend — Vivek)
- Functional components paired with React Hooks are mandatory — class components are strictly forbidden.
- Banned Storage: Never store authentication tokens inside local web storage containers (`localStorage`/`sessionStorage`). Keep assets strictly inside volatile memory.
- Core API client integration must pass through a centralized HTTP client instance fitted with interceptor modules to process authentication updates and token rotation routines.
- Enforce `RepaintBoundary` wrappers around individual video tile matrix elements to isolate streaming paint cycles away from the root layout layout pipeline.
- Implement specialized React Error Boundaries around all individual asynchronous data containers.

### Flutter / Dart (Mobile Track — Sagar)
- Secure hardware token storage via a **custom platform channel** (`SecureStoragePlugin.kt` on Android, `SecureStoragePlugin.swift` on iOS) that directly interfaces with Android Keystore AES-256-GCM key generation and iOS Secure Enclave Keychain — NOT the `flutter_secure_storage` third-party package. Rationale: the custom channel provides direct access to the exact cryptographic primitive for pen-test documentation and security audit sign-off. `flutter_secure_storage` is permissible as a Phase 2 simplification after formal security review.
- Render video stream tiles using `video_player` extensions linked with structural native `Texture` canvas widgets — never route frames through standard browser or platform views.
- Initialize a centralized global token update mechanism (`RefreshLock`) built on a Dart `Completer` handler to safely block concurrent identity refresh execution conflicts.
- Implement Subject Public Key Info (SPKI) hash validation loops targeting our designated HashiCorp Vault Intermediate CA certificate anchor — leaf-level binding rules are rejected.
- Lazy-initialize separate video canvas managers (`VideoPlayerController`), issuing strict `dispose()` procedures immediately during widget stack unmount loops.
- Bind dedicated `RepaintBoundary` nodes around each unique video grid block to separate render cycles from global system application ui redraws.

---

## 8. Security Baseline (NON-NEGOTIABLE — APPLIES TO ALL CORE FILES)

- No cryptographic secrets, operational passwords, or credentials blocks can be saved inside system files, committed git trees, or docker container layer files.
- Active configuration elements and credentials fields must be pulled dynamically from our HashiCorp Vault deployment at application launch.
- Authentication tokens remain strictly contained inside volatile execution instances (no `localStorage` footprint).
- Refresh token persistence layer rules: iOS Keychain parameters locked behind (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`), and Android storage structured through `EncryptedSharedPreferences` frameworks.
- Central backend API gateways operate on a structural default-deny policy — unmapped endpoints return an immediate HTTP 403 Forbidden intercept.
- Data authorization parameters require strict multi-layered verification matching conditions both at the primary NGINX/NestJS Gateway entrypoint and within localized domain actions modules.
- Every data mutation routine (insert, update, delete) must issue a tracking entry to the immutable MongoDB system log collection.
- Code merge procedures require successful pipeline resolution across multiple automated code gates: strict SAST analysis via SonarQube, security container inspection using Trivy or Snyk, and OWASP DAST scans.
- Endpoints tracking identity entry requests require dedicated rate-limiting limits computed via a Redis sliding-window filter mechanism.
- Banned Output: Never pipe plaintext tokens, password variables, encryption parameters, or customer verification strings out to standard console streams (`console.log`) across any deployment tier.
- Security isolation constraint: User email addresses must combine with tenancy context keys to establish a tenant-scoped composite constraint rule: `CONSTRAINT unique_tenant_email UNIQUE (customer_id, email)`. Global database uniqueness is completely banned.

---

## 9. Architecture Boundary Rules

DO:

Native video pipeline mechanics (frame ingestion, transcode routines, fragment segment layout management) ➔ Cloud Media Core engine layers (C++ 17 — Managed jointly by Shubham + Saurabh).

Business rules logic, core configuration tables, identity evaluation gating, and event routing systems ➔ Central NestJS Control Plane microservices (Managed sovereignly by Vivek).

System interaction interfaces, web configurations grids, multi-monitor display controllers ➔ Vite React Application SPA & Electron operator canvas setups (Managed sovereignly by Vivek).

Cross-platform mobile interactions ➔ Shared single-repository Flutter application architecture (Managed single-handedly by Sagar).

Analytical processing workflows ➔ Python/PyTorch inference nodes tracking incoming webcam telemetry vectors (AIEYE External Module).

Archival cluster storage layout management (fMP4 stream files, export items) ➔ MinIO S3 cluster storage pools.

DO NOT:

Implement business authorization rules or data access evaluations inside the C++ Media streaming loops.

Route video decoding, frame segment transcoding, or heavy media pipeline data layers through the NestJS process loop.

Consolidate session authentication routines within UI logic layers. Client layouts handle visibility hooks, backend engines execute strict enforcement rules.

Establish synchronous HTTP request dependencies from Media Core nodes targeting the central NestJS Gateway. Rely strictly on partitioned Redis Streams paths.

Store unstructured high-capacity frame segments, export media, or binary video files inside PostgreSQL or MongoDB tables.

Execute native C++ Media Core operations or deep learning analytics inference within on-premises edge nodes. Keep heavy rendering logic inside Cloud platform nodes.

---

## 10. Naming Conventions

Redis Stream Events:  vms:ai-event:{customer_id}:{site_id}
Redis Core Cache:     cust-{customer_id}:site-{site_id}:{service}:{entity}:{id}
MinIO S3 Buckets:     /recordings/{customer_id}/{site_id}/{camera_id}/{date}/{timestamp}.fmp4
PostgreSQL Tables:    Enforce snake_case and plural nouns (e.g., customers, users, user_site_permissions)
MongoDB Collections:  Enforce camelCase structural rules (e.g., auditLogs, aiEvents, deviceInventory)
NestJS Architecture:  PascalCase for structural modules and configuration files (e.g., AuthModule, AuthService, CreateUserDto)
API Route Paths:      /api/v5/{resource}/{id}/{sub-resource} (Strict lower-case, plural resource entities)
Environment Values:   SCREAMING_SNAKE_CASE execution variables (e.g., VAULT_RAFT_CLUSTER_PORT)
Docker Build Tags:    vms/{service}:{tag} (e.g., vms/control-plane-gateway:1.0.0-rev1)
K8s Cluster Spaces:   vms-{layer} namespaces configuration layout (e.g., vms-control-plane, vms-media)

---

## 11. Git and Branching Rules

main          → production-only, protected, requires 2 approvals + all CI gates green
develop       → integration branch, requires 1 approval + all CI gates green
feature/*     → individual feature branches, named feature/{phase}-{module}-{description}
fix/*         → bug fix branches
release/*     → release candidate branches

Commit format: {type}({scope}): {description}
Types: feat, fix, refactor, test, docs, chore, perf, security
Example: feat(auth): add JWT refresh lock to prevent race condition

---

## 12. Context Folder Protocol (Main Agent Optimization)

After EVERY completed task execution chunk:

1. Write a session tracking markdown report out inside `.context/sessions/YYYY-MM-DD-HH-MM.md`.
2. Document clearly: specific task blocks finalized, outstanding items, encountered blocks, files updated, localized validation test outcomes, and next targeted microtask.
3. Upon initialization of a new session cycle: parse and digest the latest transaction logs present inside `.context/sessions/` before invoking terminal adjustments.
4. Encountering structural errors or environment system freezes: write an incident file out within `.context/reports/YYYY-MM-DD-blocker.md`.

---

## 13. Prohibited Agent Actions (ZERO TOLERANCE AUDIT OVERRIDES)

- ❌ **Never** modify `site_type` to introduce database CHECK or enum constraints. Leave column open as a flexible string table
- ❌ **Never** assume mobile code ownership is shared or TBD. Sagar is the sole owner of Track C/D
- ❌ **Never** assign any NestJS Control Plane or PostgreSQL database design task to Sagar.
- ❌ **Never** split C++ Media Core or Edge Agent work to anyone other than the team of Shubham and Saurabh.
- ❌ **Never** create a global email uniqueness lock inside user tables. Enforce scoped unique indexes using `UNIQUE(customer_id, email)`.
- ❌ **Never** store raw multi-factor registration strings inside application layers. Rely strictly on `mfa_secret_ref` pointers.
- ❌ **Never** use raw SQL queries or bare un-namespaced `cameraId` references during backend operations blocks.

---

_Last updated: Phase 1 SaaS Revision Baseline — June 2026_
_Maintained by: Vivek (Core Infrastructure & Control Plane Lead)_
