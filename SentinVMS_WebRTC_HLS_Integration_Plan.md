# SentinVMS — WebRTC + HLS + Remote Playback Integration Plan

> **Purpose:** Make the SentinVMS Flutter app consume real customer-site live CCTV remotely, with **WebRTC as primary transport** and **HLS as automatic fallback**, while keeping Backend, MediaCore, PostgreSQL, Redis and MinIO on-premise.
>
> **Important:** This document separates **verified current source behavior** from **proposed changes**. New/proposed APIs are explicitly marked `PROPOSED`; they are not claimed to exist today.

## 1. Repositories and source baseline

### Flutter
Repository: `buildvithsagar/SentinVMS`
Branch supplied: `working`

Key source files inspected:

- `mobile/pubspec.yaml`
- `mobile/lib/features/login/data/auth_repository.dart`
- `mobile/lib/features/camera/data/camera_repository.dart`
- `mobile/lib/features/live_view/widgets/video_tile.dart`
- `mobile/lib/core/video/decoder_pool.dart`
- `mobile/lib/core/network/dio_factory.dart`
- `mobile/lib/core/network/refresh_token_interceptor.dart`
- `mobile/lib/core/network/websocket_service.dart`
- `mobile/lib/core/constants/app_constants.dart`

### Backend + MediaCore
Repository: `vivekranjan-art/vms-enterprise`

The repository index exposed a backend/media-core source state at commit:
`a082d2dd2116f8de7a9dbbd3eb90ac01194f175f`

Key source/contract files inspected:

- `backend/api-gateway/src/app/modules/auth/auth.controller.ts`
- `backend/api-gateway/src/app/modules/cameras/cameras.controller.ts`
- `backend/api-gateway/src/app/modules/cameras/cameras.service.ts`
- `backend/api-gateway/src/app/modules/recordings/recordings.controller.ts`
- `backend/api-gateway/src/app/modules/recordings/recordings.service.ts`
- `backend/api-gateway/src/app/modules/recordings/interfaces/media-core.client.interface.ts`
- `media-core-engine/src/media_core/live_gateway/webrtc_session.h`
- `media-core-engine/src/media_core/live_gateway/webrtc_session.cpp`
- `media-core-engine/src/media_core/live_gateway/live_gateway.h`
- `media-core-engine/src/media_core/live_gateway/live_gateway.cpp`
- `media-core-engine/src/media_core/session/media_session_manager.cpp`
- `docs/arch/api_contract.md`
- `docs/VMS_Mobile_API_Reference.md`
- `docs/architecture/backend/MEDIA_SESSION_ARCHITECTURE.md`
- `docs/requirements/TRD_Phase1.md`
- `backend_gaps.md`
- `docs/governance/ARCHITECTURE_RULES.md`
- `packages/contracts/ws/ws-events.ts`

---

# 2. Target architecture

```text
Customer Site (On-Premise)

IP Cameras
   │ RTSP H.264/H.265
   ▼
Edge Gateway
   │ secure/local ingestion
   ▼
MediaCore
   ├── WebRTC  ← PRIMARY live transport
   ├── HLS     ← FALLBACK live transport
   └── Recording → MinIO

Backend (NestJS)
   ├── Auth / JWT / RBAC
   ├── camera authorization
   ├── media-session orchestration
   └── recording/timeline APIs

PostgreSQL → persistent metadata
Redis      → sessions/cache/ephemeral state
MinIO      → recording objects

        Secure remote access
       (VPN / outbound tunnel /
        controlled public ingress)
                │
                ▼
         Flutter Mobile App
             │        │
          WebRTC     HLS
          primary   fallback
             └──┬───┘
                ▼
       Native media/player stack
                ▼
       Device hardware decoder
                ▼
             Screen
```

## 2.1 Responsibilities

| Component | Responsibility |
|---|---|
| Edge Gateway | Reach local cameras, ingest RTSP/ONVIF, bridge local network to VMS core |
| MediaCore | RTSP/media ingest, codec handling, HLS, WebRTC, recording/media pipeline |
| Backend | Authentication, RBAC, entitlement, camera metadata, stream authorization, media-session orchestration, recording metadata |
| PostgreSQL | Persistent users/cameras/sites/recording metadata |
| Redis | Session/cache/token/temporary state |
| MinIO | Recorded video/object storage |
| Flutter | UI, WebRTC client, HLS/VOD player, fallback state machine |

**Rule:** Backend must not become the video-byte bottleneck. The repository architecture also states that frontend does not directly access PostgreSQL and should not directly manage MediaCore internals.

---

# 3. Verified current Flutter implementation

## 3.1 `mobile/pubspec.yaml`

Current relevant dependencies include:

- `dio`
- `flutter_bloc`
- `socket_io_client`
- `video_player`

`flutter_webrtc` is not currently present.

### Required modification

Add a WebRTC package compatible with the project's supported Flutter/Dart + Android/iOS versions:

```yaml
flutter_webrtc:
```

