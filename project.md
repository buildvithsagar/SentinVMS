# Enterprise VMS — Project Initialization Reference

**Version:** Phase 1 SaaS Revision | **Date:** June 2026
**Classification:** Internal / Confidential
**Standard:** IEEE Std 830-1998 | **SRS Baseline:** v5.1 (Shared B2B SaaS Edition)

---

## 1. Project Identity

The Enterprise Video Management System (VMS) is a cost-effective, centralized Shared-Control-Plane
B2B Multi-Tenant SaaS platform. It manages IP cameras deployed across distributed infrastructure,
distributes live video through a high-performance two-tier streaming model, and exposes interactive
operational interfaces to web, desktop console, mobile, and video-wall clients.

The system provides a seamless historical migration path for current legacy accounts: target
PostgreSQL schemas are engineered upfront to safely ingest historical data loops. This ensures
that when legacy subscribers choose to extend their accounts to full VMS capabilities (Multi-tile
live grids, timeline recordings, camera playback, clip exports) in the future, their historical
profiles remain active and uninterrupted on the same hosted platform.

**Fleet target:** 50,000 cameras (globally namespaced via customer tokens)
**Phase 1 SaaS Validation Target:** 1,000 concurrent mock cameras across 2 distinct mock tenants
**Production GA:** End of Month 12

---

## 2. Frozen Technology Stack

| Layer                      | Technology                                                  | Owner                    |
| -------------------------- | ----------------------------------------------------------- | ------------------------ |
| Media Core (Cloud)         | C++ 17 + GStreamer 1.22                                     | Shubham + Saurabh        |
| Edge Agent (On-Prem)       | C++ 17, Debian 12 minimal                                   | Shubham + Saurabh        |
| Control Plane              | Node.js 20 LTS + NestJS 10                                  | Vivek                    |
| Web Client                 | React 18 + TypeScript 5 + Vite                              | Vivek                    |
| Operator Console           | Electron 28 + WebGPU                                        | Vivek                    |
| Video Wall                 | Linux thin client + Datapath/Hyundai SDK                    | Vivek                    |
| Mobile App                 | Flutter 3.x (Dart) — Solo Mobile Track                      | Sagar                    |
| AI Analytics Layer         | AIEYE Inherited Inference Core (12 Active Models Run As-Is) | Ingestion via VMS Events |
| Relational DB              | PostgreSQL 16 HA (Patroni / CloudNativePG Cluster)          | Vivek                    |
| Cache / Event Bus          | Redis 7 Cluster + Redis Streams Partitioning                | Vivek                    |
| Audit / Events / Inventory | MongoDB 7 Replica Set (PSS Append-Only logs)                | Vivek                    |
| Object Storage             | MinIO (erasure-coded 4+ nodes)                              | Shubham + Vivek          |
| Search                     | OpenSearch 2 (Phase 3 Integration)                          | Vivek                    |
| Secrets / PKI / Signing    | HashiCorp Vault (Raft, RSA-2048 Root to Intermediate)       | Vivek                    |
| Orchestration              | Kubernetes 1.29+ + Docker + Helm + Argo CD                  | Vivek                    |
| Observability              | Prometheus + Loki + Tempo + Grafana + Alertmanager          | Vivek                    |

**Stack is frozen. No substitutions without CCB approval.**

---

## 3. Eight Locked Architectural Pillars (v5.1)

### Pillar 1 — 50,000-Camera Global Multi-Tenant Namespaced Routing

- Every single camera configuration, frame snippet, log record, and stream routing parameter is addressed using a root-level composite tenancy key: `{customer_id}:{site_id}:{camera_id}` across ALL application layers.
- No bare identifiers are allowed anywhere in code logic, database rows, or event payloads. Data isolation is physically enforced via this root composite paradigm to prevent cross-tenant information leakage.

### Pillar 2 — Active-Warm Standby DR

- DR site actively serves read/investigation queries.
- RTO < 5 minutes (Patroni auto-promotion).
- RPO < 30s same-city (synchronous `remote_write`) / < 60s cross-city (`remote_apply`).

### Pillar 3 — Two-Tier LAN Multicast with Edge Loopback

- Profile T/M cameras: direct camera-to-client UDP multicast on LAN (IGMP Snooping + Vault-rotated SRTP AES-128 keys setup).
- Edge Agent appliances (Hardened Debian loops co-owned by Shubham + Saurabh) join the multicast group as loopback proxy subscribers, shipping recording frames securely to Cloud Media Core.
- Camera emits exactly ONE stream. No double-streaming overhead.

### Pillar 4 — NestJS Process Isolation (Day 1)

- API Gateway (HTTP/WebSocket handling) runs in completely SEPARATE event loops and execution containers from:
  - High-throughput background event consumers
  - Microservice alerting pipelines
  - Stream routing workers
- Three isolated Kubernetes deployments are maintained from Day 1 to ensure event bus load surges never block standard API traffic.

### Pillar 5 — Dual-Tiered WAN Constraints

