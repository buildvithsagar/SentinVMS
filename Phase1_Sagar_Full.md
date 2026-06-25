# Enterprise VMS — Phase 1 (Full system) with Sagar-Centric Mobile Sections

> Note: This document bundles the Phase 1 PRD, TRD, APP_FLOW summaries and full mobile interpretation for the Flutter client (Sagar). All Phase 1 system-level constraints, ownership boundaries, and non-negotiable architecture are preserved. Mobile-specific responsibilities, acceptance criteria, coding rules, flows, and implementation checklists are presented clearly and separately. Backend/edge/media responsibilities remain dependency context and are not reassigned.

---

Table of contents
1. Executive Summary (system)
2. Phase 1 System Architecture & Non-negotiables
3. Phase 1 Feature Requirements (system)
4. Technical Requirements (TRD) — key facts & constraints
5. APP_FLOW — End-to-end system flows (summarized)
6. Sagar Mobile Overview — scope & rules
7. Mobile-Relevant Phase 1 Requirements (detailed)
8. Feature-by-feature mobile responsibilities
9. Sagar Technical Contract (developer rules)
10. Mobile Implementation Checklist & Prioritized Plan
11. Mobile Acceptance Criteria (MVP)
12. App Flows (screen-level) — Login, Live, Playback, Alarm/Event, Export
13. Bloc / State Design Implications
14. Failure Modes & What Breaks Mobile If Backend/Media Is Wrong
15. Feature Matrix & Phase classification
16. Conflicts, Clarifications, Open Questions
17. Appendices: Important API & system call extracts (auth, refresh, sample endpoints), DecoderPool rules, SPKI pin fingerprint note

---

1) Executive summary (system)
- Phase 1 delivers a centralized, multi-tenant SaaS VMS baseline: secure identity directories, continuous cloud media recording, HLS playback/timeline scrubbing, clip exports with watermarking, and the async interception loop for AI alerts. This is a production deployable baseline intended to validate scale and multi-tenant isolation.[file:28]
- Ownership: NestJS control plane (Vivek), C++ Cloud Media Core and Edge Agent (Shubham + Saurabh), Flutter mobile app (Sagar — solo track), DB/infra observability (Vivek + infra).[file:29]

2) Phase 1 System Architecture & non-negotiables (preserved)
- Architecture: centralized Kubernetes-based cloud cluster with process isolation (api-gateway, event-workers, ws-broadcaster), media core and edge appliances for ingest, and separate data infra (PostgreSQL Patroni cluster, Redis cluster, MongoDB PSS, MinIO, Vault). The stack is frozen for Phase 1; substitutions require CCB approval.[file:29]
- Pillar 4 (Process isolation): NestJS must run as three separate deployments. This is a strict constraint — mobile design must assume these process boundaries produce the APIs and event channels described.[file:29]
- Security: TLS 1.3 enforced via ingress, Vault-managed JWT signing and mTLS for service-to-service. Mobile must follow SPKI pinning to Vault Intermediate CA and keep tokens in hardware-backed storage.[file:29]
- Media flows: cameras → edge agent → media core → minIO → Redis streams → event-workers. Mobile consumes signed HLS endpoints and never connects directly to raw camera streams.[file:29][file:30]

3) Phase 1 Feature Requirements (system)
- Core server features: multi-tenant identity, dynamic site/camera mapping, continuous fragmented fMP4 recording, HLS adaptive output, timeline scrub archives, watermarked exports, AIEYE webhook ingestion and rule-based alarms, and audit logging.[file:28]
- Mobile-facing Phase 1 features: secure sign-in, session handling, HLS live view (1×1/2×2 mobile grids), playback with timeline scrub/seek/speed, export UI trigger/status, role-aware consumption, SPKI pinning, decoder pooling, WebSocket + push alarm awareness.[file:28][file:29][file:30]