Keep `video_player` because it is useful for HLS fallback and recording/VOD playback.

---

## 3.2 `mobile/lib/features/camera/data/camera_repository.dart`

### Current behavior

`getCameras()` calls `/cameras`, but `getLiveStreamUrl()` currently returns hard-coded public demo URLs for camera IDs.

Examples currently returned include Google sample MP4 URLs and public HLS test playlists.

### Problem

The mobile app is therefore not yet obtaining the real customer's MediaCore stream URL.

### Required modification

Replace `getLiveStreamUrl()` with a real API method such as:

```dart
Future<LiveStreamSession> getLiveStreamSession({
  required String cameraId,
  required StreamType type,
  String quality = 'main',
});
```

Call the existing public backend route:

```text
GET /api/v5/cameras/:id/stream
```

with:

```text
?type=hls&quality=main
```

or, after WebRTC support is implemented:

```text
?type=webrtc&quality=main
```

Do not return camera RTSP URLs to Flutter.

---

## 3.3 `mobile/lib/features/login/data/auth_repository.dart`

### Current behavior

The source currently returns mock/detached values:

- `loginStep1()` returns `OTP_SENT`
- `loginStep2()` returns a mock JWT/user

### Required modification

Connect to the actual backend authentication API.

Verified controller routes:

```text
POST /api/v5/auth/login
POST /api/v5/auth/verify-otp
POST /api/v5/auth/otp/send
POST /api/v5/auth/refresh
POST /api/v5/auth/logout
GET  /api/v5/auth/me
```

The exact login sequence in the current backend controller is:

```text
credentials
  ↓
POST /auth/login
  ↓
if OTP/MFA required
  ↓
POST /auth/verify-otp
  ↓
JWT access token
```

The API contract says the access token is short-lived compared with a session and the refresh token is cookie-based. The Flutter refresh implementation currently also contains explicit refresh-token storage logic, so this must be normalized against the backend cookie contract before production.

---

# 4. Verified current API base/config

`mobile/lib/core/constants/app_constants.dart` defines:

```text
API_BASE_URL
WS_URL
```

with a staging default API base URL under `/api/v5`.

`dio_factory.dart` uses `AppConstants.apiBaseUrl` as Dio's base URL and installs the refresh/retry interceptors.

### Required deployment change

For every customer deployment, inject the correct secure gateway URL rather than hard-coding a customer LAN IP into app code.

Example concept:

```text
https://customer-vms.example.com/api/v5
```

or a site-specific secure access endpoint delivered through the chosen VPN/tunnel architecture.

---

# 5. Live streaming backend — current source

## 5.1 `backend/api-gateway/src/app/modules/cameras/cameras.controller.ts`

Verified route:

```text
GET /api/v5/cameras/:id/stream
```

Query parameters currently accepted by the controller:

```text
type
quality
```

The controller calls:

```text
camerasService.getStreamUrl(customerId, cameraId, type, quality)
```

The same controller also exposes:

```text
GET  /api/v5/cameras
GET  /api/v5/cameras/:id
GET  /api/v5/cameras/:id/health
GET  /api/v5/cameras/:id/snapshot
POST /api/v5/cameras/:id/ptz
POST /api/v5/cameras/:id/actions/restart-stream
```

These should remain control-plane APIs.

---

# 6. Critical current backend limitation: WebRTC is rejected

`backend/api-gateway/src/app/modules/cameras/cameras.service.ts` currently contains logic equivalent to:

```ts
if (type === 'webrtc') {
  throw new BadRequestException(
    'WebRTC is Phase 2. Use type=hls for Phase 1.',
  );
}
```

So current runtime behavior is:

```text
GET /api/v5/cameras/:id/stream?type=hls
    → supported

GET /api/v5/cameras/:id/stream?type=webrtc
    → rejected
```

### Required modification

Change the implementation from an HLS-only URL generator into a protocol-neutral media-session endpoint.

Keep the same public endpoint:

```text
GET /api/v5/cameras/:id/stream
```

and support:

```text
?type=webrtc&quality=main
?type=hls&quality=main
```

---

# 7. Current HLS generation — verified

`CamerasService.getStreamUrl()` currently:

1. validates live-view entitlement,
2. loads the camera,
3. finds the active Edge assignment,
4. asks Edge to connect the camera using the Edge gRPC client,
5. builds a MediaCore HLS URL,
6. signs it using HMAC-SHA256,
7. stores a short-lived Redis stream token,
8. returns a signed stream URL.

Current canonical HLS path generated by the source is conceptually:

```text
/hls/{customerId}/{siteId}/{cameraId}/live.m3u8
```

Current environment variables used include:

```text
MEDIA_CORE_HOST
MEDIA_CORE_PORT
MEDIA_HMAC_KEY
```

Current code default for `MEDIA_CORE_PORT` in this path is `8888`.

### What to keep

Keep this URL/signature model for HLS fallback unless the media gateway design replaces it with another equally secure short-lived authorization model.

