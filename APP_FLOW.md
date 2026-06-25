# APP_FLOW.md — System Execution Sequences

**VMS Enterprise | Phase 1 SaaS Revision | SRS v5.1 Baseline (Shared B2B SaaS Edition)**
**Classification:** Internal / Confidential

---

## Overview

This document defines the authoritative end-to-end multi-layered data lifecycle sequences for Phase 1 SaaS features. Every flow maps exact component boundaries, protocol transitions, cross-owner failure modes, and timing contracts. These sequences serve as the reference for system implementation, automated QA test case authoring, and architecture review gates.

Three primary flows are covered:

1. User Session Onboarding & Tenant Token Containment
2. Local Multicast Ingest & Edge Loopback Processing
3. Asynchronous Multi-Tenant Push Alarm Loop

---

## Flow 1 — User Session Onboarding

### 1.1 Sequence Overview

```
Client Platform UI (React Portal / Solo Flutter App)
→ TLS 1.3 Termination & HSTS Enforcement (NGINX Ingress)
→ NestJS API Gateway (Multi-tenant process-isolated container)
→ Auth Service Layer (JWT issuance + Redis sharded session registration)
→ Patroni PostgreSQL 16 (Composite tenant-scoped verification + user profile fetch)
➔ HashiCorp Vault Cluster (mfa_secret_ref resolution + JWT signing key cache)
→ Redis 7 Cluster (Session mapping + sliding window rate-limit checks)
→ MongoDB 7 PSS (Awaited immutable security audit write)
→ Client UI Container (Access token inside volatile memory + HttpOnly refresh cookie)
```

### 1.2 Step-by-Step Execution

#### Step 1 — TLS 1.3 Handshake at NGINX Ingress

```
Client Container Workspace                     NGINX Ingress Controller
|                                                        |
|---- ClientHello (TLS 1.3 parameters check) ----------->|
|<--- ServerHello + Cryptographic Certificate -----------|
|     (Automated lease tracking via cert-manager + Vault)|
|---- Finished Handshake (Volatile session keys) ------->|
|<--- HTTP/2 Stream Channel Established -----------------|

Constraints:

* Legacy Protocols: TLS 1.2 and below are explicitly REJECTED (ssl_protocols TLSv1.3 only).
* Authorized Cipher Suites: TLS_AES_256_GCM_SHA384, TLS_CHACHA20_POLY1305_SHA256 only.
* Browser Header Protection: Strict-Transport-Security: max-age=31536000; includeSubDomains.
* Internal Security: Mutual TLS (mTLS) with Vault-issued certificates is mandatory for service-to-service communication paths.
```

#### Step 2 — Request Routing to Process-Isolated API Gateway

```
NGINX Ingress → Kubernetes Service (vms-api-gateway) → Pod (api-gateway container)

NGINX upstream configuration profile:
upstream vms_api {
  server vms-api-gateway.vms-control-plane.svc.cluster.local:3000;
  keepalive 64;
}
location /api/v5/ {
  proxy_pass http://vms_api;
  proxy_http_version 1.1;
  proxy_set_header Connection "";
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Request-ID $request_id;
}

Pillar 4 Process Isolation Guarantee:

* api-gateway pod: Handles public HTTP REST endpoints and WebSocket ingress traffic exclusively.
* event-workers pod: Processes async stream background workers and rules evaluations exclusively.
* ws-broadcaster pod: Manages real-time WebSocket state fan-out routines exclusively.
* Separate Deployments with dedicated event loops and independent resource quotas prevent workers backpressure from stalling public API traffic.
```

#### Step 3 — Rate Limit Check (Redis Sliding Window)

```
api-gateway microservice receives incoming: POST /api/v5/auth/login

Before any relational database lookups are executed:
Key Namespace Target: rate:login:ip:{clientIP}
Operations Atomic Flow: INCR + EXPIRE (if key initialization occurs)

If execution count passes 5 queries within a 60-second window:
→ Return an immediate HTTP 429 Too Many Requests intercept.
→ Inject Header: Retry-After: {seconds_until_reset}.
➔ Write MongoDB Audit: { action: 'auth.ratelimit.hit', ipAddress, timestamp }.
→ Terminate request flow immediately to protect database connection pools.
```

#### Step 4 — Tenant-Scoped Credential Verification (PostgreSQL)