4) Technical Requirements (TRD) — key facts & constraints (system-level preserved)
- Frozen stack versions and ownership list: Flutter mobile (Sagar) must use Flutter 3.x and Dart 3.x; must follow `flutter_bloc`, `GetIt`, use `video_player` plugin and Texture-based rendering (PlatformView for video is forbidden); follow the rendering guidelines including RepaintBoundary per tile.[file:29]
- DecoderPool: mobile must implement a hardware decoder semaphore capping concurrent hardware decoders at 4. This is a hard limit; UI must throttle tiles accordingly.[file:29]
- Token model: Access tokens are short-lived, returned in JSON response; refresh token is HttpOnly cookie and server-side DB-tracked; mobile may store refresh tokens in hardware-backed secure storage when allowed. Refresh flow must be serialized (RefreshLock) to avoid races.[file:29][file:30]
- SPKI pinning: Mobile must pin the Vault Intermediate CA SPKI SHA-256 fingerprint; leaf pinning or bypass is banned.[file:29]
- Streaming: Phase 1 is HLS-first. WebRTC/ICE is present in system but explicitly out of Phase 1 mobile scope.[file:29]
- WebSocket / push: WebSocket broadcaster fans out alarms to authenticated connections with sticky sessions; a push path via FCM/APNs is present for mobile alarms.[file:30]

5) APP_FLOW — End-to-end execution sequences (system)
- Flow 1 — User session onboarding: TLS handshake → NGINX → api-gateway → auth service → PostgreSQL check → Vault (MFA) → issue access token + HttpOnly refresh cookie → Redis session registration → MongoDB audit write → client receives access token (volatile) and refresh cookie.[file:30]
- Flow 2 — Edge ingest & recording: Edge appliances discover ONVIF cameras, forward to media core, media core segments continuous fMP4 and writes to MinIO, emits Redis event vms:recording-lifecycle consumed by workers that create DB indexes.[file:30]
- Flow 3 — AI alarm event: AIEYE webhook → Redis AI stream vms:ai-event:{customer_id}:{site_id} → event-workers evaluate rules → create alarms in PostgreSQL and audit logs in MongoDB → publish to ws-broadcaster and push-notification service (FCM/APNs) → mobile receives via WebSocket or push.[file:30]

6) Sagar Mobile Overview — scope & rules (Sagar-centric summary)
- Owned deliverable: Flutter single-repo mobile app implementing Phase 1 mobile MVP: secure login, session management, HLS live view grid (1×1 and 2×2), playback timeline scrub/seek/speed, role-aware camera list, basic export UI surface, alarm consumption (WebSocket primary + push fallback), secure storage/pinning, decoder cap and failure handling.[file:29][file:30][file:32]
- Not owned: media core, edge agent, NestJS server, DB, MinIO, AI inference engines, export assembly/watermarking — these are backend dependencies.[file:29]
- Non-negotiables for mobile: follow TRD constraints for decoder pool, SPKI pinning, refresh lock, token containment, and forbidden use of PlatformView for streaming.[file:29]

7) Mobile-Relevant Phase 1 Requirements (detailed)
- Auth & sessions:
  - POST /api/v5/auth/login → returns accessToken + secure Set-Cookie vms_refresh; accessToken must be stored only in volatile app memory and optionally encrypted refresh token in Keystore/Keychain if allowed.[file:29]
  - POST /api/v5/auth/refresh → uses HttpOnly cookie to rotate access token; mobile must call this via the transport (cookie handled by the HTTP client) and serialize refresh requests via RefreshLock.[file:29][file:30]
  - Logout flow must call POST /api/v5/auth/logout and clear local volatile state.[file:29]
- HLS live view:
  - Mobile requests signed HLS URL from control plane (tenant-scoped).
  - Player must use HLS, not WebRTC; the decoder cap is 4 hardware decoders overall.
  - UI: show placeholder while loading, clear error/offline overlay when stream unavailable.[file:29]
- Playback timeline:
  - Request metadata and playback signed HLS URL from backend.
  - Provide timeline scrub, coarse/precise seek, and speed control (Phase 1).
  - Provide clear failure/error states for missing segments or expired signed URL.[file:28][file:29]
- Evidence export UI:
  - Mobile surfaces export initiation only if backend indicates permission; actual assembly & watermarking are backend tasks; mobile triggers export by calling backend endpoint and displays export status/result (signed URL) respecting expiration behavior.[file:28]