---

# 8. Backend → Edge current flow

The current camera service already uses the camera's active Edge assignment and the `EdgeGrpcClientService` to send lifecycle commands.

The controller's discovery path also invokes Edge gRPC.

Therefore the live-start flow should remain:

```text
Flutter
  ↓
Backend camera stream request
  ↓
authorization
  ↓
Edge assignment lookup
  ↓
Edge gRPC CONNECT
  ↓
Edge reaches local RTSP camera
```

The mobile must never talk directly to the camera's private RTSP address.

---

# 9. MediaCore WebRTC — verified current source

## 9.1 Existing files

```text
media-core-engine/src/media_core/live_gateway/webrtc_session.h
media-core-engine/src/media_core/live_gateway/webrtc_session.cpp
media-core-engine/src/media_core/live_gateway/live_gateway.h
media-core-engine/src/media_core/live_gateway/live_gateway.cpp
```

`LiveGateway` already exposes methods conceptually equivalent to:

```cpp
start_webrtc(...)
stop_webrtc(...)
add_remote_ice_candidate(...)
is_webrtc_active(...)
webrtc_session_count(...)
push_frame(...)
```

This means the MediaCore core already contains a WebRTC session layer.

---

# 10. Actual WebRTC pipeline in MediaCore

`webrtc_session.cpp` currently builds a GStreamer pipeline equivalent to:

```text
appsrc
  ↓
h264parse
  ↓
rtph264pay
  ↓
webrtcbin
```

It also has:

- SDP offer parsing,
- SDP answer generation,
- local ICE candidate callback,
- remote ICE candidate injection,
- STUN configuration,
- optional TURN configuration.

Relevant environment variables currently read by the source:

```text
VMS_WEBRTC_STUN_SERVER
VMS_WEBRTC_TURN_SERVER
```

---

# 11. Critical MediaCore codec limitation: WebRTC currently H.264 only

`WebRtcSession::start()` explicitly rejects codecs other than H.264.

The current behavior is therefore:

```text
H.264 camera
   ↓
MediaCore
   ↓
WebRTC
   ✅
```

but:

```text
H.265 camera
   ↓
current WebRTC session
   ❌
```

### Required strategy

For H.265 cameras, use the existing MediaCore transcoding capability where necessary:

```text
H.265 camera
   ↓
MediaCore / codec conversion
   ↓
H.264
   ↓
WebRTC
```

For cameras already producing compatible H.264, avoid unnecessary transcoding and prefer remux/packet handling where possible to reduce latency and CPU/GPU cost.

---

# 12. WebRTC signaling is the main missing integration

The MediaCore C++ WebRTC code already expects:

- an SDP offer,
- SDP answer callback,
- local ICE candidate callback,
- remote ICE candidate input.

The repository's `backend_gaps.md` explicitly identifies the absence of a finished end-to-end WebRTC negotiation API and says the current frontend hardcodes HLS because WebRTC SDP offer/answer endpoints are missing.

### Required work

Create a complete signaling path:

```text
Flutter
  ↓ offer
Backend signaling/control
  ↓
MediaCore WebRtcSession
  ↓ answer
Backend signaling/control
  ↓
Flutter
```

and:

```text
Flutter ⇄ ICE candidates ⇄ Backend/MediaCore
```

---

# 13. Backend MediaCore abstraction — verified

The existing interface:

```ts
export interface IMediaCoreClient {
  negotiateStream(
    cameraId: string,
    type: 'hls' | 'webrtc',
    quality: 'main' | 'sub'
  ): Promise<any>;

  requestExport(cameraId: string, payload: any): Promise<string>;
  getTimelineMetadata(cameraId: string, date: string): Promise<any>;
}
```

Source:

`backend/api-gateway/src/app/modules/recordings/interfaces/media-core.client.interface.ts`

### Interpretation

This interface is already an intended integration point between the Backend and MediaCore.

### Required work

Implement/verify a real concrete `MediaCoreClient` that invokes the actual internal MediaCore control/session protocol.

Do not make Flutter aware of MediaCore's private internal address.

---

# 14. Media session manager — verified

The repository contains a canonical Media Session architecture.

`docs/architecture/backend/MEDIA_SESSION_ARCHITECTURE.md` defines:

- MediaCore as source of truth for stream state,
- `AcquireSession` / `ReleaseSession` lifecycle,
- one camera → one reusable media session,
- multiple viewers attached to one session,
- viewer heartbeats,
- 30-second idle grace period,
- recording as a persistent pseudo-viewer concept.

`media_session_manager.cpp` contains `acquire_session()`, `release_session()`, `on_pipeline_ready()`, `on_pipeline_failed()` and cleanup logic.

### Required modification

Make protocol selection real.

Current `acquire_session()` returns an HLS protocol marker in the retrieved implementation. The session API must support:

```text
LIVE + WEBRTC
LIVE + HLS
PLAYBACK
```

without creating duplicate pipelines for the same camera unnecessarily.

---