```
AuthService.login(dto: LoginDto):

Tenant-Scoped Query Execution (Eliminates Multi-Tenant Account Lockout Exploits):
SELECT user_id, customer_id, email, password_hash, base_role,
       mfa_secret_ref, failed_login_count, locked_until, is_active
FROM users
WHERE customer_id = $1 AND email = $2
LIMIT 1;

Parameters Tuple: [dto.customer_id, dto.email]
Connection: Multi-tenant pooled client mesh, SSL enforced.
Timeout Threshold: 3000ms.

Case A — User or Tenant Context Not Found:
→ Execute a dummy bcrypt.compare() block to neutralize timing oracle side-channel attacks.
→ Increment Redis connection failure tracking counter for target IP.
→ Return HTTP 401 Unauthorized with generic message: "Invalid credentials".
➔ Commit Append-Only MongoDB Log: { action: 'auth.login.failed', ipAddress }.

Case B — Tenant Account Locked:
→ Validate structural condition: locked_until IS NOT NULL AND locked_until > NOW().
→ Return HTTP 401 Unauthorized: "Account temporarily locked".

Case C — Account Inactive:
→ Check: is_active = FALSE.
→ Return HTTP 401 Unauthorized with generic message (do not reveal reason).

Case D — Password Mismatch:
→ Compare password: bcrypt.compare(dto.password, user.password_hash) = false.
→ UPDATE users
    SET failed_login_count = failed_login_count + 1,
        locked_until = CASE WHEN failed_login_count + 1 >= 5
          THEN NOW() + INTERVAL '30 minutes' ELSE NULL END
    WHERE customer_id = $1 AND user_id = $2;
  → Return HTTP 401 Unauthorized with generic message: "Invalid credentials".

Case E — Password Match, MFA Verification Required:
→ Compare password: bcrypt.compare(dto.password, user.password_hash) = true.
→ Extract mfa_secret_ref from relational row; verify token parameters asynchronously with HashiCorp Vault.
→ Invoke Vault Secrets Engine to decrypt enrollment payload via Raft secure backends.
→ If totpCode is invalid or missing: Return HTTP 401 Unauthorized "Invalid MFA code".
→ If valid: Proceed straight to token generation loops.
```

#### Step 5 — JWT Signing Key Fetch from Vault

```
Vault Cluster Secrets Ingestion:
Path Target: secret/data/vms/jwt-signing-key
Method: GET request cached at boot instance, rotated in 3600s intervals.
Authentication: Kubernetes token parameters verification via Vault agent sidecar.
Constraint: Signing keys reside strictly inside volatile service processes memory; plaintext keys are banned from filesystem containers.
```

#### Step 6 — JWT Access Token Issuance

```typescript
const sessionId = randomUUID();
const accessToken = jwt.sign(
  {
    sub: user.user_id,
    customer_id: user.customer_id, // Root Multi-Tenant Token Injection
    email: user.email,
    role: user.base_role,
    siteId: user.site_id,
    sessionId: sessionId,
  },
  vaultSigningKey,
  {
    algorithm: "HS256",
    expiresIn: "8h",
    issuer: "vms-api-gateway",
    audience: "vms-clients",
  },
);
// Token Containment Constraint: Access tokens are returned strictly within the JSON response body.
// JavaScript engines are blocked from saving material inside localStorage or sessionStorage.
```

#### Step 7 — Refresh Token Issuance (PostgreSQL + HttpOnly Cookie)

```typescript
const rawRefreshToken = randomBytes(64).toString('hex');
const tokenHash       = createHash('sha256').update(rawRefreshToken).digest('hex');
const expiresAt       = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

INSERT INTO refresh_tokens (user_id, customer_id, token_hash, expires_at, ip_address, user_agent)
VALUES ($1, $2, $3, $4, $5, $6); // Root customer_id sharding mapped securely to user tracking

res.cookie('vms_refresh', rawRefreshToken, {
  httpOnly:  true,
  secure:    true,
  sameSite:  'strict',
  maxAge:    30 * 24 * 60 * 60 * 1000,
  path:      '/api/v5/auth/refresh',
});
```

#### Step 8 — Sharded Redis Session Registration

```
Key Pattern Layout:   cust-{customer_id}:usr-{user_id}:session:{sessionId}
Value Payload:        { userId, customer_id, role, siteId, issuedAt }
TTL Expiry Boundary:  28800 seconds (8 Hours — perfectly matches JWT access token window)
Command Execution:    SET cust-{customer_id}:usr-{user_id}:session:{sessionId} {json} EX 28800

Purpose:
  - Enables immediate, targeted session revocation patterns.
  - NestJS JwtStrategy interceptors validate this key's presence before allowing API gateway execution.
```

#### Step 9 — Durability-Guaranteed MongoDB Audit Write

```javascript
// Strict Write-Concern: { w: 'majority', j: true } ensures transaction durability
await db.collection("auditLogs").insertOne({
  userId: user.user_id,
  customer_id: user.customer_id, // Root Tenant Indexing
  action: "auth.login.success",
  resourceType: "User",
  resourceId: user.user_id,
  siteId: user.site_id,
  ipAddress: clientIP,
  userAgent: userAgent,
  metadata: { role: user.base_role, sessionId },
  timestamp: new Date(),
  payloadHash: sha256(
    `${user.user_id}:${user.customer_id}:auth.login.success:${timestamp}`,
  ),
});
```

#### Step 10 — Reset Failed Login Counter

```sql
UPDATE users
SET failed_login_count = 0,
    locked_until = NULL,
    last_login_at = NOW()
WHERE customer_id = $1 AND user_id = $2;
```