- Session handling:
  - Implement RefreshLock using a Dart Completer-based pattern to avoid refresh storms across concurrent requests.
  - Validate Redis session presence: backend may revoke session; mobile must respond by logging out or restricting access gracefully.[file:29]
- Role-aware access:
  - The UI must hide actions not allowed by the user's role (Viewer vs Operator vs Admin). Server enforces final 403 decisions, but UI must not present forbidden buttons.[file:28]
- Security:
  - SPKI pinning to Vault Intermediate CA hash; store auth material only in Android Keystore/iOS Secure Enclave when needed; do not store JWT in localStorage or persistent plaintext stores.[file:29]

8) Feature-by-feature mobile responsibilities (concise)
- Login/auth (mobile): present login & MFA UI, call POST /api/v5/auth/login, store access token in AuthBloc memory, store refresh token securely if allowed, and call refresh endpoint when needed with serialization.[file:29]
- HLS live view (mobile): request signed HLS path, open in Texture-based player, enforce DecoderPool cap (4), show offline/buffering overlays.[file:29]
- Playback timeline scrubber (mobile): request playback signed URL & metadata, present timeline with scrub, seek and speed controls, and handle expired/partial segments.[file:28][file:29]
- Evidence export wizard UI (mobile): provide UI to request export, show status & signed-download handling (do not assemble locally). [file:28]
- Session handling (mobile): implement RefreshLock and safe token persistence; handle revocation by logout UI; serialize refresh and retry logic.[file:29][file:30]
- Role-aware access consumption (mobile): read role fields from the server-issued user object and render only allowed actions (read-only for Viewer, live/playback and export UI available for permitted roles).[file:28]

9) Sagar Technical Contract (developer rules)
- Always preserve backend ownership: do not implement or assume responsibility for media ingest, export assembly, recording retention, or audit logging.[file:29]
- Security & storage:
  - Store access token in volatile AuthBloc only.
  - If storing refresh token to persist session across app restarts, encrypt and place it in Android Keystore or iOS Keychain Secure Enclave only.[file:29]
  - Always implement SPKI pinning to the Vault Intermediate CA fingerprint provided by Vault; reject any chain that does not match.[file:29]
- Networking:
  - Use HTTPS with TLS 1.3.
  - Use the backend’s signed HLS URLs; do not attempt to fetch raw camera/RTSP streams.
  - Respect same-site cookie semantics; rely on HttpOnly refresh cookie for /auth/refresh.
- Streaming:
  - Use Texture-based video rendering, not PlatformView for the streaming surface.
  - Limit active hardware decoders to 4 (DecoderPool).
  - Wrap each tile inside a RepaintBoundary to isolate rendering.
- Concurrency:
  - Centralize all token refresh through a single RefreshLock (Completer-based).
  - Prevent concurrent refresh network calls from multiple widgets/tiles.
- UI:
  - Do not present controls that require backend write capabilities unless role indicates permission.
  - For PTZ, show a non-functional stub (Phase 1) or hide entirely.[file:29]
- Testing:
  - Unit tests for RefreshLock, decoder counting, secure storage, SPKI check, playback error handling, and auth flows must exist before shipping.[file:29]

10) Mobile Implementation Checklist & prioritized plan

Priority order (concrete)
1. Authentication & Session (AuthBloc): login, MFA screen, refresh flow, logout, RefreshLock, secure storage integration, tests. [Blocker for rest][file:29][file:30]
2. Camera list & role-aware browsing (API consumption): GET /api/v5/cameras endpoint usage, tenant-scoped listing. [file:29]
3. Live HLS player (LiveViewBloc): open signed HLS URLs, implement DecoderPool cap (4), placeholder / offline overlays, 1×1 & 2×2 grid UI. [file:29]
4. Playback screen (PlaybackBloc): timeline scrubber, seek, speed control; request playback signed URLs and metadata. [file:28][file:29]
5. Alarm handling (AlarmBloc): WebSocket client, subscription to tenant-scoped channels, push integration (FCM/APNs) and backoff/polling fallback. [file:30]
6. Export UI surface: export initiation call, status polling, signed-download handling (do not assemble locally). [file:28]
7. Telemetry & logs (client-side): event logging to backend as permitted, error reporting, instrumentation (non-sensitive). [file:29]
8. UX polish and edge-case handling: network quality indicators, decoder availability UI, device capability gating. [file:29]