# 15. Public live API — recommended final contract

Use the existing route:

```text
GET /api/v5/cameras/:id/stream
```

### WebRTC request

```text
GET /api/v5/cameras/{cameraId}/stream?type=webrtc&quality=main
Authorization: Bearer <access_token>
```

### PROPOSED WebRTC response

```json
{
  "type": "webrtc",
  "session_id": "uuid",
  "viewer_id": "uuid",
  "signaling": {
    "url": "..."
  },
  "expires_at": "2026-..."
}
```

Field names should be frozen in `docs/arch/api_contract.md` before implementation.

### HLS request

```text
GET /api/v5/cameras/{cameraId}/stream?type=hls&quality=main
Authorization: Bearer <access_token>
```

### Existing HLS response pattern

```json
{
  "stream_url": "https://.../hls/{customer}/{site}/{camera}/live.m3u8?...",
  "expires_at": "...",
  "type": "hls"
}
```

---

# 16. PROPOSED internal MediaCore control contract

The repository evidence confirms the need for MediaCore negotiation but does **not** establish a finished public WebRTC signaling HTTP API.

Choose **one** internal control protocol and document it. If HTTP is chosen, a clean contract is:

```text
POST /internal/v1/media/sessions
POST /internal/v1/media/sessions/{sessionId}/webrtc/offer
POST /internal/v1/media/sessions/{sessionId}/webrtc/ice
DELETE /internal/v1/media/sessions/{sessionId}/viewers/{viewerId}
GET /internal/v1/media/sessions/{sessionId}
```

These are **PROPOSED**, not existing endpoints.

A gRPC implementation is equally valid and may fit the existing Edge/backend style better. Do not maintain two parallel control protocols unless there is a real requirement.

---

# 17. WebRTC negotiation sequence

```text
Flutter
  │
  │ GET /cameras/:id/stream?type=webrtc
  ▼
Backend
  │
  ├─ JWT/RBAC/entitlement
  ├─ camera lookup
  ├─ Edge assignment
  └─ Acquire MediaSession
       │
       ▼
   MediaCore
       │
       │ returns session/viewer/signaling info
       ▼
Backend
  │
  ▼
Flutter
  │
  │ create RTCPeerConnection
  │ create SDP offer
  │
  ▼
Backend signaling
  │
  ▼
MediaCore WebRtcSession
  │
  ├─ set remote SDP offer
  ├─ create SDP answer
  ├─ set local description
  └─ emit local ICE candidates
  │
  ▼
Flutter
  │
  ├─ set remote SDP answer
  └─ exchange ICE
  │
  ▼
WebRTC connected
  │
  ▼
LIVE VIDEO
```

The actual C++ WebRTC session already has the corresponding operations.

---

# 18. Flutter implementation design

## 18.1 Add a typed model

New file:

```text
mobile/lib/features/camera/models/live_stream_session.dart
```

Recommended concept:

```dart
enum StreamType { webrtc, hls }

class LiveStreamSession {
  final StreamType type;
  final String sessionId;
  final String viewerId;
  final String? streamUrl;
  final String? signalingUrl;
  final DateTime? expiresAt;
}
```

Adjust names to the final API contract.

---

## 18.2 New WebRTC service

New file:

```text
mobile/lib/core/video/webrtc_service.dart
```

Responsibilities:

- create `RTCPeerConnection`,
- create SDP offer,
- apply SDP answer,
- handle remote video track,
- exchange ICE candidates,
- expose connection state,
- detect failure/timeout,
- cleanly close the session.

Pseudo lifecycle:

```text
createPeer
  ↓
createOffer
  ↓
sendOffer
  ↓
setAnswer
  ↓
ICE exchange
  ↓
connected
```

---

## 18.3 New live stream orchestrator

New file:

```text
mobile/lib/core/video/live_stream_service.dart
```

This service owns the policy:

```text
TRY_WEBRTC
   ↓
CONNECTED → LIVE_WEBRTC

FAILED/TIMEOUT
   ↓
GET HLS SESSION
   ↓
LIVE_HLS
```

Recommended states:

```text
idle
connectingWebRtc
webRtcConnected
webRtcFailed
connectingHls
hlsConnected
failed
stopped
```

---

# 19. `video_tile.dart` changes

Current file:

```text
mobile/lib/features/live_view/widgets/video_tile.dart
```

Current logic directly:

```text
CameraRepository
  ↓
getLiveStreamUrl()
  ↓
VideoPlayerController.networkUrl()
```

### Replace with

```text
VideoTile
  ↓
LiveStreamService
  ├─ WebRTC player first
  └─ HLS VideoPlayer fallback
```

UI should expose status:

```text
CONNECTING WEBRTC
LIVE • WEBRTC
SWITCHING TO HLS
LIVE • HLS
STREAM ERROR
RETRY
```

Keep the existing `RepaintBoundary` and PTZ overlay.

---

# 20. DecoderPool clarification

Current file:

```text
mobile/lib/core/video/decoder_pool.dart
```

