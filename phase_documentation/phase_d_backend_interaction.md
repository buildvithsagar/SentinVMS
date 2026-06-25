# End-to-End System Interaction & Data Flows (Mobile ⇄ Web/Backend)

This document details how the mobile application interacts with the central SaaS gateway, the media streaming core, and real-time telemetry pipelines to ensure secure and optimized operations.

---

## 1. End-to-End System Architecture

The following diagram illustrates the complete flow of data and control signals between the Mobile Client, Vivek's SaaS Gateway, Vivek's WebSocket Broadcaster, and Saurabh's Media/Export Engines.

```mermaid
graph TD
    %% Define components
    subgraph MobileClient [Mobile Client Environment (Sagar's UI Shell)]
        AuthBloc[AuthBloc & Secure Storage]
        Dio[Dio Client with SPKI Pinning]
        WSS_Service[WebSocketService]
        DecPool[DecoderPool Semaphore]
        Timeline[TimelineScrubber UI]
        AlarmUI[AlarmListPage View]
        ExportUI[ExportPage Wizard]
    end

    subgraph SaaS_Gateway [Central SaaS Gateway (Vivek's Domain)]
        AuthAPI[Auth/Login REST Endpoints]
        CamAPI[Camera Registry REST Endpoints]
        AlarmAPI[Alarms REST Endpoints]
        ExportAPI[Exports REST Endpoints]
    end

    subgraph Media_Core [Media Core & Engines (Saurabh's Domain)]
        HLS_Stream[HLS Streaming Core]
        ExpEngine[fMP4 Clip Export Engine]
    end

    subgraph Realtime_Core [Real-time Events Core]
        WSS_Broadcaster[Vivek's WebSocket Broadcaster]
    end

    %% Auth Flows
    AuthBloc -->|1. Credentials + SPKI Verification| AuthAPI
    AuthAPI -->|2. Returns JWT Access & Refresh Tokens| AuthBloc

    %% Registry & Status Flows
    Dio -->|3. Fetch Camera List| CamAPI
    CamAPI -->|4. Return Paginated Cameras DTO| Dio
    WSS_Service <-->|5. Subscribe to Status Telemetry| WSS_Broadcaster
    WSS_Broadcaster -->|6. Real-time Status Updates| WSS_Service

    %% Live View Flows
    Dio -->|7. Request Signed HLS Url| HLS_Stream
    HLS_Stream -->|8. Returns Signed HLS Url| DecPool
    DecPool -->|9. Limit to 4 Concurrent Leases| DecPool

    %% Playback Timeline Flows
    Timeline -->|10. Fetch Recording Segments| CamAPI
    Timeline -->|11. Request Seek HLS Playback URL| HLS_Stream

    %% Real-time Alarms Flows
    WSS_Broadcaster -->|12. Push Foreground Alarms| WSS_Service
    WSS_Service -->|13. Ingest Alarms| AlarmUI
    AlarmUI -->|14. Acknowledge Alarm| AlarmAPI

    %% Exports Flows
    ExportUI -->|15. Trigger Export Job| ExportAPI
    ExportAPI -->|16. Forward to Clip Generator| ExpEngine
    ExpEngine -->|17. Assemble fMP4, Watermark, & Sign| ExportAPI
    ExportUI -->|18. Poll Job Status / Download| ExportAPI

    %% Styling
    classDef clientStyle fill:#0D0E12,stroke:#02965E,stroke-width:2px,color:#E2E8F0;
    classDef gatewayStyle fill:#14161F,stroke:#1565C0,stroke-width:1.5px,color:#E2E8F0;
    classDef engineStyle fill:#14161F,stroke:#E65100,stroke-width:1.5px,color:#E2E8F0;
    classDef streamStyle fill:#14161F,stroke:#70788C,stroke-width:1px,color:#E2E8F0;

    class AuthBloc,Dio,WSS_Service,DecPool,Timeline,AlarmUI,ExportUI clientStyle;
    class AuthAPI,CamAPI,AlarmAPI,ExportAPI gatewayStyle;
    class HLS_Stream,ExpEngine engineStyle;
    class WSS_Broadcaster streamStyle;
```

---

## 2. Interaction Specifications

### A. Authentication & Session Lifespan (App ⇄ Web Backend)
*   **Access Token Management:** Stored strictly in volatile memory inside the `AuthState`. It is never written to persistent disk storage to prevent memory dumps from leaking active keys.
*   **Refresh Token Management:** Stored inside the device's hardware-backed container (EncryptedSharedPreferences using an AES-256-GCM key inside Android Keystore; kSecAttrAccessibleKeychain inside iOS Keychain).
*   **Auto-Rotation:** The client-side `RefreshTokenInterceptor` queues overlapping HTTP calls using a lock completer. Upon receiving a `401 Unauthorized`, it fetches a renewed JWT from `/api/v5/auth/refresh` before retrying the queued requests.

### B. Live Stream Management (App ⇄ Media Core)
*   **Signed HLS Feeds:** To display camera feeds, the client makes an authenticated request to `GET /api/v5/recordings/stream`. The Media Core validates permissions and returns a signed HLS URL with a short-lived token.
*   **Lease Control:** The client-side `DecoderPool` manages active rendering pipelines. When the user loads a grid layout:
    1.  The app requests a `DecoderLease`.
    2.  If active leases exceed 4, the oldest lease is evicted, releasing hardware decoder resources.
    3.  A new lease is allocated, and the video player initializes streaming.

### C. Time-bound Recorded Playback (App ⇄ Media Core)
*   **Segment Mapping:** The app queries `GET /api/v5/recordings/segments` to retrieve continuous and event-based video segment boundaries for a specific day.
*   **Interactive Seeks:** When an operator drags and drops the playhead inside the `TimelineScrubber`:
    1.  The scrubber translates the horizontal canvas offset to a timestamp.
    2.  The repository requests a play link starting at that timestamp from `GET /api/v5/recordings/playback`.
    3.  The video player loads the new URL and plays the stream.

### D. Foreground Alarms Telemetry (WebSocket Broadcaster ⇄ App)
*   **Reconciliation on Resume:** Real-time alarms are pushed via the WebSocket connection (`wss://api.vms.serviceprovider.com/ws`). If connection dropouts occur (e.g., during app suspension), the client automatically refetches the alarm journal from `GET /api/v5/alarms` on reconnection to reconcile status telemetry.
*   **Acknowledgement Sync:** Operators can acknowledge active alarms. The client posts to `POST /api/v5/alarms/{id}/acknowledge`, which updates the event state on the server and propagates the updated alarm object to the client's list.

### E. Evidence Export Wizard (App ⇄ Export Engine)
*   **Wizard Trigger:** Operators specify a camera and time range via the `ExportPage`. The client submits an export request (`POST /api/v5/exports`).
*   **Assembly & Watermarking:** The Export Engine compiles the recorded fragments, adds the corresponding watermarks/metadata, and signs the final fMP4 container.
*   **Status Polling:** The client queries `GET /api/v5/exports/{id}` periodically. Once the state transitions to `COMPLETED`, a signed download URL is provided.