#### Step 11 — Client Response & Token Containment

```
SaaS React Client Portal Execution (Vivek Ownership):
  - Response parameters (accessToken + profile metadata) load straight to the Zustand volatile memory store.
  - Browser handles the vms_refresh cookie automatically via strict HttpOnly configurations.
  - Tab close actions drop the Zustand store context instantly, purging the accessToken from the client lifecycle.

SaaS Cross-Platform Flutter Mobile Client Execution (Sagar Solo Track Lead):
  - Response payload access token hydrates the thread-isolated AuthBloc memory space.
  - Secure persistent token containment: if long-term offline parameters are active, the refresh token is encrypted and written straight to native hardware cryptoprocessors using Keystore-backed EncryptedSharedPreferences (Android) and the Secure Enclave Keychain mesh (iOS).
```

### 1.3 Token Refresh Flow

```
Trigger Boundary: React Query background hydration layer or HTTP 401 intercept responses.

Sagar's Flutter Mobile RefreshLock Blueprint (Eliminates Thread Hydration Race Conditions):
  if (_refreshCompleter != null) {
    await _refreshCompleter!.future; // Block concurrent executions — wait for ongoing rotation
    retry original request;
    return;
  }
  _refreshCompleter = Completer<void>();
  try {
    POST /api/v5/auth/refresh (cookie transported automatically via Dio Client)
    → Ingest new access token into volatile BLoC space
    _refreshCompleter!.complete();
    retry original request;
  } catch (e) {
    _refreshCompleter!.completeError(e);
    emit logout event sequence;
  } finally {
    _refreshCompleter = null;
  }

NestJS Refresh Logic Execution Gateway:
  1. Read incoming vms_refresh cookie; parse and hash token via SHA-256.
  2. Query database checking matching fields: WHERE customer_id = $1 AND token_hash = $2 AND revoked = FALSE
  3. Execute transactional rotation: mark historical row record as revoked, insert newly rotated token tracking block.
  4. Issue a new access token containing updated session structures and update the Redis cache layer.
```

### 1.4 Session Revocation Flow

```
Admin revokes target user session:
  DELETE /api/v5/users/{userId}/sessions/{sessionId} [ADMIN role required, tenant-scoped]

NestJS Engine Actions:
  1. DEL cust-{customer_id}:usr-{userId}:session:{sessionId} (Redis — immediate systemic breakout)
  2. UPDATE refresh_tokens SET revoked = TRUE WHERE customer_id = $1 AND user_id = $2 AND session_id = $3
  3. Commit entry to MongoDB audit logs collection tracking execution metadata.
```

---

## Flow 2 — Local Multicast Ingest & Edge Loopback Processing

### 2.1 Sequence Overview

```
IP Hardware Camera (ONVIF Profile T/M Network Core)
  → Local L2/L3 Network Switch (IGMPv3 Snooping Hardware Enforcement)
  → LAN Multicast Group Pipeline (Single physical stream, parallel local subscribers)
      ├── Desktop Video Canvas Client / Linux Video Wall Node (Live WebGPU direct canvas render)
      └── C++ Edge Agent Appliance (Loopback proxy subscriber module → continuous chunking proxy)
              → WAN Encryption Tunnel (TLS 1.3 High-Band Ingest Pipeline ≥ 100 Mbps)
              → C++ Cloud Media Core (GStreamer fragment pipelines cluster node)
              → MinIO Object Storage (Encrypted, customer_id sharded fMP4 buckets layout)
              → Redis Stream Queue (vms:recording-lifecycle event payload)
              → NestJS Event Workers Pod (Asynchronous database recording index creation)
```

### 2.2 ONVIF Camera Auto-Discovery Protocols

#### Step 1 — Edge Agent WS-Discovery Probe

```
Edge Agent appliance loop boot ➔ ONVIFDiscovery::startDiscoveryLoop()

Protocol Standard: SOAP over UDP multicast interface lines.
Target Multicast Address Boundary: 239.255.255.250:3702.
Scan Trigger Interval: 60 seconds (Configured dynamically via Vault properties mapping).
Scanning Boundary: Subnets extracted straight from Vault parameters; zero cleartext properties files.
```

#### Step 2 — ProbeMatch Extraction & Sharded Ingestion

```
Device returns validated SOAP ProbeMatch metadata vectors to Edge appliance.

Edge Agent Deduplication Engine:
  Query localized SQLite node: SELECT uuid FROM discovered_devices WHERE customer_id = ? AND uuid = ?
  If entry is unrecognized: INSERT local table, then initialize mTLS gRPC upload tunnel to Control Plane.

mTLS Protected Ingestion Path: POST /api/v5/cameras/discovered
  Payload Structure:
  {
    "customer_id":  "customer-uuid-v4-token", // Explicit Tenancy Identifier Validation
    "siteId":       "site-uuid-v4-token",
    "ipAddress":    "192.168.10.12",
    "onvifProfile": "M",
    "rtspUrl":      "rtsp://192.168.10.12:554/live/stream0",
    "xaddrs":       ["http://192.168.10.12/onvif/device_service"],
    "uuid":         "urn:uuid:hardware-axis-token-v5",
    "manufacturer": "Axis Communications",
    "model":        "Q1615-E"
  }
```