The current pool does not create a hardware decoder. It manages a maximum number of active `VideoPlayerController` leases and evicts old entries when the pool is full.

### Important

You do **not** need to build an H.264/H.265 decoder for Android/iOS.

The phone/OS provides hardware video decoding where supported.

Your application integrates native playback/WebRTC stacks; it does not implement the codec decoder.

### Required redesign

Rename or refactor the abstraction if necessary so it represents **player/stream resource management**, not a custom decoder implementation.

For a 4/9/16 camera grid, use visibility/priority rules so not every tile necessarily consumes the same resources.

---

# 21. `websocket_service.dart` changes

Current file:

```text
mobile/lib/core/network/websocket_service.dart
```

Current Socket.IO path:

```text
/ws/v5/telemetry
```

Current events include:

```text
ai.alert.triggered
camera.status
storage.alert
```

### Keep Socket.IO for

- telemetry,
- camera state,
- alarms/events,
- UI status updates.

### Do not treat Socket.IO telemetry as the media transport.

WebRTC media uses the WebRTC peer connection. Socket.IO may be used as signaling only if the Backend contract explicitly chooses that method.

If Socket.IO becomes the signaling transport, freeze explicit event names, e.g.:

```text
webrtc:offer
webrtc:answer
webrtc:ice-candidate
webrtc:close
```

Those event names are **PROPOSED**.

---

# 22. Remote access when everything is on-premise

If Backend, MediaCore, DB, Redis and MinIO are all at the customer site, the mobile cannot simply connect to `192.168.x.x` from 4G/5G.

A secure network path is required:

```text
Remote Flutter
      │
  4G/5G/Internet
      │
      ▼
VPN / Secure Tunnel / Controlled Public Gateway
      │
      ▼
Customer LAN
```

### Do not expose directly

```text
PostgreSQL
Redis
Camera RTSP
Edge gRPC
MinIO admin
```

Only expose controlled API/media entrypoints.

---

# 23. WebRTC NAT traversal

MediaCore's current C++ implementation already reads STUN/TURN environment variables.

For remote networks, configure:

```text
VMS_WEBRTC_STUN_SERVER
VMS_WEBRTC_TURN_SERVER
```

### Target path

```text
Flutter
   │
   ├─ direct WebRTC if possible
   │
   └─ TURN relay when direct path fails
   │
   ▼
MediaCore
```

Remote 4G/5G testing must be part of acceptance testing.

---

# 24. Recording and playback

Verified recording controller routes include:

```text
GET  /api/v5/recordings/timeline
GET  /api/v5/recordings/stream
GET  /api/v5/recordings/calendar
GET  /api/v5/recordings/:id/detail
GET  /api/v5/recordings/:cameraId
POST /api/v5/recordings/start
POST /api/v5/recordings/stop
POST /api/v5/recordings/:id/export
GET  /api/v5/recordings/exports/:exportId
```

The mobile API reference specifically documents:

```text
GET /api/v5/recordings/timeline
GET /api/v5/recordings/stream
```

---

# 25. Recording timeline → playback

## Timeline

```text
Flutter
  ↓
GET /api/v5/recordings/timeline
  ↓
Backend
  ↓
recording metadata
  ↓
Timeline/Scrubber
```

Parameters documented in the mobile API reference:

```text
camera_id
site_id
date
```

## Playback

```text
Flutter
  ↓
GET /api/v5/recordings/stream
  ↓
Backend authorization
  ↓
MediaCore VOD
  ↓
MinIO
  ↓
HLS VOD
  ↓
Flutter video_player
```

Documented playback parameters include:

```text
camera_id
site_id
start_time
end_time
speed
```

with speed values including `0.5, 1, 2, 4, 8, 16`.

---

# 26. Recording storage

Repository documentation specifies an fMP4 object naming convention conceptually like:

```text
/recordings/{customer_id}/{site_id}/{camera_id}/{YYYY-MM-DD}/{epoch_ms}.fmp4
```

MinIO stores the actual video objects.

PostgreSQL stores metadata such as:

```text
recording id
camera id
site id
start time
end time
duration
file size
storage tier
evidence lock state
```

Do not send internal object paths directly to untrusted clients.

---

# 27. Important playback gap

The repository's `backend_gaps.md` says parts of the playback pipeline are incomplete/mock and that MediaCore has low-level playback functionality that is not yet fully wired to the Backend API.

Therefore validate the complete real path:

```text
recording metadata
  ↓
actual MinIO object
  ↓
MediaCore VOD pipeline
  ↓
valid HLS playlist/segments
  ↓
Flutter playback
```

Do not mark playback complete just because the controller route exists.

---

# 28. Camera health / status

Verified endpoint:

```text
GET /api/v5/cameras/:id/health
```

Current implementation can read health data from Redis and fall back to database camera data.

Use this for UI state such as:

```text
ONLINE
OFFLINE
ERROR
FPS
bitrate
packet loss
last seen
```

