# BACKEND_SCHEMA.md — Physical Data Structures
**VMS Enterprise | Phase 1 SaaS Revision | SRS v5.1 Baseline (Shared B2B SaaS Edition)**
**Classification:** Internal / Confidential

---

## Overview

This document defines the authoritative physical schema for every data store deployed in Phase 1. These schemas are the single source of truth for migrations, seed scripts, ORM entity definitions, Mongoose schemas, and Redis key-space contracts.

Three data stores are covered:
1. Patroni PostgreSQL 16 — relational multi-tenant configuration and recording index
2. MongoDB 7 PSS Replica Set — append-only immutable security audit log ledger
3. Redis Cluster 7 — dynamic session state cache, presence telemetry, and partitioned alert streams

---

## Part 1 — Patroni PostgreSQL 16

### 1.0 Global Schema Rules (Enforced, Non-Negotiable)

```
RULE 1: Every single tenant-owned table, primary key index, foreign relationship, and query lookup
MUST strictly incorporate and enforce the root canonical partitioning token key: 'customer_id'.
To prevent cross-tenant data leakage, all child tables must refer to parent entities using composite
foreign keys (e.g. FOREIGN KEY (customer_id, parent_id) REFERENCES parent_table(customer_id, id)).

RULE 2: All timestamps use TIMESTAMPTZ (timezone-aware). TIMESTAMP WITHOUT TIME ZONE is permanently banned.

RULE 3: All primary keys are UUID type using gen_random_uuid() as default layer allocations.
No serial integers, no bigserial, no auto-increment database sequences.

RULE 4: Dynamic Portal Forms Portability: The 'site_type' column inside sites catalog tables must remain
a relaxed, open string target (VARCHAR(100)) with ZERO database-level hard enums, check lists,
or restrictive validation arrays. Field parameter validation is delegated entirely to the NestJS layer.

RULE 5: Soft deletes only. No hard DELETE operations on operational or hardware tracking records.
Use an explicit 'is_active' BOOLEAN state check flag.

RULE 6: Identity Data Protection: Global email constraints are banned. Cross-tenant user lockouts are
eliminated using a strict tenant-scoped composite model constraint: UNIQUE (customer_id, email).

RULE 7: Cryptographic Isolation: Relational user schemas are forbidden from storing plaintext multi-factor
secrets. Tables must exclusively deploy an 'mfa_secret_ref VARCHAR(255)' key tracking external Vault entries.
```

### 1.1 updated_at Trigger Utility Infrastructure