Implementation tasks (developer-level)
- Wire Dio/OkHttp/NSURLSession with SPKI pinning and cookie jar that supports HttpOnly refresh cookie transport for /api/v5/auth/refresh.[file:29]
- Implement AuthBloc, LiveViewBloc, PlaybackBloc, AlarmBloc, ConnectivityBloc and a central SessionGuardBloc that can force logouts or re-auth when Redis revocation occurs.[file:30]
- Implement DecoderPool service with counting and acquire/release semantics used by video tiles; fail tile open if acquire fails beyond cap and show explanatory UI.[file:29]
- Implement RefreshLock — serialize refresh calls and queue original requests to retry after refresh completes.[file:30]
- Implement secure storage wrapper (Keystore / Secure Enclave) and tests for token write/read/erase lifecycle.[file:29]
- Implement WebSocket client with sticky-session support for testing (note: sessionAffinity: ClientIP on k8s is a server-side requirement — mobile must provide stable client behavior and reconnect logic).[file:29][file:30]

11) Mobile Acceptance Criteria (MVP)
- Auth/Session:
  - Successful login yields an access token in App memory and refresh cookie set by server; re-open app preserves session if refresh token is stored in secure storage and refresh returns a new access token.[file:29]
  - RefreshLock prevents concurrent refresh requests and original requests are retried post-refresh.[file:30]
  - Logout clears session state and the app returns to login screen.[file:29]
- Live view:
  - Mobile can open 1×1 and 2×2 HLS streams using signed URLs; P95 initial play start ≤ 5s for available streams (subject to network). DecoderPool never exceeds 4 concurrent hardware decoders.[file:29]
  - Offline or expired signed URL results in visible overlay explaining the issue and offering retry.[file:29]
- Playback:
  - Timeline scrub, seek, and speed controls function and display time accurately; seeks either succeed or show clear error if the segment is missing or URL expired.[file:28]
- Alarm handling:
  - When app is foregrounded and connected, alarms arrive within expected system latency via WebSocket and appear in alarm feed; when backgrounded, push delivery arrives via FCM/APNs within acceptable timeliness.[file:30]
- Security:
  - SPKI pinning validation is implemented; any mismatch blocks network calls and surfaces a clear trust error to the user.[file:29]

12) App Flows (screen-level) — rewrite to mobile terms

A. Login & Session Flow (screen steps)
- Trigger: open app → show splash → check secure storage for existing refresh token.
- Mobile request: if no token, show Login screen → POST /api/v5/auth/login (customer_id, email, password, totpCode).
- Response handling: on 200 store accessToken in AuthBloc memory; if allowed, store encrypted refresh token in Keystore and let Cookie jar retain vms_refresh for future refresh calls. otherwise show error messages mapping to 401/429/lockout.
- State updates: AuthBloc authenticated -> navigate to Home.
- Failure states: 401 -> show generic "Invalid credentials"; 429 -> show retry-after and lockout guidance; locked account -> show "temporarily locked".
- Refresh: auth interceptor sees 401 -> attempt RefreshLock -> POST /api/v5/auth/refresh -> if success update AuthBloc and retry original request; otherwise force logout.[file:29][file:30]

B. Live View Flow (screen steps)
- Trigger: user taps a camera or opens Live Grid.
- Mobile request: GET camera list (tenant scoped), then request signed HLS URL for chosen camera via control plane endpoint (e.g., GET /api/v5/cameras/{id}/stream or similar).
- Response: signed HLS URL returned.
- Player: Acquire decoder from DecoderPool; open HLS player using Texture-based rendering; wrap tile in RepaintBoundary.
- UI state: Loading spinner -> Buffering -> Playing. show small latency indicator and connection quality icon.
- Failure states: signed URL expired -> show "stream unavailable" overlay; decoder limit reached -> show "tile unavailable; close other tiles" hint; network lost -> show retry button.
- Recovery: On reconnect or new signed URL, retry with exponential backoff and re-acquire decoder.[file:29]