Do not use the health API as the media transport.

---

# 29. PTZ flow

Verified public route:

```text
POST /api/v5/cameras/:id/ptz
```

Current service routes the command to the assigned Edge through gRPC.

Correct architecture:

```text
Flutter
  ↓ HTTPS
Backend
  ↓ gRPC
Edge
  ↓ ONVIF/PTZ
Camera
```

Keep this boundary; do not implement direct ONVIF/PTZ calls from Flutter.

---

# 30. Security requirements

From the repository architecture/contracts:

- `Authorization: Bearer <access_token>` for protected APIs.
- customer scope comes from JWT, not mobile request body.
- TLS is required.
- RBAC/permission guards remain in Backend.
- stream URLs/tokens are short-lived.
- camera RTSP credentials must never be exposed to Flutter.
- Backend/MediaCore internal control endpoints must not be unauthenticated.

For local deployment, use a secure ingress/tunnel rather than opening database/cache services to the public network.

---

# 31. Exact file change plan

## Flutter — modify

### `mobile/pubspec.yaml`
- Add WebRTC dependency.
- Keep `video_player`.

### `mobile/lib/features/login/data/auth_repository.dart`
- Replace mock login.
- Call actual `/auth/login`, `/auth/verify-otp`.
- Map real JWT/user response to AuthBloc.

### `mobile/lib/features/camera/data/camera_repository.dart`
- Delete demo stream URL switch.
- Add real stream-session requests.
- Parse WebRTC/HLS session response.

### `mobile/lib/features/live_view/widgets/video_tile.dart`
- Replace direct stream initialization with `LiveStreamService`.
- Show WebRTC/HLS status.
- Trigger fallback.
- Preserve resource cleanup and `RepaintBoundary`.

### `mobile/lib/core/video/decoder_pool.dart`
- Refactor toward generic player/session leases.
- Keep a limit for multi-camera resources.
- Do not imply that this class implements the codec.

### `mobile/lib/core/network/refresh_token_interceptor.dart`
- Align actual cookie behavior with backend.
- Avoid two competing refresh-token storage models.

### `mobile/lib/core/network/dio_factory.dart`
- Keep as API client/TLS boundary.
- Inject customer gateway URL through `API_BASE_URL`.

### `mobile/lib/core/network/websocket_service.dart`
- Keep telemetry Socket.IO.
- Optionally add explicit WebRTC signaling events only after contract is frozen.

## Flutter — add

```text
mobile/lib/features/camera/models/live_stream_session.dart
mobile/lib/core/video/webrtc_service.dart
mobile/lib/core/video/live_stream_service.dart
mobile/lib/core/video/stream_state.dart
```

---

# 32. Backend — modify

### `backend/api-gateway/src/app/modules/cameras/cameras.controller.ts`
- Keep `GET /api/v5/cameras/:id/stream`.
- Allow `type=webrtc`.
- Return a WebRTC session descriptor for WebRTC.
- Return the signed HLS URL for HLS.

### `backend/api-gateway/src/app/modules/cameras/cameras.service.ts`
Refactor `getStreamUrl()` into protocol-neutral orchestration:

```text
authorizeLiveView()
ensureEdgeIngest()
acquireMediaSession()
return WebRTC session OR HLS signed URL
```

### `backend/api-gateway/src/app/modules/recordings/interfaces/media-core.client.interface.ts`
- Keep the abstraction.
- Ensure concrete implementation exists and is wired.
- `negotiateStream()` must perform real Backend → MediaCore communication.

### `backend/api-gateway/src/app/modules/recordings/recordings.controller.ts`
- Verify `/recordings/stream` and `/recordings/timeline` match final playback contract.
- Keep authorization on all user-facing playback endpoints.

### `backend/api-gateway/src/app/modules/recordings/recordings.service.ts`
- Complete/verify real MediaCore VOD integration.
- Ensure real MinIO/object-backed playback.
- Ensure no mock playback URL survives production.

### DTOs to freeze/update

```text
backend/api-gateway/src/app/modules/recordings/dto/stream-request.dto.ts
backend/api-gateway/src/app/modules/recordings/dto/stream-response.dto.ts
backend/api-gateway/src/app/modules/recordings/dto/playback-session-request.dto.ts
backend/api-gateway/src/app/modules/recordings/dto/playback-session-response.dto.ts
```

---

# 33. MediaCore — modify

### Existing WebRTC implementation

```text
media-core-engine/src/media_core/live_gateway/webrtc_session.h
media-core-engine/src/media_core/live_gateway/webrtc_session.cpp
```

Tasks:

- keep SDP/ICE implementation,
- expose it through the chosen internal control/signaling adapter,
- make H.264 output guaranteed for WebRTC,
- preserve STUN/TURN configuration,
- return explicit session/negotiation failures.

### `live_gateway.*`

Connect external session requests to:

```text
start_webrtc()
add_remote_ice_candidate()
stop_webrtc()
```

### `media_session_manager.cpp`

