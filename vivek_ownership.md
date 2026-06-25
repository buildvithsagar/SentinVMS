# Vivek — Phase 1 Ownership: Control Plane, Data Layer, Web Client, Security

**Role:** Lead Full-Stack Control Plane & Storage Infrastructure Sovereign Owner
**Phase:** 1 SaaS Revision
**Features Owned:** F02 (Web Client Portal Live View Grid), F03 (PTZ UI Controls — Web Portal), F05 (Playback UI Grid — Web Portal), F07 (User Directory & Tenant Gating), F08 (Health Monitoring Dashboards), F10 (System Encryption & Audits — Vault, mTLS, HashiCorp CA, Audit Engine)

> **Boundary Clarity per project.md Section 8:**
> - F02: Vivek owns **web client portal** live view grid. Media Core streaming = Saurabh. Mobile HLS shell = Sagar.
> - F03: Vivek owns **web portal PTZ controls UI**. Edge PTZ execution bridge = Shubham. Media Core PTZ routing = Saurabh.
> - F05: Vivek owns **web portal playback timeline UI** (SVG scrubber, speed controls). Engine = Saurabh. Mobile scrubber = Sagar.
> - F10: Vivek is the **sole F10 owner** — Vault PKI, mTLS, HashiCorp CA, audit logs, JWT issuance, RBAC enforcement.

---

## Architectural Mandate