#### Step 3 — Composite Primary Key Database Registration

```sql
-- NestJS CameraService.registerDiscovered() execution
INSERT INTO cameras (customer_id, site_id, camera_id, name, ip_address, rtsp_url, onvif_profile,
                     codec, status, ptz_capable, created_at, updated_at)
VALUES ($1, $2, gen_random_uuid(), $3, $4, $5, $6, 'H264', 'CONNECTED', $7, NOW(), NOW())
ON CONFLICT (customer_id, site_id, ip_address) DO UPDATE
  SET onvif_profile = EXCLUDED.onvif_profile,
      rtsp_url      = EXCLUDED.rtsp_url,
      updated_at    = NOW();

-- Composite Primary Key Mapping Constraint Enforced: (customer_id, site_id, camera_id)
-- Standalone inserts missing the root-level customer_id are dropped at database layer.
```

#### Step 4 — Control Plane Dynamic Resource Allocation

```
NestJS Control Gate ➔ Redis Pub/Sub Pipe ➔ Hardened Edge Appliance Subscriber

Target Channel: edge:config:{customer_id}:{site_id}:{server_id}
Message Payload: {
  "action":          "ASSIGN_CAMERA",
  "customer_id":     "{customer_id}",
  "siteId":          "{site_id}",
  "cameraId":        "{camera_id}",
  "onvifProfile":    "M",
  "multicastGroup":  "239.10.12.5",
  "multicastPort":   5004,
  "srtp": {
    "keyVaultRef": "secret/data/vms/srtp/{customer_id}/{site_id}/{camera_id}",
    "rotationInterval": "1800s"
  }
}
```

### 2.3 IGMPv3 Snooping Hardware Enforcement at Switch Layer

- Customer local switch network infrastructure must enable hardware-level IGMPv3 Snooping on all operational streaming VLANs.
- A local Querier engine issues network validation signals; the Edge appliance maps socket bindings via strict kernel-level `IP_ADD_MEMBERSHIP` commands.
- Stream Overhead Elimination: IP cameras emit exactly ONE physical stream onto the switch plane. The Edge Agent acts as a local loopback listener proxying recording fragments securely to the cloud, completely preventing double-streaming bandwidth leaks.
- Local Transport Payload Encryption: Frame chunks on the LAN pass through SRTP transformations using AES-128-CM keys fetched from the HashiCorp Vault intermediate engine.

### 2.4 C++ Edge Agent Multicast Loopback Proxy Architecture

#### Step 5 — Join Multicast Group as Subscriber

```cpp
// MulticastLoopbackProxy::subscribe() execution mapping
int sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
int reuse = 1;
setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));

sockaddr_in addr{};
addr.sin_family      = AF_INET;
addr.sin_addr.s_addr = htonl(INADDR_ANY);
addr.sin_port        = htons(multicastPort);
bind(sock, (sockaddr*)&addr, sizeof(addr));

ip_mreq mreq{};
mreq.imr_multiaddr.s_addr = inet_addr(multicastGroup.c_str());
mreq.imr_interface.s_addr = htonl(INADDR_ANY);
setsockopt(sock, IPPROTO_IP, IP_ADD_MEMBERSHIP, &mreq, sizeof(mreq));
```

#### Step 6 — GStreamer Fragmented Segment Chunker Pipeline

```cpp
// Build GStreamer continuous fMP4 segmenting chunker graphs
std::string pipeline_desc =
  "udpsrc multicast-group=" + multicastGroup + " port=" + std::to_string(multicastPort) +
  " caps=\"application/x-rtp, media=video, clock-rate=90000, encoding-name=H264\" "
  "! rtpjitterbuffer latency=200 "
  "! rtph264depay ! h264parse ! nvh264dec " // Hardware accelerated rendering pipelines
  "! videoscale ! videoconvert ! x264enc tune=zerolatency key-int-max=30 "
  "! splitmuxsink location=/var/vms/anr/" + customerId + "/" + siteId + "/" + cameraId + "/%Y%m%d_%H%M%S.fmp4 "
  "  max-size-time=900000000000 " // Strict 15-minute intervals in nanoseconds
  "  muxer-factory=mp4mux muxer-properties=\"fragment-duration=1000\" "; // fMP4 ISO BMFF chunks

GstElement* pipeline = gst_parse_launch(pipeline_desc.c_str(), &error);
gst_element_set_state(pipeline, GST_STATE_PLAYING);
```

#### Step 7 — Partitioned Multi-Tenant Cloud Storage Upload