Make session responses protocol-aware and integrate the actual WebRTC pipeline lifecycle.

Required session states:

```text
CREATING
READY
ACTIVE
IDLE
TERMINATING
DESTROYED
FAILED
```

---

# 34. HLS fallback requirements

When Flutter detects WebRTC failure:

```text
WebRTC FAILED
     ↓
request fresh HLS session
     ↓
GET /api/v5/cameras/:id/stream?type=hls
     ↓
signed URL
     ↓
VideoPlayerController.networkUrl()
     ↓
MediaCore HLS
     ↓
M3U8 + segments
     ↓
LIVE
```

Do not keep a failed WebRTC connection alive while opening HLS unless there is a deliberate parallel-recovery policy.

---

# 35. Hardware decoder clarification

Nothing needs to be written from scratch for mobile H.264/H.265 decoding.

Conceptually:

```text
MediaCore
  ↓ encoded H.264/H.265
network
  ↓
Android/iOS native media stack
  ↓
hardware-accelerated decode when supported
  ↓
video frames
  ↓
screen
```

`ExoPlayer/Media3` and `AVPlayer/AVFoundation` are playback/native media technologies; they use the device's available hardware codecs where supported.

Your `DecoderPool` is a resource-management layer, not a decoder implementation.

---

# 36. End-to-end remote live flow

## Login

```text
Flutter
 ↓
POST /api/v5/auth/login
 ↓
Backend
 ↓
JWT / MFA
 ↓
Flutter
```

## Camera discovery/list

```text
Flutter
 ↓
GET /api/v5/cameras
 ↓
Backend
 ↓
PostgreSQL + Redis
 ↓
Flutter
```

## Start live view — WebRTC primary

```text
Flutter
 ↓
GET /api/v5/cameras/{id}/stream?type=webrtc&quality=main
 ↓
Backend
 ↓
JWT + RBAC + entitlement
 ↓
Edge CONNECT if needed
 ↓
MediaCore Acquire/Reuse MediaSession
 ↓
WebRTC session descriptor
 ↓
Flutter
 ↓
SDP Offer / Answer + ICE
 ↓
MediaCore
 ↓
WebRTC media
 ↓
Flutter
 ↓
LIVE
```

## Fallback

```text
WebRTC connection fails
 ↓
GET /api/v5/cameras/{id}/stream?type=hls&quality=main
 ↓
Signed HLS URL
 ↓
Flutter video_player
 ↓
MediaCore HLS
 ↓
LIVE
```

---

# 37. End-to-end recording flow

```text
Flutter
 ↓
GET /api/v5/recordings/timeline
 ↓
Backend
 ↓
Timeline metadata
 ↓
Flutter scrubber
 ↓
User selects time range
 ↓
GET /api/v5/recordings/stream
 ↓
Backend authorization
 ↓
MediaCore VOD
 ↓
MinIO recording objects
 ↓
HLS VOD
 ↓
Flutter video_player
 ↓
Playback
```

---

# 38. Acceptance tests

### WebRTC

- H.264 camera → remote Android → WebRTC video.
- H.264 camera → remote iOS → WebRTC video.
- H.265 camera → required H.265→H.264 path → WebRTC.
- SDP offer/answer succeeds.
- ICE exchange succeeds.
- TURN path succeeds on restrictive/mobile networks.
- Session cleanup works after tile/page close.

### HLS

- Force WebRTC failure.
- App automatically switches to HLS.
- HLS playlist and segments load.
- Expired HLS URL is renewed correctly.

### Security

- Unauthorized user cannot get stream session.
- User without camera permission receives 403.
- RTSP URL is never returned to mobile.
- PostgreSQL/Redis/MinIO admin are not public.

### Playback

- Timeline loads.
- Selected interval returns a real playback URL.
- Real MinIO object is playable.
- 0.5x/1x/2x/4x/8x/16x behavior is validated where backend/media pipeline supports it.

### Grid/resource tests

- 1x1
- 2x2
- 3x3
- 4x4

Verify that resource eviction/visibility behavior does not accidentally destroy active sessions that are still visible.

---

# 39. Implementation order

1. **Real mobile authentication**
2. **Remove demo stream URLs**
3. **Make current HLS live path work with one real on-prem camera**
4. **Implement/verify Backend → MediaCore client**
5. **Finish WebRTC signaling**
6. **Add Flutter WebRTC service**
7. **Implement WebRTC-first/HLS-fallback state machine**
8. **Configure remote access + STUN/TURN**
9. **Verify recording playback end-to-end**
10. **Tune multi-camera resource management**

---

# 40. Source-of-truth references

## Flutter