C. Playback Flow (screen steps)
- Trigger: user opens playback for camera/time range.
- Mobile request: GET playback metadata + signed playback HLS URL from backend.
- Response: HLS playback URL and timeline metadata (start/end, seek points).
- Player and UI: show timeline scrubber and speed control; user can scrub and press play; implement logic to prefetch segments if possible.
- Failure states: missing segments or expired URLs -> show contextual message and "Request fresh clip" action (which triggers a backend call).
- Export: user can tap Export UI (if role allows) to request an evidence clip. Mobile calls export endpoint; backend assembles and returns signed download URL later; mobile shows export status in a separate Export screen or notifications.[file:28]

D. Alarm/Event Flow (screen steps)
- Trigger: AIEYE detection triggers event -> backend creates alarm and publishes to ws-broadcaster and push services.
- Mobile behavior while app foregrounded:
  - Mobile opens WebSocket connection on login and authenticates; subscribe to tenant/site alarm channels.
  - On receiving alarm, AlarmBloc appends item and optionally shows an in-app banner; user can tap to open LiveView or Playback (if allowed).
- Mobile behavior while backgrounded:
  - Backend sends push notification via FCM/APNs; tapping notification opens app to Alarm detail screen or Live or Playback (behavior should be product-approved).
  - If WebSocket is disconnected, app will reconcile on resume by fetching alarm list via GET /api/v5/alarms (short poll).
- Failure & fallback:
  - If push delivery fails, on resume app polls alarms; if WebSocket is disconnected, app displays offline indicator and offers reconnect. Use light background polling only if product requires it — otherwise rely on push and reconnect flows.[file:30]

E. Export status
- Trigger: user initiates export (export wizard UI).
- Mobile request: POST /api/v5/exports (payload: cameraIds, time range, reason, requestedBy).
- Backend dependency: export assembly, watermarking, and signed URL generation are backend tasks (MinIO + media core + audit logging). Mobile must poll export status or receive a push/websocket update when export ready.
- UI & state: show export progress and once backend returns signed URL, mobile displays Download button and warns about expiry window. Keep export UI on a dedicated Export screen for clarity and to avoid conflating alarms and exports.[file:28]

13) Bloc / State Design Implications (detailed)
- AuthBloc: holds user profile, role, customer_id, site scope, access token (volatile). Exposes isAuthenticated streams and events for login/logout/refresh/failure.
- SessionGuardBloc: monitors connectivity, token expiry times, Redis revocation signals (via API), and forces logout when necessary.
- LiveViewBloc: manages acquisition and release of decoders, current tiles, tile states (loading/playing/error), and per-tile signed URL expiry.
- PlaybackBloc: manages playback HLS URL, timeline position, playing state, speed, and seek requests. Should be able to cancel pending seeks if new ones arrive.
- AlarmBloc: maintains alarm list, unread counts, badge counts, and current selected alarm. Supports in-app banner display and deeplink navigation actions.
- ExportBloc: maintains export requests list, statuses, and signed-download URLs with expiry.
- Concurrency: All network calls must go through a centralized HTTP client that uses SPKI pinning and supports automatic cookie handling for refresh.[file:29]

14) Failure Modes & What Breaks Mobile If Backend/Media Is Wrong
- Auth contract mismatch (login/refresh) -> app cannot maintain sessions; must force relogin and show correct errors.[file:29]
- Bad tenant scope in responses -> shows no cameras or wrong cameras; mobile must treat this as an authorization error and ask backend for correction rather than attempting local fixes.[file:29]
- Signed HLS URL failures (expired/invalid) -> streams cannot play; show clear UI and retry ability; do not attempt raw stream fallback.[file:29]
- Decoder overload if backend returns many streams or user requests large grid -> app must enforce local decoder cap; otherwise device will fail.[file:29]
- WebSocket broadcaster issues -> alarm latency or missing alarms; mobile should rely on push or poll fallback on resume to maintain correctness.[file:30]
- Export assembly failures (backend) -> mobile must surface the export error and not try to reconstruct clip locally.[file:28]