- High-Band >= 100 Mbps sustained/site: live cloud ingest + loopback proxy upload.
- Low-Band >= 10 Mbps sustained/site: ANR sync only (scheduled, off-peak, non-contending).

### Pillar 6 — Locality-Split WebRTC Latency Targets

- LAN/DC operators (RTT <= 15ms to cloud): P95 <= 500ms glass-to-glass view.
- Remote operators (via central HA coturn TURN fleet, government WAN): P95 <= 1.5s.
- HLS fallback stream (Mobile Phase 1 initialization track): <= 5s.

### Pillar 7 — Centralized HA TURN Fleet

- 2 active coturn nodes behind a load balancer at Cloud DC.
- <= 1,000 concurrent relayed streams, N+1 redundancy. STUN/TURN configurations delivered dynamically by Control Plane to active clients.

### Pillar 8 — Secure Token Containment & Mobile Sandboxing

- Phase 1 mobile application code (Sagar's exclusive track) implements basic login workflows, strict JWT contract verification, and HLS streaming components.
- The system establishes a secure container framework: all runtime tokens, authentication assets, and certificates are isolated inside native hardware cryptoprocessors (Android Keystore / iOS Enclave Keychain). Mobile traffic never receives elevated cluster access commands.

---

## 4. Deployment Model

Cloud Platform (Centralized SaaS Kubernetes Cluster)
├── ns: ingress → NGINX/Traefik, TLS 1.3 termination
├── ns: control-plane → NestJS API Gateway (Multi-tenant process-isolated)
│ NestJS Event Consumer Workers (Isolated Stream processors)
│ NestJS WebSocket Broadcaster (Dynamic alerts routing)
├── ns: media → C++ Cloud Media Core pods (GStreamer pipelines, Shubham+Saurabh ownership)
│ Recorder pods (fMP4 stream segmenting assembly)
├── ns: ai-ingress → AIEYE Webhook Receiver Gateway (Async payloads interception)
├── ns: data → PostgreSQL Primary + Standby (Patroni clustering with customer_id sharding)
│ Redis Cluster (3 masters + 3 replicas event bus routing)
│ MongoDB Replica Set (PSS immutable audit stores)
├── ns: storage → MinIO S3 (Multi-tenant partitioned buckets layout)
├── ns: observability → Prometheus, Loki, Tempo, Grafana stack
└── ns: security → HashiCorp Vault cluster (PKI Secrets Engine, RSA-2048 intermediate)

Edge (On-Premises per site)
└── C++ Edge Agent Appliance (Hardened Debian 12 loop - Shubham + Saurabh)
├── ONVIF WS-Discovery engine
├── Multicast loopback proxy proxying recordings
├── 512 GB local ANR storage partition
└── Local PTZ command execution bridge

---

## 5. Data-Store Discipline

| Store      | Allowed Data                                                                                                                                                                                                                                      | Forbidden                                                                                    |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| PostgreSQL | `customers` matrix profiles, `vms_modules` catalog, `customer_module_entitlements`, `users` profiles, dynamic `sites` metadata, `cameras` hardware configurations, `user_site_permissions`. Every single row MUST use a root-level `customer_id`. | Global flat indices, raw un-scoped logs, AI metadata payloads, raw text `mfa_secret` fields. |
| Redis      | Active sessions state, JWT revocation logs, pub/sub streams, multi-tenant alerting pipelines partitioned via `vms:ai-event:{customer_id}:{site_id}` tracking.                                                                                     | Long-term cold analytics data, unpartitioned event registers.                                |
| MongoDB    | Immutable audit entries tracking state-changing client operations, historical system telemetry logs, AI analytics events tracking history.                                                                                                        | Relational schema tables metadata, core authentication configuration records.                |
| MinIO/S3   | Continuous video recording segments (fMP4 fragments), secure exports, alert snapshots.                                                                                                                                                            | Transactional user state data, microservice schema configs.                                  |
| Vault      | SRTP encryption keys, per-camera leaf certificates, RSA master signing tokens, `mfa_secret_ref` tokens mapping tracking.                                                                                                                          | Standard application properties, raw business configurations logic.                          |

---

## 6. Security Baseline (All Phases)

- TLS 1.3 everywhere (mTLS between internal background workers)
- SRTP + AES-128 media payload encryption
- Bcrypt password hashing, cost factor >= 12
- JWT: Access token (8h in-memory container execution only, never stored in localStorage), Refresh token (30d HttpOnly Secure SameSite cookie state)
- Strict tenant-scoped data isolation constraint: `CONSTRAINT unique_tenant_email UNIQUE (customer_id, email)`. Global uniqueness is banned to prevent cross-tenant user lockout attacks.
- MFA Secrets protection: Raw keys are forbidden in database rows. Relational user tables must exclusively map an **`mfa_secret_ref VARCHAR(255)`** pointing towards HashiCorp Vault.

---

## 7. Four-Phase Delivery Model

| Phase   | Tier      | Duration              | Validation Workload Target                         | Release / Scope Update                                   |
| ------- | --------- | --------------------- | -------------------------------------------------- | -------------------------------------------------------- |
| Phase 1 | Standard  | Month 1–3 (S1–S6)     | 1,000 mock cameras, 2 distinct mock tenants        | v1.0 (Core VMS SaaS + AIEYE Event Ingestion Integration) |
| Phase 2 | Mid       | Month 4–6 (S7–S12)    | 2,000 cameras, multi-site active routing           | v2.0 (Relational Dynamic RBAC Enforcement & Federation)  |
| Phase 3 | Advanced  | Month 7–9 (S13–S18)   | 5,000 cameras, open search indexing clusters       | v3.0 (OpenSearch cluster analytics deployments)          |
| Phase 4 | Tender/GA | Month 10–12 (S19–S24) | 50,000-class high available production environment | Full Production GA Baseline                              |

---

## 8. Phase 1 Standard — 10 Feature Matrix

| #   | Feature                                                                                          | Primary Owner                                        |
| --- | ------------------------------------------------------------------------------------------------ | ---------------------------------------------------- |
| F01 | Camera Integration (ONVIF auto-discovery protocols, streaming parameters extraction)             | Shubham + Saurabh                                    |
| F02 | Multi-Tenant Live View (Dynamic grid layout processing, multi-tile video matrix canvas)          | Shubham + Saurabh (Media Core) + Vivek (Web Client)  |
| F03 | PTZ Routing Loopbacks (Zoom, pan commands serialization, bridge network routing)                 | Shubham + Saurabh (Media Core) + Vivek (UI controls) |
| F04 | Continuous Cloud Recording (Assembling continuous fMP4 fragments safely inside MinIO)            | Shubham + Saurabh                                    |
| F05 | Timeline Archive Playback (Playback scrubbing engine logic, dynamic snapshot generation)         | Shubham + Saurabh (Engine) + Vivek (UI Layout)       |
| F06 | Secure Export Pipeline (Watermarked clip downloading framework, media verification layers)       | Shubham + Saurabh                                    |
| F07 | User Directory & Tenant Gating (NestJS Guard loops, verification via entitlements registry)      | Vivek                                                |
| F08 | Infrastructure Health Telemetry (Edge agent monitoring dashboards, storage capacity alerts)      | Vivek + Shubham + Saurabh                            |
| F09 | Solo Cross-Platform Mobile Apps (Flutter multi-platform engine orchestration, HLS pipelines)     | Sagar                                                |
| F10 | System Encryption & Audits (mTLS worker orchestration, HashiCorp CA intermediate initialization) | Vivek (Auth/Vault/Audit Engine)                      |

---

## 9. Git Branching Rules

```
main                              → production-only, protected, 2 approvals + all CI gates green
develop                           → integration branch, squash merges from feature branches
feature/VMS-{ticket}-{desc}       → individual feature branches
fix/VMS-{ticket}-{desc}           → bug fix branches
release/v{major}.{minor}.0        → release candidate branches
```

**Rules:**

- No direct commits to `main` or `develop`
- All feature branches branch from `develop`
- CI must pass (lint + unit + integration + SAST + SCA) before PR can be reviewed
- DAST runs on staging after merge to `develop`
- Release branches are frozen — only cherry-pick hotfixes allowed

---

## 10. Quality Gates — Phase 1 SaaS Scale

| Gate                    | Threshold              | Operational Verification Rule                                                           |
| ----------------------- | ---------------------- | --------------------------------------------------------------------------------------- |
| Unit test coverage      | >= 60%                 | Checked automatically on code commits before merges                                     |
| SAST / Dependency SCA   | Zero Critical Findings | Verified via SonarQube, Snyk, and Trivy image scans                                     |
| Multi-Tenant Leakage    | Zero Tolerance         | Automated script validating zero data cross-contamination between mock tenants          |
| Sizing Target Workload  | 1,000 Cameras          | Must maintain stable concurrent active streaming routines for 7 continuous days         |
| Site Configuration Flow | Dynamic Ingestion      | `site_type` configured as open `VARCHAR(100)` allowing infinite frontend custom layouts |

---

## 11. Key NFRs — Phase 1 Scope

- Live view latency: P95 <= 500ms LAN WebRTC / <= 5s HLS mobile fallback
- API response P95: <= 500ms (control plane)
- Camera status detection latency: <= 30s
- Recording: continuous fMP4 segments to MinIO, no gaps
- Playback: timeline scrub, 0.5x–16x FF, 1x–2x RW
- Availability: >= 99.0% during Phase 1 single-station pilot deployment
- Auth: JWT access 8h in-memory, refresh 30d HttpOnly cookie

---

## 12. Antigravity Workspace Rules

- Each ownership file is a self-contained task source for that engineer's agent context.
- Tasks are atomic: one task = one deployable/testable artifact.
- Cross-owner dependencies must be declared explicitly with interface contracts.
- No task may reference a Phase 2+ deliverable as a prerequisite for Phase 1 completion.
- Terminology compliance: Use `customer_id` across all artifacts to ensure compatibility with inherited AIEYE Python configurations.