```cpp
void MinIOUploader::uploadSegment(
    const std::string& customerId,
    const std::string& siteId,
    const std::string& cameraId,
    const std::string& localPath)
{
  // Master Multi-Tenant Storage Path Naming Convention
  std::string date      = currentDateISO();
  std::string timestamp = currentTimestampEpoch();
  std::string minioKey  = "recordings/" + customerId + "/" + siteId + "/" + cameraId + "/" + date + "/" + timestamp + ".fmp4";

  Aws::S3::Model::CreateMultipartUploadRequest createReq;
  createReq.SetBucket("vms-hot");
  createReq.SetKey(minioKey);
  createReq.SetContentType("video/mp4");
  createReq.SetStorageClass(Aws::S3::Model::StorageClass::STANDARD);

  auto createResult = s3Client_.CreateMultipartUpload(createReq);
  std::string uploadId = createResult.GetResult().GetUploadId();

  // Execute chunked streams upload with automated exponential backoff loops
  // Upon validation success, emit tracking metadata payload to the central micro event bus
  redis_.xadd("vms:recording-lifecycle", {
    {"customer_id", customerId},
    {"siteId",      siteId},
    {"cameraId",    cameraId},
    {"segmentId",   generateUUID()},
    {"filePath",    minioKey},
    {"fileSize",    std::to_string(fileSize)},
    {"state",       "CLOSED"},
    {"timestamp",   nowISO8601()}
  });
}
```

#### Step 8 — NestJS Asynchronous Ingestion & Relational Database Writing

```typescript
// apps/event-workers/src/recording/recording-lifecycle.consumer.ts execution loop
@Injectable()
export class RecordingLifecycleConsumer implements OnApplicationBootstrap {
  private readonly STREAM = "vms:recording-lifecycle";
  private readonly GROUP = "recording-index-group";
  private readonly CONSUMER = `worker-${process.env.HOSTNAME}`;

  async onApplicationBootstrap(): Promise<void> {
    await this.ensureConsumerGroup();
    this.startConsumeLoop();
  }

  private async startConsumeLoop(): Promise<void> {
    while (true) {
      // Claim pending messages older than 30s to execute crash recovery thresholds
      const pending = await this.redis.xautoclaim(
        this.STREAM,
        this.GROUP,
        this.CONSUMER,
        30000,
        "0-0",
        "COUNT",
        50,
      );
      if (pending[1].length > 0) {
        await this.processBatch(pending[1]);
      }

      // Ingest new messages batch from event bus
      const messages = await this.redis.xreadgroup(
        "GROUP",
        this.GROUP,
        this.CONSUMER,
        "COUNT",
        50,
        "BLOCK",
        2000,
        "STREAMS",
        this.STREAM,
        ">",
      );
      if (messages?.[0]?.[1]?.length) {
        await this.processBatch(messages[0][1]);
      }

      // Mandatory event loop micro-task yield blocks libuv thread pool starvation under load
      await new Promise<void>((resolve) => setImmediate(resolve));
    }
  }

  private async insertRecordingIndex(
    payload: RecordingLifecyclePayload,
  ): Promise<void> {
    // Inserts records using full composite sharding parameters
    await this.dataSource.query(
      `INSERT INTO recordings
         (segment_id, customer_id, site_id, camera_id, ingest_type, started_at, storage_path, storage_tier, retention_days)
       VALUES ($1, $2, $3, $4, $5, $6, $7, 'HOT', 30)
       ON CONFLICT DO NOTHING`,
      [
        payload.segmentId,
        payload.customer_id,
        payload.siteId,
        payload.cameraId,
        "CONTINUOUS",
        new Date(parseInt(payload.timestamp)),
        payload.filePath,
      ],
    );
  }
}
```

### 2.5 WAN Outage Failure — Localized ANR Caching Loop

- **Failure Detection State:** Hardened Edge appliance monitors mTLS gRPC connection streams with the control core every 10 seconds. Missing 3 sequential heartbeats (30 seconds) triggers an immediate system WAN_LOSS status declaration.
- **ANR Local Isolation:** The appliance isolates cloud upload pipelines instantly, continuing local frame writing loops inside protected storage disks: `/var/vms/anr/{customer_id}/{site_id}/{camera_id}/`.
- **Off-Peak Dynamic Replication:** Upon network line restoration, backends trigger an asynchronous replenishment sync loop. Schedulers extract records from the local SQLite engine (`WHERE synced_flag = FALSE`), transferring data chunks on off-peak hours (e.g., 02:00–06:00) capped at an 80 Mbps ceiling to protect live ingest paths.

---

## Flow 3 — Asynchronous Push Alarm Loop

### 3.1 Sequence Overview