- **Pillar 4 Process Isolation Engine:** NestJS infrastructure must run as THREE structurally separate Kubernetes Deployments from Day 1 to eliminate background workers backpressure stalls:
  1. `vms-api-gateway` — Central multi-tenant REST endpoints gateway (/api/v5/*), identity verification, and WebSocket connection entrypoints container.
  2. `vms-event-workers` — Async Redis Streams event loop consumers, rules engine evaluations, and database recording indices workers container.
  3. `vms-ws-broadcaster` — Real-time user session status and telemetry fan-out broadcaster via sticky session configurations (`sessionAffinity: ClientIP`).
- **Pillar 1 Tenancy Isolation:** Every single transactional database row, primary key index, and query statement inside Patroni PostgreSQL 16, Redis 7 Cluster, and MongoDB 7 PSS must be sharded via the root canonical partitioning key: `customer_id`. All relationships and queries must use composite foreign key paths.
- **Global Spatial Namespace Expansion:** Every camera asset registry lookup statement requires the full structural composite index tuple: `(customer_id, site_id, camera_id)`. Un-namespaced bare queries are strictly prohibited.
- **Sovereign UI Workspace Boundaries:** Vivek holds absolute code ownership over the Vite React 18 TypeScript Web SPA, the Electron 28 Dedicated Operator Desktop Console via WebGPU canvas loops, and the Linux Thin Client Video Monitor Wall modules.

---

## Sub-Phase 1.1 — NestJS Monorepo Foundation & Process-Isolated Container Split

### Task 1.1.1 — Nx Multi-Tenant Monorepo Initialization
- Initialize Nx workspace structure: `nx init --preset=nest`.
- Create three independent process-isolated application deployment targets:
  - `apps/api-gateway` — REST/WS public ingress, default-deny auth security guards on all routes.
  - `apps/event-workers` — Partitioned Redis Streams async background consumer engine.
  - `apps/ws-broadcaster` — Real-time user notification broad hub, Redis cluster pub/sub subscriber.
- Create unified shared enterprise libraries:
  - `libs/common` — Custom DTO definitions, request interceptors, and error decorators.
  - `libs/database` — Prisma schemas definitions, Patroni model bindings, and migrations history.
  - `libs/auth` — Short-lived JWT processing logic, Passport strategy integrations.
- ESLint Configuration: Enforce strict TypeScript compilation parameters (`"strict": true`). Banned: Silent `any` declarations trigger immediate compilation exceptions (`@typescript-eslint/no-explicit-any = error`).
- Initialize Husky pre-commit hooks executing automated type-check and deterministic regex scanners scripts on staged files.

### Task 1.1.2 — Docker Compose Development Stack Configuration
- Configure `docker-compose.dev.yml` executing the microservice sandbox topology layers:
  - Patroni PostgreSQL 16 Cluster (HA sharded replication engine simulation).
  - Redis 7 Enterprise Cluster (3 Masters + 3 Replicas deployment setup).
  - MongoDB 7 PSS Replica Set (3 physical node blocks for append-only logs).
  - Distributed MinIO Storage (Erasure-coded multi-node drives layout).
  - HashiCorp Vault Server (Local dev state initializing Root to Intermediate CA signing paths).
  - Prometheus, Loki, and Grafana monitoring stacks.
- Configure explicit multi-tenant health verification checks to delay server booting until all backend storage structures are active.

### Task 1.1.3 — Kubernetes Helm Chart Scaffolding (Phase 1 Baseline)
- Configure `charts/vms-umbrella/` structuring the child deployment patterns:
  - `vms-api-gateway`: Minimum 2 replica pods, readiness/liveness checks on `/health`, scale on CPU >= 70%, PodDisruptionBudget `minAvailable 1`.
  - `vms-event-workers`: Minimum 2 replica instances, no external ingress paths.
  - `vms-ws-broadcaster`: Minimum 2 replica pods, sticky load-balancing session parameters via `sessionAffinity: ClientIP`.
- Embed native HashiCorp Vault agent sidecar secret injection annotations across all cluster resource files.

### Task 1.1.4 — Observability Metrics Scaffolding
- Every application deployment target implements the metric scrape route: `GET /metrics` via `@willsoto/nestjs-prometheus`.
- Enforce structured JSON logging via `nestjs-pino` appending auditing telemetry tokens: `traceId`, `spanId`, `customer_id`, `userId`, `action`, `durationMs`.
- Wire OpenTelemetry node SDK handlers pushing tracer spans to Loki and Tempo analytics pools.
- Configure Alertmanager rules triggering alerts when API error rate > 5% for 2min, or Redis stream consumer group lag > 100 entries.

---

## Sub-Phase 1.2 — Patroni PostgreSQL Relational Schema Migrations

### Task 1.2.1 — HA Database Connection Routing
- Setup `TypeOrmModule.forRootAsync()` fetching relational access secrets dynamically from Vault sidecar mount files.
- Connection pooling limits parameters: minimum 5, maximum 20 concurrent links.
- Enforce transport network cryptographic layer: `ssl: { rejectUnauthorized: true, ca: vaultCACert }`.
- Block application auto-synchronization: `synchronize: false` is absolute rule. Use explicit versioned migrations.

### Task 1.2.2 — Schema Migration: customers & sites (Dynamic UI Forms Portability)
```sql
CREATE TABLE customers (
  id                  UUID                 PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id           VARCHAR(8)           UNIQUE NOT NULL, -- 8-digit unique alphanumeric tracking tag
  customer_type       VARCHAR(30)          NOT NULL DEFAULT 'COMPANY' CHECK (customer_type IN ('COMPANY', 'INDIVIDUAL')),
  organization_name   VARCHAR(255)         NOT NULL,
  contact_person_name VARCHAR(255)         NOT NULL,
  email               VARCHAR(255)         UNIQUE NOT NULL,
  phone_number        VARCHAR(15)          NOT NULL,
  billing_address     TEXT,
  pincode             VARCHAR(20),
  industry_type       VARCHAR(50)          NOT NULL DEFAULT 'OTHER',
  max_cameras         INTEGER              NOT NULL DEFAULT 10 CHECK (max_cameras BETWEEN 1 AND 50000),
  status              VARCHAR(30)          NOT NULL DEFAULT 'PENDING_LICENSE',
  created_at          TIMESTAMPTZ          NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ          NOT NULL DEFAULT NOW()
);

-- Dynamic UI Site Forms Mapping Pattern: Banned hard database CHECK validation enums
CREATE TABLE sites (
  id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id   UUID         NOT NULL REFERENCES customers(id) ON DELETE CASCADE, -- Root tenant partition
  site_name     VARCHAR(255) NOT NULL,
  site_type     VARCHAR(100) NOT NULL DEFAULT 'OFFICE', -- Open text string handling frontend layouts autonomy
  parent_id     UUID,
  full_path     TEXT         NOT NULL DEFAULT '',
  address       TEXT,
  city          VARCHAR(100),
  state         VARCHAR(100),
  country       VARCHAR(100),
  postal_code   VARCHAR(20),
  latitude      DECIMAL(10,8) CHECK (latitude BETWEEN -90 AND 90),
  longitude     DECIMAL(11,8) CHECK (longitude BETWEEN -180 AND 180),
  is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  
  CONSTRAINT unique_tenant_site_id UNIQUE (customer_id, id),
  CONSTRAINT unique_tenant_site_node UNIQUE(customer_id, parent_id, site_name),
  CONSTRAINT fk_sites_parent FOREIGN KEY (customer_id, parent_id) REFERENCES sites(customer_id, id) ON DELETE SET NULL
);
CREATE INDEX idx_sites_tenant_parent ON sites(customer_id, parent_id);
```

### Task 1.2.3 — Schema Migration: users & sessions (Collision-Free Scoping)
```sql
CREATE TABLE users (
  id                  UUID             PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id         UUID             REFERENCES customers(id) ON DELETE CASCADE, -- Nullable strictly for Super Admins
  username            VARCHAR(50)      NOT NULL,
  email               VARCHAR(255)     NOT NULL,
  password_hash       VARCHAR(255)     NOT NULL, -- Bcrypt hash factor >= 12
  role                VARCHAR(30)      NOT NULL DEFAULT 'VIEWER',
  status              VARCHAR(30)      NOT NULL DEFAULT 'ACTIVE',
  mfa_enabled         BOOLEAN          NOT NULL DEFAULT FALSE,
  mfa_secret_ref      VARCHAR(255),    -- Cryptographic hash reference string pointing to HashiCorp Vault
  failed_login_count     INTEGER          NOT NULL DEFAULT 0,
  locked_until        TIMESTAMPTZ,
  password_changed_at TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
  created_at          TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
  
  -- Scoped Isolation Unique Constraints: Erases cross-tenant user lookup enumeration exploits
  CONSTRAINT unique_tenant_user_id UNIQUE (customer_id, id),
  CONSTRAINT unique_tenant_email UNIQUE (customer_id, email),
  CONSTRAINT chk_sa_isolation CHECK ((role = 'SUPER_ADMIN' AND customer_id IS NULL) OR (role <> 'SUPER_ADMIN' AND customer_id IS NOT NULL))
);
CREATE UNIQUE INDEX idx_super_admin_global ON users(email) WHERE customer_id IS NULL;

CREATE TABLE refresh_tokens (
  id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID         NOT NULL,
  customer_id  UUID         NOT NULL REFERENCES customers(id) ON DELETE CASCADE, -- Root tenant identifier
  token_hash   CHAR(64)     NOT NULL, -- SHA-256 signature hash string
  issued_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  expires_at   TIMESTAMPTZ  NOT NULL,
  revoked      BOOLEAN      NOT NULL DEFAULT FALSE,
  ip_address   INET,
  user_agent   TEXT,
  CONSTRAINT uq_refresh_token_hash UNIQUE (token_hash),
  CONSTRAINT chk_refresh_expiry CHECK (expires_at > issued_at),
  CONSTRAINT fk_refresh_users FOREIGN KEY (customer_id, user_id) REFERENCES users(customer_id, id) ON DELETE CASCADE
);
CREATE INDEX idx_refresh_tenant_hash ON refresh_tokens(customer_id, token_hash) WHERE revoked = FALSE;
```

### Task 1.2.4 — Schema Migration: cameras & edge_servers
```sql
CREATE TABLE edge_servers (
  id                   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id          UUID         NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  site_id              UUID,
  server_name          VARCHAR(255) NOT NULL,
  serial_number        VARCHAR(100) NOT NULL,
  mac_address          MACADDR      NOT NULL,
  status               VARCHAR(30)  NOT NULL DEFAULT 'OFFLINE',
  created_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_tenant_server UNIQUE(customer_id, server_name),
  CONSTRAINT unique_hardware_serial UNIQUE(serial_number),
  CONSTRAINT unique_tenant_edge_server_id UNIQUE (customer_id, id),
  CONSTRAINT fk_edge_sites FOREIGN KEY (customer_id, site_id) REFERENCES sites(customer_id, id) ON DELETE SET NULL
);

-- Relational Contract: Locked composite primary key enforces multi-tenant tree boundaries
CREATE TABLE cameras (
  id                       UUID                  DEFAULT gen_random_uuid(),
  customer_id              UUID                  NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  site_id                  UUID                  NOT NULL,
  edge_server_id           UUID                  NOT NULL,
  camera_name              VARCHAR(255)          NOT NULL,
  ip_address               INET                  NOT NULL,
  rtsp_url                 TEXT                  NOT NULL,
  onvif_profile            VARCHAR(5)            NOT NULL DEFAULT 'S',
  codec                    VARCHAR(20)           NOT NULL DEFAULT 'H264',
  ptz_enabled              BOOLEAN               NOT NULL DEFAULT FALSE,
  recording_enabled        BOOLEAN               NOT NULL DEFAULT TRUE,
  status                   VARCHAR(30)           NOT NULL DEFAULT 'UNKNOWN',
  is_active                BOOLEAN               NOT NULL DEFAULT TRUE,
  created_at               TIMESTAMPTZ           NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ           NOT NULL DEFAULT NOW(),

  PRIMARY KEY (customer_id, id), -- Composite Namespace Key
  CONSTRAINT unique_tenant_site_camera UNIQUE(customer_id, site_id, camera_name),
  CONSTRAINT unique_site_ip_block UNIQUE(site_id, ip_address),
  CONSTRAINT fk_cameras_sites FOREIGN KEY (customer_id, site_id) REFERENCES sites(customer_id, id) ON DELETE RESTRICT,
  CONSTRAINT fk_cameras_edge FOREIGN KEY (customer_id, edge_server_id) REFERENCES edge_servers(customer_id, id) ON DELETE RESTRICT
);
CREATE INDEX idx_cameras_tenant_spatial ON cameras(customer_id, site_id, status);
```

### Task 1.2.5 — Schema Migration: recordings & customer_module_entitlements
```sql
CREATE TABLE recordings (
  id                 UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id        UUID                NOT NULL REFERENCES customers(id) ON DELETE CASCADE, -- Tenant isolation key
  site_id            UUID                NOT NULL REFERENCES sites(id) ON DELETE RESTRICT,
  camera_id          UUID                NOT NULL,
  recording_type     VARCHAR(30)         NOT NULL DEFAULT 'CONTINUOUS',
  start_time         TIMESTAMPTZ         NOT NULL,
  end_time           TIMESTAMPTZ,
  file_path          TEXT                NOT NULL, -- MinIO hot/warm S3 bucket path string
  file_size_bytes    BIGINT,
  storage_tier       VARCHAR(15)         NOT NULL DEFAULT 'HOT',
  is_active          BOOLEAN             NOT NULL DEFAULT TRUE,
  created_at         TIMESTAMPTZ         NOT NULL DEFAULT NOW(),

  -- Compulsory Composite FK constraints tree validation down to camera rows
  FOREIGN KEY (customer_id, camera_id) REFERENCES cameras(customer_id, id) ON DELETE CASCADE,
  CONSTRAINT chk_rec_times CHECK (end_time IS NULL OR end_time > start_time),
  CONSTRAINT unique_tenant_object_key UNIQUE(customer_id, file_path)
);
CREATE INDEX idx_recordings_tenant_search ON recordings(customer_id, camera_id, start_time DESC);

-- Feature Gating Matrix Table: Maps the 12 active AI models license tokens
CREATE TABLE customer_module_entitlements (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID        NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  module_code VARCHAR(50) NOT NULL, -- e.g. 'LIVE_GRID', 'ANPR_WITH_SPEED', 'FIRE_SMOKE'
  is_enabled  BOOLEAN     NOT NULL DEFAULT FALSE,
  allocated_slots INTEGER NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_customer_entitlement UNIQUE(customer_id, module_code)
);
```

### Task 1.2.6 — Schema Migration: workspace_layouts
```sql
CREATE TABLE workspace_layouts (
  id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id  UUID         NOT NULL REFERENCES customers(id) ON DELETE CASCADE, -- Partitioning key
  user_id      UUID         NOT NULL,
  name         VARCHAR(255) NOT NULL,
  tile_count   SMALLINT     NOT NULL CHECK (tile_count IN (1, 4, 8, 16)),
  layout_json  JSONB        NOT NULL DEFAULT '{}',
  is_default   BOOLEAN      NOT NULL DEFAULT FALSE,
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_layouts_users FOREIGN KEY (customer_id, user_id) REFERENCES users(customer_id, id) ON DELETE CASCADE
);
```

---

## Sub-Phase 1.3 — MongoDB Immutable Audit Logs Collection Schema

### Task 1.3.1 — Durability-Guaranteed MongoDB Link
- Setup `MongooseModule.forRootAsync()` initializing write parameters rules.
- Enforce strict transaction write concern: `{ w: 'majority', j: true, wtimeout: 5000 }`.
- Connection string must explicitly array all three members of the PSS replica set cluster.

### Task 1.3.2 — audit_logs Collection Structure
```typescript
@Schema({
  collection: 'audit_logs',
  timestamps: false,
  strict:     true, -- Unknown parameters fields are blocked instantly
  versionKey: false,
})
export class AuditLog {
  @Prop({ required: true, type: String, index: true })
  userId: string;

  @Prop({ required: true, type: String, index: true }) // Token rule: '{resource}.{verb}.{outcome}'
  action: string;

  @Prop({ required: true, type: String, index: true })
  customer_id: string; // Mandatory Root Multi-Tenant sharding partition token

  @Prop({ required: true, type: String, index: true })
  siteId: string;

  @Prop({ required: true, type: String })
  ipAddress: string;

  @Prop({ type: Object, default: {} })
  metadata: Record<string, unknown>; // Sanitized variables fields; passwords/keys mapped to [REDACTED]

  @Prop({ required: true, type: Date, index: true })
  timestamp: Date;

  @Prop({ required: true, type: String, unique: true })
  payloadHash: string; // Cryptographic verification signature
}
export const AuditLogSchema = SchemaFactory.createForClass(AuditLog);
AuditLogSchema.index({ customer_id: 1, timestamp: -1 });
```

### Task 1.3.3 — AuditService (Write-Only)
- **System Invariant:** The `AuditService` contains ZERO update, delete, or modify endpoint abstractions. Fire-and-forget loops are banned. Enforce connection-level majority write concern.
- The NestJS `AuditInterceptor` intercepts all incoming state-mutating requests (`POST`, `PUT`, `PATCH`, `DELETE`), computes the cryptographic row signature hash, and blocks client operation processing if database logging fails.

---

## Sub-Phase 1.4 — Auth Service & Multi-Tenant Token Protection

### Task 1.4.1 — Identity Module Scaffolding
- Implement `apps/api-gateway/src/auth/` containing dedicated router guards: `ThrottlerGuard` (sliding window rate-limiter), `JwtAuthGuard` (JWT payload verification), and `RolesGuard` (Default-Deny access checking).

### Task 1.4.2 — Short-Lived JWT Architecture Contract
```typescript
interface JwtMultiTenantPayload {
  sub:         string;   // userId UUID string
  customer_id: string;   // Canonical Tenant Token key index
  email:       string;
  role:        'SUPER_ADMIN' | 'ADMIN' | 'SUPERVISOR' | 'OPERATOR' | 'VIEWER';
  siteId:      string;
  sessionId:   string;   // Random UUID bound to Redis session maps
}
// Access token: HS256, 8-hours lifetime, master signature key pulled from Vault memory
// Refresh token: 64-byte randomized string hash, mapped to cookie paths (/api/v5/auth/refresh)
```

### Task 1.4.3 — Login Processing Loop & Vault MFA Verification
- Public identity route received: `POST /api/v5/auth/login`.
- Step 1: Check IP counter inside Redis sliding window. Over crossing 5 sequential failures within 60s triggers immediate `HTTP 429 Too Many Requests` response.
- Step 2: Query PostgreSQL user record filtering strictly via composite arguments: `WHERE customer_id = $1 AND email = $2`. Invalid parameters execute a simulated dummy bcrypt computational load to drop timing oracle side-channels.
- Step 3: Evaluate MFA verification code against the decrypted `mfa_secret_ref` pointer context resolved asynchronously from HashiCorp Vault.
- Step 4: Map access token straight to client volatile memory structures (Zustand context state), and set refresh token inside an encrypted `HttpOnly Secure SameSite=Strict` cookie wrapper.

### Task 1.4.4 — JWT Blacklist via Redis
- Implement `revokeSession(sessionId: string, ttlSeconds: number)` writing blacklisted sessions to Redis cache keys: `cust-{customer_id}:jwt:blacklist:{sessionId}` (TTL: remaining token lifetime).
- Implement `isRevoked(sessionId: string)` checking blacklist keys before allowing request authentication.

---

## Sub-Phase 1.5 — Default-Deny Authorization Gates Enforcements

### Task 1.5.1 — Default-Deny Roles Guard
- Route access controller implements an absolute default-deny condition via `RolesGuard`.
- If a route handler lacks explicit context annotations matching `@Roles()` or `@Public()`, the filter aborts request processing, immediately returning an `HTTP 403 Forbidden` intercept to the caller.
- **SaaS Authorization Filter:** Every standard camera query, live stream seek request, or alarm modification statement must inject identity parameters verified strictly from the client JWT payload context: `WHERE customer_id = token.customer_id AND site_id = token.site_id`. Parsing tenancy definitions directly from user-supplied bodies or request arguments is completely banned.

### Task 1.5.2 — Password Scoped Policy
- Implement `validatePasswordPolicy(password: string, previousHashes: string[])` enforcing: length >= 12, uppercase/lowercase/number/symbol inclusion, and blocking reuse of the last 5 passwords.

---

## Sub-Phase 1.6 — High-Throughput Event Ingestion Workers Processing

### Task 1.6.1 — Partitioned AI Webhooks Interception
- Implement async consumer loops running strictly within the process-isolated container space: `apps/event-workers`.
- Workers parse real-time incoming JSON webhook alerts payloads emitted from the external AIEYE cluster node matrix, routing transactions asynchronously into message bus streams partitioned dynamically via: **`vms:ai-event:{customer_id}:{site_id}`**.
- Track slots allocations for the 12 primary active core models: `ANPR_WITH_SPEED`, `CAMERA_TAMPERING`, `CROWD_DETECTION`, `FACE_DETECTION`, `FALLEN_DETECTION`, `FIRE_SMOKE`, `INTRUSION`, `MISSING_OBJECT`, `PIPE_DETECTION`, `TAILGATING`.
- Implement strict `XCLAIM` message claiming routines fitted with a 30-second pending timeout threshold to rescue stale alarms on pod crashes. Enforce manual `setImmediate()` execution yields after every batch tick to shield the libuv event loop from starvation.

### Task 1.6.2 — Health Telemetry Endpoints
- Set up endpoints exposing camera health status cache, per-service heartbeats, and MinIO storage tier levels:
  - `GET /api/v5/health/cameras` — site-scoped real-time camera state checks.
  - `GET /api/v5/health/system` — independent cluster service status.
  - `GET /api/v5/health/storage` — MinIO disk/capacity consumption metrics.

### Task 1.6.3 — Storage Alert Deduplication
- Consume `vms:storage-alert` event stream. On threshold breach (default 80%), publish alert to ws-broadcaster.
- Implement alerts rate-limiting using Redis de-duplication keys: `alert:storage:{siteId}:{tier}` (TTL: 300 seconds).

---

## Sub-Phase 1.7 — React Web Client Architecture & Dynamic Layout Grid

### Task 1.7.1 — Vite React Portal Setup
- Create `apps/web-client/` via Vite React-TS template. Strict lint rules: compilation throws errors on silent `any` overrides.
- **Volatile Token Storage Rule:** Banned caching or writing security tokens into persistent browser local or session targets (`localStorage`/`sessionStorage`). Retain access token parameters strictly inside short-lived Zustand application memory modules.

### Task 1.7.2 — React Error Boundaries & Custom Sites Portal Form
- Encapsulate all route-level workspace layout panels inside custom React Error Boundaries to prevent runtime rendering crashes from polluting the DOM.
- **Dynamic Site Handling View Component:** Implement an unrestricted alphanumeric text form panel capturing Tenant Admin site descriptions text. Portal containers dynamically bind variable multi-tile camera streams maps to these user-generated site string profiles, mapping elements smoothly via React Query.
- **Monitoring Live View Layout:** CSS Grid workspace rendering 1, 4, 8, and 16 concurrent live camera video streams partitions fitted with animated skeleton loaders during fragment buffering cycles.

### Task 1.7.3 — In-Memory Auth Store
- Configure Zustand client auth store managing `accessToken` and `UserProfile` state in-memory only. Global RefreshLock mutex blocks duplicate requests during background React Query token refreshes.

### Task 1.7.4 — Workspace Routing
- Implement React Router `createBrowserRouter` registering protected portal layouts:
  - `/login` — login ingress mapping.
  - `/monitoring` — CSS live view workspace.
  - `/archives` — timeline playback seek panel.
  - `/admin` — role-guarded customer config tables (ADMIN only).
  - `/dashboards` — operational health widgets.

### Task 1.7.5 — Video Tile playback & Timeline Seek UI
- Implement `VideoTile` loading, playing, error, and offline UI state indicators.
- Implement timeline SVG seek bar displaying colored markers by recording type (Continuous, Motion, Schedule) alongside drag-handle time-tooltip overlays.
- Implement media controls: 0.5x to 16x speed scaling, reverse rewind, frame-by-frame seeking, multi-camera synchronization, and MinIO frame storyboard hover overlays.