```sql
-- Executed once during core environment bootstrap initialization
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### 1.2 Table: customers (Root SaaS Tenancy Matrix)

```sql
CREATE TABLE customers (
  id                  UUID                 PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id           VARCHAR(8)           UNIQUE NOT NULL, -- 8-digit business license code tracker
  customer_type       VARCHAR(30)          NOT NULL DEFAULT 'COMPANY' CHECK (customer_type IN ('COMPANY', 'INDIVIDUAL')),
  organization_name   VARCHAR(255)         NOT NULL,
  contact_person_name VARCHAR(255)         NOT NULL,
  email               VARCHAR(255)         UNIQUE NOT NULL, -- Global unique org contact point
  phone_number        VARCHAR(15)          NOT NULL,
  billing_address     TEXT,
  pincode             VARCHAR(20),
  industry_type       VARCHAR(50)          NOT NULL DEFAULT 'OTHER',
  max_cameras         INTEGER              NOT NULL DEFAULT 10 CHECK (max_cameras BETWEEN 1 AND 50000),
  status              VARCHAR(30)          NOT NULL DEFAULT 'PENDING_LICENSE',
  created_at          TIMESTAMPTZ          NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ          NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_customers_updated_at BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

### 1.3 Table: sites (Dynamic Mapping — No Enums/CHECK Constraints)

```sql
CREATE TABLE sites (
  id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id   UUID         NOT NULL REFERENCES customers(id) ON DELETE CASCADE, -- Leading partitioning key
  site_name     VARCHAR(255) NOT NULL,
  site_type     VARCHAR(100) NOT NULL DEFAULT 'OFFICE', -- Open string field, zero DB constraints to support forms
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

  CONSTRAINT unique_tenant_site_id UNIQUE (customer_id, id), -- Composite index support for children
  CONSTRAINT unique_tenant_site_node UNIQUE (customer_id, parent_id, site_name),
  CONSTRAINT fk_sites_parent FOREIGN KEY (customer_id, parent_id) REFERENCES sites(customer_id, id) ON DELETE SET NULL
);

CREATE INDEX idx_sites_tenant_parent ON sites(customer_id, parent_id);
CREATE TRIGGER trg_sites_updated_at BEFORE UPDATE ON sites FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

### 1.4 Table: licenses (Tenant Subscriptions Tracker)

```sql
CREATE TABLE licenses (
  id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id         UUID         NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  license_key         VARCHAR(255) UNIQUE NOT NULL,
  max_edge_servers    INTEGER      NOT NULL DEFAULT 1 CHECK (max_edge_servers >= 1),
  max_cameras         INTEGER      NOT NULL DEFAULT 10 CHECK (max_cameras >= 1),
  enabled_ai_models   TEXT[]       NOT NULL DEFAULT '{}', -- Maps the active 12 models matrix lines
  valid_from          TIMESTAMPTZ  NOT NULL,
  valid_to            TIMESTAMPTZ  NOT NULL,
  is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

  CONSTRAINT chk_license_dates CHECK (valid_to > valid_from)
);

CREATE TRIGGER trg_licenses_updated_at BEFORE UPDATE ON licenses FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

### 1.5 Table: vms_modules (Master Capabilities Catalog)

```sql
CREATE TABLE vms_modules (
  id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  module_code         VARCHAR(50)  UNIQUE NOT NULL, -- 'LIVE_GRID', 'ANPR_WITH_SPEED', etc.
  module_name         VARCHAR(100) NOT NULL,
  category            VARCHAR(30)  NOT NULL CHECK (category IN ('CORE_VMS', 'AI_ANALYTICS')),
  is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
```

### 1.6 Table: customer_module_entitlements (Layer A Feature Gating Matrix)

```sql
CREATE TABLE customer_module_entitlements (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id         UUID        NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  module_code         VARCHAR(50) NOT NULL REFERENCES vms_modules(module_code) ON DELETE CASCADE,
  is_enabled          BOOLEAN     NOT NULL DEFAULT FALSE,
  allocated_slots     INTEGER     NOT NULL DEFAULT 0,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT unique_customer_entitlement UNIQUE(customer_id, module_code)
);

CREATE TRIGGER trg_cme_updated_at BEFORE UPDATE ON customer_module_entitlements FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

### 1.7 Table: users (Tenant-Scoped Uniqueness & Vault MFA References)

```sql
CREATE TABLE users (
  id                  UUID             PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id         UUID             REFERENCES customers(id) ON DELETE CASCADE, -- Nullable strictly for Super Admins
  username            VARCHAR(50)      NOT NULL,
  email               VARCHAR(255)     NOT NULL,
  password_hash       VARCHAR(255)     NOT NULL, -- Bcrypt hash factor >= 12
  role                VARCHAR(30)      NOT NULL DEFAULT 'VIEWER', -- Fast path token role mapping
  status              VARCHAR(30)      NOT NULL DEFAULT 'ACTIVE',
  mfa_enabled         BOOLEAN          NOT NULL DEFAULT FALSE,
  mfa_secret_ref      VARCHAR(255),    -- Reference token pointer mapping strictly to Vault cluster
  failed_login_count  INTEGER          NOT NULL DEFAULT 0, -- Renamed from failed_attempts to match APP_FLOW.md Step 4 implementation queries
  locked_until        TIMESTAMPTZ,
  password_changed_at TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
  created_at          TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ      NOT NULL DEFAULT NOW(),

  -- Guard rail: Super Admins are global providers; all other roles must partition by tenant
  CONSTRAINT chk_super_admin_isolation CHECK (
    (role = 'SUPER_ADMIN' AND customer_id IS NULL) OR
    (role <> 'SUPER_ADMIN' AND customer_id IS NOT NULL)
  ),

  -- Composite index support for multi-tenant child FKs
  CONSTRAINT unique_tenant_user_id UNIQUE (customer_id, id),

  -- Scoped Isolation Unique Key: Prevents cross-tenant lockout enumeration attacks
  CONSTRAINT unique_tenant_email UNIQUE (customer_id, email)
);

CREATE UNIQUE INDEX idx_super_admin_global ON users(email) WHERE customer_id IS NULL; -- Super admin uniqueness path
CREATE INDEX idx_users_tenant_lookup ON users(customer_id, status);
CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

### 1.8 Table: refresh_tokens (Hashed Persistence Lifecycle)

```sql
CREATE TABLE refresh_tokens (
  id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID         NOT NULL,
  customer_id  UUID         NOT NULL REFERENCES customers(id) ON DELETE CASCADE, -- Multi-tenant tracking index
  token_hash   CHAR(64)     NOT NULL, -- SHA-256 string signature hash of the raw token
  issued_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  expires_at   TIMESTAMPTZ  NOT NULL,
  revoked      BOOLEAN      NOT NULL DEFAULT FALSE,
  ip_address   INET,
  user_agent   TEXT,

  CONSTRAINT uq_refresh_token_hash UNIQUE (token_hash),
  CONSTRAINT chk_refresh_expiry    CHECK (expires_at > issued_at),
  CONSTRAINT fk_refresh_users      FOREIGN KEY (customer_id, user_id) REFERENCES users(customer_id, id) ON DELETE CASCADE
);

CREATE INDEX idx_refresh_tenant_hash ON refresh_tokens(customer_id, token_hash) WHERE revoked = FALSE;
```

### 1.9 Table: otp_codes (Temporary Security Windows)

```sql
CREATE TABLE otp_codes (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID        NOT NULL,
  customer_id UUID        NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  otp_purpose VARCHAR(30) NOT NULL CHECK (otp_purpose IN ('MFA_VERIFICATION', 'PASSWORD_RESET')),
  code_hash   VARCHAR(255) NOT NULL,
  expires_at  TIMESTAMPTZ NOT NULL,
  is_used     BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT fk_otp_users FOREIGN KEY (customer_id, user_id) REFERENCES users(customer_id, id) ON DELETE CASCADE
);

CREATE INDEX idx_otp_lookup ON otp_codes(customer_id, user_id, otp_purpose) WHERE is_used = FALSE;
```

### 1.10 Table: user_devices (Sagar Mobile Push Delivery Tokens Registry)

```sql
CREATE TABLE user_devices (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID        NOT NULL,
  customer_id   UUID        NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  device_token  TEXT        NOT NULL, -- FCM token / APNs device payload signature
  platform      VARCHAR(20) NOT NULL CHECK (platform IN ('ANDROID', 'IOS')),
  is_active     BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT unique_user_device_token UNIQUE(user_id, device_token),
  CONSTRAINT fk_devices_users FOREIGN KEY (customer_id, user_id) REFERENCES users(customer_id, id) ON DELETE CASCADE
);

CREATE TRIGGER trg_devices_updated_at BEFORE UPDATE ON user_devices FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

### 1.11 Table: user_site_permissions (Granular Layer B Access Gating)

```sql
CREATE TABLE user_site_permissions (
  id                 UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            UUID        NOT NULL,
  customer_id        UUID        NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  site_id            UUID        NOT NULL,
  can_view_live      BOOLEAN     NOT NULL DEFAULT TRUE,
  can_view_playback  BOOLEAN     NOT NULL DEFAULT FALSE,
  can_export_clips   BOOLEAN     NOT NULL DEFAULT FALSE,
  can_manage_devices BOOLEAN     NOT NULL DEFAULT FALSE,
  is_active          BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT unique_user_site_token UNIQUE(user_id, site_id),
  CONSTRAINT fk_usp_users FOREIGN KEY (customer_id, user_id) REFERENCES users(customer_id, id) ON DELETE CASCADE,
  CONSTRAINT fk_usp_sites FOREIGN KEY (customer_id, site_id) REFERENCES sites(customer_id, id) ON DELETE CASCADE
);

CREATE TRIGGER trg_usp_updated_at BEFORE UPDATE ON user_site_permissions FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

### 1.12 Table: edge_servers (Localized Processing Hardware Directory)

```sql
CREATE TABLE edge_servers (
  id                   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id          UUID         NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  site_id              UUID,
  server_name          VARCHAR(255) NOT NULL,
  serial_number        VARCHAR(100) NOT NULL,
  model                VARCHAR(100),
  mac_address          MACADDR      NOT NULL,
  internal_ip          INET,
  external_ip          INET,
  status               VARCHAR(30)  NOT NULL DEFAULT 'OFFLINE',
  software_version     VARCHAR(50),
  last_heartbeat       TIMESTAMPTZ,
  is_active            BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

  CONSTRAINT unique_tenant_server UNIQUE(customer_id, server_name),
  CONSTRAINT unique_hardware_serial UNIQUE(serial_number),
  CONSTRAINT unique_tenant_edge_server_id UNIQUE (customer_id, id),
  CONSTRAINT fk_edge_sites FOREIGN KEY (customer_id, site_id) REFERENCES sites(customer_id, id) ON DELETE SET NULL
);

CREATE TRIGGER trg_edge_updated_at BEFORE UPDATE ON edge_servers FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

### 1.13 Table: cameras (Absolute 3-Tier Namespaced Fixed Core Schema)

```sql
-- Primary Key is composite tuple: (customer_id, id).
-- Enforces customer_id -> site_id -> camera_id spatial namespace hierarchy at DB layer.

CREATE TABLE cameras (
  id                       UUID                  NOT NULL DEFAULT gen_random_uuid(),
  customer_id              UUID                  NOT NULL REFERENCES customers(id) ON DELETE CASCADE, -- Leading partition token
  site_id                  UUID                  NOT NULL,
  edge_server_id           UUID                  NOT NULL,
  camera_name              VARCHAR(255)          NOT NULL,
  location_description     VARCHAR(500),
  ip_address               INET                  NOT NULL,
  rtsp_url                 TEXT                  NOT NULL,
  onvif_uri                VARCHAR(500),
  onvif_profile            VARCHAR(5)            NOT NULL DEFAULT 'S',
  codec                    VARCHAR(20)           NOT NULL DEFAULT 'H264',
  bitrate_kbps             INTEGER               DEFAULT 2048,
  ptz_enabled              BOOLEAN               NOT NULL DEFAULT FALSE,
  audio_enabled            BOOLEAN               NOT NULL DEFAULT FALSE,
  recording_enabled        BOOLEAN               NOT NULL DEFAULT TRUE,
  retention_days           INTEGER               DEFAULT 30 CHECK (retention_days BETWEEN 1 AND 365),
  status                   VARCHAR(30)           NOT NULL DEFAULT 'UNKNOWN',
  is_active                BOOLEAN               NOT NULL DEFAULT TRUE,
  created_at               TIMESTAMPTZ           NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ           NOT NULL DEFAULT NOW(),

  PRIMARY KEY (customer_id, id), -- Composite index mapping
  CONSTRAINT unique_tenant_site_camera UNIQUE(customer_id, site_id, camera_name),
  CONSTRAINT unique_site_ip_block UNIQUE(site_id, ip_address),
  CONSTRAINT fk_cameras_sites FOREIGN KEY (customer_id, site_id) REFERENCES sites(customer_id, id) ON DELETE RESTRICT,
  CONSTRAINT fk_cameras_edge FOREIGN KEY (customer_id, edge_server_id) REFERENCES edge_servers(customer_id, id) ON DELETE RESTRICT
);

CREATE INDEX idx_cameras_tenant_spatial ON cameras(customer_id, site_id, status);
CREATE TRIGGER trg_cameras_updated_at BEFORE UPDATE ON cameras FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

### 1.14 Table: recordings (Multi-Tenant Fragment Index)

```sql
CREATE TABLE recordings (
  id                 UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id        UUID                NOT NULL REFERENCES customers(id) ON DELETE CASCADE, -- Tenant isolation flag
  site_id            UUID                NOT NULL REFERENCES sites(id) ON DELETE RESTRICT,
  camera_id          UUID                NOT NULL,
  recording_type     VARCHAR(30)         NOT NULL DEFAULT 'CONTINUOUS',
  start_time         TIMESTAMPTZ         NOT NULL,
  end_time           TIMESTAMPTZ,
  file_path          TEXT                NOT NULL, -- MinIO hot/warm S3 storage key
  file_size_bytes    BIGINT,
  storage_tier       VARCHAR(15)         NOT NULL DEFAULT 'HOT',
  checksum_sha256    CHAR(64),
  is_active          BOOLEAN             NOT NULL DEFAULT TRUE,
  created_at         TIMESTAMPTZ         NOT NULL DEFAULT NOW(),

  -- Enforces strict composite FK verification linking down to the camera master row
  FOREIGN KEY (customer_id, camera_id) REFERENCES cameras(customer_id, id) ON DELETE CASCADE,
  CONSTRAINT chk_rec_times CHECK (end_time IS NULL OR end_time > start_time),
  CONSTRAINT unique_tenant_object_key UNIQUE(customer_id, file_path)
);

CREATE INDEX idx_recordings_tenant_search ON recordings(customer_id, camera_id, start_time DESC);
```

### 1.15 Table: workspace_layouts (Custom Operator Configurations)

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

CREATE TRIGGER trg_layouts_updated_at BEFORE UPDATE ON workspace_layouts FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

### 1.16 PostgreSQL Native Row-Level Security (RLS) Configuration

```sql
-- Session Context Extractor function
CREATE OR REPLACE FUNCTION current_customer_id() RETURNS UUID
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN NULLIF(current_setting('app.current_customer_id', TRUE), '')::UUID;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$;

-- Enable RLS layers across core application transactional registries
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE licenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_module_entitlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_site_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE edge_servers ENABLE ROW LEVEL SECURITY;
ALTER TABLE cameras ENABLE ROW LEVEL SECURITY;
ALTER TABLE recordings ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspace_layouts ENABLE ROW LEVEL SECURITY;

-- Authoritative Tenant Verification Isolation Policies
CREATE POLICY p_sites_isolation ON sites USING (current_customer_id() IS NULL OR customer_id = current_customer_id());
CREATE POLICY p_licenses_isolation ON licenses USING (current_customer_id() IS NULL OR customer_id = current_customer_id());
CREATE POLICY p_cme_isolation ON customer_module_entitlements USING (current_customer_id() IS NULL OR customer_id = current_customer_id());
CREATE POLICY p_users_isolation ON users USING (current_customer_id() IS NULL OR customer_id = current_customer_id());
CREATE POLICY p_devices_isolation ON user_devices USING (current_customer_id() IS NULL OR customer_id = current_customer_id());
CREATE POLICY p_usp_isolation ON user_site_permissions USING (current_customer_id() IS NULL OR customer_id = current_customer_id());
CREATE POLICY p_edge_isolation ON edge_servers USING (current_customer_id() IS NULL OR customer_id = current_customer_id());
CREATE POLICY p_cameras_isolation ON cameras USING (current_customer_id() IS NULL OR customer_id = current_customer_id());
CREATE POLICY p_recordings_isolation ON recordings USING (current_customer_id() IS NULL OR customer_id = current_customer_id());
CREATE POLICY p_layouts_isolation ON workspace_layouts USING (current_customer_id() IS NULL OR customer_id = current_customer_id());
```

---

## Part 2 — MongoDB 7 PSS Replica Set

### 2.0 Global MongoDB Execution Invariants

```
RULE 1: Write Concern verification constraints for audit_logs require: { w: 'majority', j: true } configuration.
RULE 2: The audit_logs data collection layer is strictly APPEND-ONLY. Mutations (update, delete, drop) are banned.
RULE 3: Mongoose schemas enforce absolute strict validation definitions parameters (strict: true).
```

### 2.1 Collection: audit_logs (Append-Only System Log Store)

```typescript
@Schema({
  collection:  'audit_logs',
  timestamps:  false,
  strict:      true,
  versionKey:  false,
})
export class AuditLog {
  @Prop({ required: true, type: String, index: true })
  userId: string;

  @Prop({ required: true, type: String, index: true })
  action: string; // Format token: '{resource}.{verb}.{outcome}'

  @Prop({ required: true, type: String, index: true })
  customer_id: string; // Root multi-tenant tracking index

  @Prop({ required: true, type: String, index: true })
  siteId: string;

  @Prop({ required: true, type: String })
  ipAddress: string;

  @Prop({ type: Object, default: {} })
  metadata: Record<string, unknown>; // Encrypted/Sanitized structural context variables

  @Prop({ required: true, type: Date, index: true })
  timestamp: Date;

  @Prop({ required: true, type: String, unique: true })
  payloadHash: string; // Cryptographic signature verify key token
}

export const AuditLogSchema = SchemaFactory.createForClass(AuditLog);
AuditLogSchema.index({ customer_id: 1, timestamp: -1 });
```

### 2.2 Collection: ai_events_history (Interception Archival Storage)

```typescript
@Schema({
  collection: 'ai_events_history',
  timestamps: false,
  strict:     true,
  versionKey: false
})
export class AIEventHistory {
  @Prop({ required: true, type: String, index: true })
  customer_id: string; // Partitioning sharding element

  @Prop({ required: true, type: String, index: true })
  siteId: string;

  @Prop({ required: true, type: String, index: true })
  cameraId: string;

  @Prop({ required: true, type: String, index: true })
  eventClass: string; // Matches one of the 12 master core labels

  @Prop({ type: Object, default: {} })
  boundingBox: Record<string, number>; // JSON [x, y, w, h] coordinates vectors

  @Prop({ required: true, type: Number })
  confidence: number;

  @Prop({ type: Object, default: {} })
  metadata: Record<string, unknown>; // Extended frame signatures details

  @Prop({ required: true, type: Date, index: true })
  detectedAt: Date;

  // Automated 90 days hot auto-purging retention threshold parameters
  @Prop({ default: Date.now, type: Date, expires: '90d' })
  createdAt: Date;
}

export const AIEventHistorySchema = SchemaFactory.createForClass(AIEventHistory);
AIEventHistorySchema.index({ customer_id: 1, siteId: 1, detectedAt: -1 });
```

---

## Part 3 — Redis Cluster 7 Key-Space & Streams Contracts

### 3.0 Key-Space Conventions

```
# Core Session Cache Tokens
cust-{customer_id}:usr-{userId}:session:{sessionId}            ➔ JSON string containing mapping fields  (TTL: 8 Hours)
cust-{customer_id}:jwt:blacklist:{sessionId}                     ➔ "1" indicator block flag               (TTL: Volatile window)
cust-{customer_id}:site-{siteId}:cam:status:{cameraId}          ➔ Real-time camera hardware metrics logs (TTL: 120s)
cust-{customer_id}:site-{siteId}:rules:cache                    ➔ Warm rules engine variables execution  (TTL: 60s)
rate:login:ip:{ipAddress}                                       ➔ Request counters tracking ingress lock (TTL: 60s)
```

### 3.1 Partitioned Micro Event Bus Streams (At-Least-Once Delivery Execution)

```
Stream Key Namespace: vms:ai-event:{customer_id}:{site_id}
  - Publisher: External Ingestion Payload Webhook Adaptor loops.
  - Consumer Group: 'alarm-worker-group' instantiated inside event-workers pods.
  - Capacity Limits: MAXLEN 50000 approximate boundaries configurations.
  - Parameters fields structure:
      customer_id  STRING  Master Corporate Tenant Token Key
      siteId       STRING  Location identifier UUID
      cameraId     STRING  Target IP camera UUID node vector
      eventClass   STRING  Analytical class label matching the 12 master models catalog matrix
      boundingBox  STRING  JSON stringified coordinates vector payload
      confidence   STRING  Float metric tracker mapping inference results
      timestamp    STRING  Milliseconds unix epoch timestamp string

Stream Key Namespace: vms:recording-lifecycle
  - Publisher: C++ Media Core chunker instances on segment closure loops.
  - Consumer Group: 'recording-index-group' running inside background processes threads.
  - MAXLEN Bounds: 20000 entries.
  - Fields parameters:
      customer_id  STRING  Master Tenant token
      siteId       STRING  Location mapping key
      cameraId     STRING  Camera UUID token
      segmentId    STRING  UUID identifier generated by GStreamer graph nodes
      filePath     STRING  Canonical MinIO bucket object key reference path
      fileSize     STRING  Video capacity footprint in bytes units string
      state        STRING  Static terminal token string: 'CLOSED'
```

### 3.2 Real-time WebSocket Fan-Out Channels (Pub/Sub)

```
ws:alarm:{customer_id}:{siteId}  ➔ Real-time alert notifications triggers dispatched to ws-broadcaster pods
ws:camera:{customer_id}:{siteId} ➔ Hardware state modification logs streamed to authorized workstation screens
media:cmd:{customer_id}:{siteId} ➔ NestJS control plane commands routed straight to internal Media Core receivers
```