```
AIEYE Deep Learning Inference Cluster (12 Master Core Engines Operating As-Is)
  ➔ Public Ingestion Webhook Event Gateway Gateway Interception
  → Redis Streams: vms:ai-event:{customer_id}:{site_id} (Tenant partitioned queues)
  → NestJS Event Workers Pod (Sovereign event loop container process isolation)
  → Rules Engine Condition Verification (Asynchronous verification, zero API thread blockage)
  → Relational Alarm Database Matrix Creation (Patroni PostgreSQL 16 row mapping, execution ≤ 2s)
  → WebSocket Broadcaster Microservice (WSS secure real-time push to authorized clients UI)
  → Solo Mobile Push Delivery Engine (FCM / APNs secure transport routing execution ≤ 5s)
```

### 3.2 AI Cluster Event Webhook Payloads Publication

```python
# Ingest loop interfacing with running AIEYE inference engines webhook signals
# Vivek owns consumption engine; Shubham + Saurabh own Media Core triggers compliance

import redis
import json
import time

r = redis.Redis(host='redis-cluster.vms-data.svc.cluster.local', port=6379)

def publish_ai_webhook_alert(detection: dict):
    customer_id = detection['customer_id'] # Global Multi-Tenant Tracking Token Key
    site_id     = detection['siteId']

    # STRICT COMPOSITE PARTITIONING — Banned single shared channel queues
    stream_key  = f"vms:ai-event:{customer_id}:{site_id}"

    payload = {
        'customer_id': customer_id,
        'siteId':      detection['siteId'],
        'cameraId':    detection['cameraId'],
        'eventClass':  detection['class'],      # Maps to one of the 12 primary analytical models
        'trackingId':  detection['trackingId'],
        'boundingBox': json.dumps(detection['bbox']),   # Normalized [x, y, w, h] vector
        'confidence':  str(detection['confidence']),
        'metadata':    json.dumps(detection.get('metadata', {})),
        'timestamp':   str(int(time.time() * 1000)),   # Milliseconds Epoch
    }

    # Atomic insertion capped via strict MAXLEN bounds to block resource leaks
    r.xadd(stream_key, payload, maxlen=10000, approximate=True)
```

### 3.3 NestJS Event Workers — Partitioned Stream Consumption Layer

```typescript
// apps/event-workers/src/alarm/ai-event.consumer.ts execution profile
@Injectable()
export class AIEventConsumer implements OnApplicationBootstrap {
  // CRITICAL: This executes strictly inside the process-isolated EVENT-WORKERS pod container
  // Banned execution within the api-gateway thread to ensure zero public API latency interference
  private readonly GROUP = "alarm-worker-group";
  private readonly CONSUMER = `alarm-worker-${process.env.HOSTNAME}`;

  async onApplicationBootstrap(): Promise<void> {
    // Collect active multi-tenant mappings index from the database memory cache
    const activeTenantsProfiles =
      await this.siteRegistry.getActiveTenantMappings();

    // Spawns parallel consumer execution instances sharded cleanly across tenant streams
    await Promise.all(
      activeTenantsProfiles.map((profile) =>
        this.consumeTenantStream(profile.customer_id, profile.site_id),
      ),
    );
  }

  private async consumeTenantStream(
    customer_id: string,
    siteId: string,
  ): Promise<void> {
    const streamKey = `vms:ai-event:${customer_id}:${siteId}`;
    await this.ensureConsumerGroup(streamKey);

    while (true) {
      // PHASE 1: Invoke XCLAIM auto-claim loops older than 30s to resolve background worker faults
      const claimed = await this.redis.xautoclaim(
        streamKey,
        this.GROUP,
        this.CONSUMER,
        30000,
        "0-0",
        "COUNT",
        50,
      );
      if (claimed[1]?.length) {
        await this.processBatch(customer_id, siteId, claimed[1]);
      }

      // PHASE 2: Ingest fresh incoming alert tokens batch
      const result = await this.redis.xreadgroup(
        "GROUP",
        this.GROUP,
        this.CONSUMER,
        "COUNT",
        50,
        "BLOCK",
        1000,
        "STREAMS",
        streamKey,
        ">",
      );
      const entries = result?.[0]?.[1];
      if (entries?.length) {
        await this.processBatch(customer_id, siteId, entries);
      }

      // Releases execution loop explicitly to give thread processing back to I/O callbacks
      await new Promise<void>((resolve) => setImmediate(resolve));
    }
  }

  private async processBatch(
    customer_id: string,
    siteId: string,
    entries: [string, string[]][],
  ): Promise<void> {
    for (const [messageId, rawFields] of entries) {
      try {
        const event = this.parseAIEvent(rawFields);
        await this.rulesEngine.evaluate(customer_id, siteId, event);
        await this.redis.xack(
          `vms:ai-event:${customer_id}:${siteId}`,
          this.GROUP,
          messageId,
        );
      } catch (err) {
        this.logger.error(
          `Failed execution parsing alert tracking sequence token ${messageId}`,
          err,
        );
      }
    }
  }
}
```

### 3.4 Rules Engine Evaluation Microservice