- https://github.com/buildvithsagar/SentinVMS/blob/working/mobile/pubspec.yaml
- https://github.com/buildvithsagar/SentinVMS/blob/working/mobile/lib/features/camera/data/camera_repository.dart
- https://github.com/buildvithsagar/SentinVMS/blob/working/mobile/lib/features/live_view/widgets/video_tile.dart
- https://github.com/buildvithsagar/SentinVMS/blob/working/mobile/lib/core/video/decoder_pool.dart
- https://github.com/buildvithsagar/SentinVMS/blob/working/mobile/lib/core/network/dio_factory.dart
- https://github.com/buildvithsagar/SentinVMS/blob/working/mobile/lib/core/network/refresh_token_interceptor.dart
- https://github.com/buildvithsagar/SentinVMS/blob/working/mobile/lib/core/network/websocket_service.dart
- https://github.com/buildvithsagar/SentinVMS/blob/working/mobile/lib/features/login/data/auth_repository.dart

## Backend / MediaCore

- https://github.com/vivekranjan-art/vms-enterprise/blob/a082d2dd2116f8de7a9dbbd3eb90ac01194f175f/backend/api-gateway/src/app/modules/auth/auth.controller.ts
- https://github.com/vivekranjan-art/vms-enterprise/blob/a082d2dd2116f8de7a9dbbd3eb90ac01194f175f/backend/api-gateway/src/app/modules/cameras/cameras.controller.ts
- https://github.com/vivekranjan-art/vms-enterprise/blob/a082d2dd2116f8de7a9dbbd3eb90ac01194f175f/backend/api-gateway/src/app/modules/cameras/cameras.service.ts
- https://github.com/vivekranjan-art/vms-enterprise/blob/a082d2dd2116f8de7a9dbbd3eb90ac01194f175f/backend/api-gateway/src/app/modules/recordings/recordings.controller.ts
- https://github.com/vivekranjan-art/vms-enterprise/blob/a082d2dd2116f8de7a9dbbd3eb90ac01194f175f/backend/api-gateway/src/app/modules/recordings/recordings.service.ts
- https://github.com/vivekranjan-art/vms-enterprise/blob/a082d2dd2116f8de7a9dbbd3eb90ac01194f175f/backend/api-gateway/src/app/modules/recordings/interfaces/media-core.client.interface.ts
- https://github.com/vivekranjan-art/vms-enterprise/blob/a082d2dd2116f8de7a9dbbd3eb90ac01194f175f/media-core-engine/src/media_core/live_gateway/webrtc_session.h
- https://github.com/vivekranjan-art/vms-enterprise/blob/a082d2dd2116f8de7a9dbbd3eb90ac01194f175f/media-core-engine/src/media_core/live_gateway/webrtc_session.cpp
- https://github.com/vivekranjan-art/vms-enterprise/blob/a082d2dd2116f8de7a9dbbd3eb90ac01194f175f/media-core-engine/src/media_core/live_gateway/live_gateway.h
- https://github.com/vivekranjan-art/vms-enterprise/blob/a082d2dd2116f8de7a9dbbd3eb90ac01194f175f/media-core-engine/src/media_core/session/media_session_manager.cpp

## Contracts / architecture

- https://github.com/vivekranjan-art/vms-enterprise/blob/a082d2dd2116f8de7a9dbbd3eb90ac01194f175f/docs/arch/api_contract.md
- https://github.com/vivekranjan-art/vms-enterprise/blob/a082d2dd2116f8de7a9dbbd3eb90ac01194f175f/docs/VMS_Mobile_API_Reference.md
- https://github.com/vivekranjan-art/vms-enterprise/blob/a082d2dd2116f8de7a9dbbd3eb90ac01194f175f/docs/architecture/backend/MEDIA_SESSION_ARCHITECTURE.md
- https://github.com/vivekranjan-art/vms-enterprise/blob/a082d2dd2116f8de7a9dbbd3eb90ac01194f175f/docs/requirements/TRD_Phase1.md
- https://github.com/vivekranjan-art/vms-enterprise/blob/a082d2dd2116f8de7a9dbbd3eb90ac01194f175f/backend_gaps.md
- https://github.com/vivekranjan-art/vms-enterprise/blob/a082d2dd2116f8de7a9dbbd3eb90ac01194f175f/docs/governance/ARCHITECTURE_RULES.md
- https://github.com/vivekranjan-art/vms-enterprise/blob/a082d2dd2116f8de7a9dbbd3eb90ac01194f175f/packages/contracts/ws/ws-events.ts

---

## Final implementation principle

```text
Backend = AUTH + RBAC + SESSION ORCHESTRATION
MediaCore = MEDIA PIPELINE + WEBRTC + HLS + RECORDING
Redis = EPHEMERAL STATE / CACHE / TOKENS
PostgreSQL = PERSISTENT METADATA
MinIO = VIDEO OBJECT STORAGE
Edge = LOCAL CAMERA BRIDGE
Flutter = UI + WEBRTC PRIMARY + HLS FALLBACK + PLAYBACK
```

The most important current gap is not the absence of a WebRTC C++ pipeline. The code already contains that primitive. The main missing work is connecting **Flutter → Backend authorization/session → MediaCore WebRTC signaling → remote WebRTC media**, while preserving the existing HLS path as a reliable fallback.