15) Feature Matrix & Phase classification (summary)
- Mobile Phase 1 MVP (must build):
  - login/auth, refresh/logout (AuthBloc)
  - role-aware camera list
  - HLS live view (1×1 / 2×2), DecoderPool cap
  - playback scrub/seek/speed
  - alarm consumption (WebSocket primary + push fallback)
  - secure storage & SPKI pinning
  - export UI surface & export status consumption (UI only)
- Mobile later phase:
  - PTZ (actual control), 2-way audio, thumbnails/storyboards, advanced timeline heatmaps, multi-site advanced UI
- Mobile visibility only:
  - camera discovery, recording scheduling, retention controls, evidence watermarking internals, health dashboards (display-only)
- Not Sagar scope:
  - media core, edge agent, backend DB schema, event-workers internal logic, minio, vault management, federation, HA infra.

16) Conflicts, Clarifications, Open Questions
- PTZ: VMSfeatures lists PTZ for mobile, but TRD/PRD clearly scopes PTZ to edge/server and defers true mobile PTZ to later phases. Clarify if Phase 1 needs PTZ UI or only a stub.[file:28][file:29][file:32]
- Play thumbnails/storyboards: VMSfeatures lists thumbnails as "Standard", TRD and earlier mobile scope prioritized scrub/seek/speed. Need to confirm whether backend will supply thumbnails in Phase 1.[file:28][file:32]
- Alarm transport: APP_FLOW and TRD include both WebSocket and push paths. Phase 1 recommendation: WebSocket primary, push fallback, but confirm product preference.[file:30]
- Export UI: Is initiating exports from mobile required in Phase 1, or only viewing export status once exported? Backend must confirm export endpoints and signed URL TTL for mobile UX.[file:28]
- Decoder cap device negotiation: TRD states 4 is hard ceiling. Do we allow a capability-negotiation step per-device to lower that number for low-end phones, or must mobile always use a 4-cap assumption? (Prefer negotiation.)[file:29]
- SPKI fingerprint: Backend/Vault must provide the intermediate CA SPKI SHA-256 string to implement pinning; request this value from Vault owners.[file:29]

17) Appendices (useful extracts & developer notes)

A. Auth endpoints (Phase 1 examples, preserved)
- POST /api/v5/auth/login
  - Body: { customer_id, email, password, totpCode }
  - Response 200: { accessToken, user: { userId, customer_id, username, baseRole } } and Set-Cookie: vms_refresh=...; HttpOnly; Secure... [file:29]
- POST /api/v5/auth/refresh
  - Uses HttpOnly cookie vms_refresh; returns new accessToken; may rotate cookie.
- POST /api/v5/auth/logout
  - Requires Authorization: Bearer {token}; returns 204.

B. Sample token lifecycle rules
- JWT lifetime: ~8 hours (token) and refresh cookie TTL: 30 days (backend); Redis session TTL matches access token lifetime in some flows (8h) and is used for immediate revocation [file:29].
- RefreshLock pseudocode (Dart Completer pattern) should be implemented in mobile to avoid multiple concurrent refresh calls.[file:30]

C. DecoderPool rules (developer note)
- Must expose API to acquire decoder before creating player: bool acquireDecoder(String tileId), releaseDecoder(String tileId).
- Enforce FIFO/priority policy: visible tiles > background tiles; when max reached, deny opening another tile and show UI to close some tiles or downgrade quality.
- Decoder cap is 4 hardware decoders — treat this as absolute limit for Phase 1 unless backend instructs otherwise.[file:29]

D. SPKI pinning
- Obtain intermediate Vault CA SPKI SHA-256 fingerprint (base64) from Vault owners; implement strict pin check in both Android (OkHttp network interceptor) and iOS (NSURLSession delegate).

E. Alarm transport model
- WebSocket for real-time when app is foregrounded with an active connection; FCM/APNs for background notification delivery; short polling on resume as fallback. The backend provides ws:alarm:{customer_id}:{siteId} pub/sub channels and push service via push-notification service in event-workers.[file:30]

---

End of document.