```typescript
// apps/event-workers/src/alarm/rules-engine.service.ts
// CRITICAL: Runs in isolated event-workers pod — never on API Gateway thread

@Injectable()
export class RulesEngineService {
  constructor(
    private readonly redis: Redis,
    private readonly rulesRepository: RulesRepository,
    private readonly alarmService: AlarmService,
    private readonly notificationService: PushNotificationService,
    private readonly metrics: MetricsService,
  ) {}

  async evaluate(
    customer_id: string,
    siteId: string,
    event: AIEvent,
  ): Promise<void> {
    // Load active rules for tenant site from Redis cache (warm cache, 60s TTL)
    const cacheKey = `rules:active:${customer_id}:${siteId}`;
    let rulesJson = await this.redis.get(cacheKey);

    if (!rulesJson) {
      const rules = await this.rulesRepository.findActiveBySite(
        customer_id,
        siteId,
      );
      rulesJson = JSON.stringify(rules);
      await this.redis.set(cacheKey, rulesJson, "EX", 60);
    }

    const rules: WorkflowRule[] = JSON.parse(rulesJson);

    for (const rule of rules) {
      if (
        this.matchesTrigger(rule, event) &&
        this.matchesFilters(rule, event)
      ) {
        await this.executeActions(customer_id, rule, event);
      }
    }
  }

  private matchesTrigger(rule: WorkflowRule, event: AIEvent): boolean {
    const triggerMap: Record<string, string[]> = {
      motion: ["motion"],
      person: ["person"],
      vehicle: ["vehicle"],
      alpr_hit: ["alpr_hit"],
      camera_offline: ["camera_offline"],
    };
    return (
      triggerMap[rule.triggerEventClass]?.includes(event.eventClass) ?? false
    );
  }

  private matchesFilters(rule: WorkflowRule, event: AIEvent): boolean {
    const filters = rule.filterConditions;
    if (filters.cameraId && filters.cameraId !== event.cameraId) return false;
    if (filters.minConfidence && event.confidence < filters.minConfidence)
      return false;
    if (filters.timeOfDay) {
      const hour = new Date().getHours();
      if (hour < filters.timeOfDay.from || hour > filters.timeOfDay.to)
        return false;
    }
    return true;
  }

  private async executeActions(
    customer_id: string,
    rule: WorkflowRule,
    event: AIEvent,
  ): Promise<void> {
    for (const action of rule.actionPipelines) {
      switch (action.type) {
        case "CREATE_ALARM":
          await this.alarmService.create(rule, event, action.priority);
          break;
        case "START_RECORDING":
          // Multi-tenant sharded media command routing channel
          await this.redis.publish(
            `media:cmd:${customer_id}:${event.siteId}`,
            JSON.stringify({
              action: "START_RECORDING",
              cameraId: event.cameraId,
              customer_id,
              siteId: event.siteId,
            }),
          );
          break;
        case "SEND_NOTIFICATION":
          await this.notificationService.dispatchAlarmPushNotification(
            rule,
            event,
          );
          break;
      }
    }
  }
}
```

### 3.5 Relational Alarm Database Creation Sequence

```typescript
// apps/event-workers/src/alarm/alarm.service.ts relational row injection
async create(rule: WorkflowRule, event: AIEvent, priority: 'P1'|'P2'|'P3'|'P4'): Promise<Alarm> {
  const t0 = Date.now();

  // Commits record enforcing strict root row-level logical multi-tenant tracking keys
  const alarm = await this.dataSource.query(
    `INSERT INTO alarms (alarm_id, customer_id, rule_id, site_id, camera_id, severity, payload, status, created_at, updated_at)
     VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, 'ACTIVE', NOW(), NOW())
     RETURNING alarm_id, customer_id, site_id, severity, created_at`,
    [
      event.customer_id, // Root Multi-Tenant Data Isolation Partitioning Key
      rule.ruleId,
      event.siteId,
      event.cameraId,
      priority,
      JSON.stringify({ eventClass: event.eventClass, boundingBox: event.boundingBox, confidence: event.confidence }),
    ]
  );

  this.metrics.histogram('alarm.create.duration_ms').observe(Date.now() - t0); // Performance histogram metrics tracking

  // Append entry straight to the MongoDB immutable audit collection logs
  await this.auditService.write({
    userId: 'system_core_gateway',
    action: 'alarm.created',
    resourceType: 'Alarm',
    resourceId: alarm[0].alarm_id,
    siteId: event.siteId,
    metadata: { customer_id: event.customer_id, priority, eventClass: event.eventClass }
  });

  // Signal WebSocket Broadcaster pod via Redis pub/sub layer async channel hooks
  await this.redis.publish(
    `ws:alarm:${event.customer_id}:${event.siteId}`,
    JSON.stringify({ type: 'ALARM_CREATED', alarmId: alarm[0].alarm_id, severity: priority, timestamp: alarm[0].created_at })
  );

  return alarm[0];
}
```

### 3.6 WebSocket Broadcaster Fan-Out Routines

```typescript
// apps/ws-broadcaster/src/alarm/alarm-broadcaster.service.ts
// SEPARATE KUBERNETES DEPLOYMENT from api-gateway and event-workers

@Injectable()
export class AlarmBroadcasterService implements OnApplicationBootstrap {
  constructor(
    private readonly redisSub: Redis,
    private readonly wsRegistry: WebSocketRegistryService,
    private readonly logger: Logger,
  ) {}

  async onApplicationBootstrap(): Promise<void> {
    // Subscribe to alarm pub/sub channel for all tenants and sites dynamically
    await this.redisSub.psubscribe("ws:alarm:*:*");

    this.redisSub.on("pmessage", (_pattern, channel, message) => {
      const parts = channel.split(":");
      const customer_id = parts[2];
      const siteId = parts[3];
      const payload = JSON.parse(message);
      this.broadcastToSite(customer_id, siteId, payload);
    });
  }

  private broadcastToSite(
    customer_id: string,
    siteId: string,
    payload: AlarmPayload,
  ): void {
    // WebSocket connections scoped and mapped by customer_id and siteId
    // Ensures absolute tenant isolation at the WebSocket push layer
    const connections = this.wsRegistry.getConnections(customer_id, siteId);

    for (const ws of connections) {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(
          JSON.stringify({
            event: "alarm",
            data: payload,
          }),
        );
      }
    }
  }
}
```

### 3.7 Solo Cross-Platform Mobile Push Notification Execution Pipeline

```typescript
// apps/event-workers/src/notification/push-notification.service.ts background engine
@Injectable()
export class PushNotificationService {
  // Triggered from RulesEngine action: SEND_NOTIFICATION execution
  // Processes alerts completely outside of the api-gateway thread to block container latency stalls

  async dispatchAlarmPushNotification(
    alarm: Alarm,
    userId: string,
  ): Promise<void> {
    const activeTargetHardwareTokens = await this.getUserDeviceTokens(userId);

    for (const device of activeTargetHardwareTokens) {
      if (device.platform === "android") {
        await this.executeFirebaseChannelPush(device.token, alarm);
      } else if (device.platform === "ios") {
        await this.executeAppleAPNsChannelPush(device.token, alarm);
      }
    }
  }

  private async executeFirebaseChannelPush(
    token: string,
    alarm: Alarm,
  ): Promise<void> {
    await admin.messaging().send({
      token,
      notification: {
        title: `Critical Alarm — ${alarm.severity}`,
        body: `Tenant Security Event Verified`,
      },
      data: {
        alarmId: alarm.alarm_id,
        customer_id: alarm.customer_id,
        siteId: alarm.site_id,
        type: "ALARM",
      },
      android: { priority: "high", ttl: 60000 }, // Low 60s TTL ensures stale alerts expire automatically
    });
  }
}

// System End-to-End Timing Budget Target Constraints Verification Map:
//   AI Webhook Interception ➔ Redis stream push:      ~10ms
//   Redis xreadgroup Batch Ingestion layer:           ≤1000ms (1s hard blocking ceiling)
//   Workflow Rules Engine Evaluation:                 ~20ms
//   Relational Alarm row INSERT processing:           ~50ms (Target metrics <= 100ms)
//   Redis publish to ws-broadcaster instances:         ~5ms
//   WebSocket fan-out push to web operator screen:     ~10ms
//   FCM/APNs secure transport to Sagar's mobile core: ≤2000ms
//   ──────────────────────────────────────────────────────────────────────────────────────────
//   Total Multi-Tenant Ingestion Path Latency P95 Ceiling: ≤5000ms (Achieves NFR-P04 baseline)
```

### 3.8 Tenant-Scoped Alarm Acknowledgement Workflow

```
React Client Management Portal / Solo Flutter App UI
  ➔ PATCH /api/v5/alarms/{alarmId} (Intercepted at public vms-api-gateway pod ingress)
  → Ingress validation filters verify caller session tokens, forcing OPERATOR role constraints check
  → AlarmService.acknowledge() execution:
      UPDATE alarms
      SET status = 'ACKNOWLEDGED',
          acknowledged_by = $1,
          acknowledged_at = NOW(),
          updated_at = NOW()
      WHERE customer_id = $2 AND site_id = $3 AND alarm_id = $4 AND status = 'ACTIVE'
      RETURNING *;

  -- Multi-Tenant Scope Verification Guard rail:
  -- The update statement forces checking against matching tokens derived strictly from the verified JWT.
  -- Cross-tenant adjustments or unauthorized mutations are structurally dropped at row-level filters.

  ➔ Append audit line: { action: 'alarm.acknowledged', alarmId, customer_id, userId } to MongoDB logs.
  ➔ Publish update token: ws:alarm:{customer_id}:{siteId} back to the micro event bus layers.
  ➔ Broadcaster microservice fans out the state mutation instantly to all synchronized operators UI tiles.
  ➔ HTTP 200 returned confirming the transaction.
```
