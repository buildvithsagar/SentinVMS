# Mobile Client — Micro-Phase B: Camera Registry & Status Telemetry

This document details the architectural specifications, sequence flows, and implementation reference mappings for **Micro-Phase B: Camera Registry & Status Telemetry (Metadata)**.

---

## 1. Approved Architectural Decisions

*   **WebSocket State Mapping:** A single [WebSocketService](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/lib/core/network/websocket_service.dart) runs as a singleton in the dependency injector. It monitors the state of `AuthBloc`:
    *   Initiates connection when user logs in (`Authenticated` state).
    *   Disconnects socket when user logs out (`Unauthenticated` state).
    *   Reconnects using the brand new token when the interceptor executes a refresh rotation (token changes inside `Authenticated` state).
*   **Reconnection Telemetry Reconciliation:** If the connection drops, the service reconnects using exponential backoff (capped at 30 seconds). To prevent missing status update packets during connection downtime, the [CameraBloc](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/lib/features/camera/bloc/camera_bloc.dart) intercepts the socket status transitioning back to `connected` and triggers **Reconciliation on Resume** by calling `GET /api/v5/cameras` again.
*   **Site-Level Subscription:** Active camera updates are restricted by site. When fetching cameras for a specific `siteId`, the app writes a subscription payload onto the socket: `{ "event": "subscribe:site", "data": { "siteId": siteId } }`. The service stores these active subscriptions and resubscribes automatically upon connection restoration.

---

## 2. Sequence Diagram: WebSocket Auth Synchronization Flow

Demonstrates how the WebSocket connection handles logins, logouts, and token rotation updates dynamically.

```mermaid
sequenceDiagram
    autonumber
    participant Bloc as AuthBloc
    participant WS as WebSocketService
    participant Gate as NestJS Ingress / WS Broadcaster

    Note over WS: Listens to AuthBloc stream
    
    Bloc->>WS: State changed: Authenticated (token_A)
    WS->>WS: Extract token_A
    WS->>Gate: Connect to wss://.../ws?token=token_A
    Gate-->>WS: Connection Established (Status: Connected)
    
    Note over WS: Session token expires & rotates in background
    Bloc->>WS: State changed: Authenticated (token_B)
    WS->>WS: Detects new token!
    WS->>Gate: Disconnect active socket
    WS->>Gate: Connect to wss://.../ws?token=token_B
    Gate-->>WS: Re-established Connection (Status: Connected)
    
    Bloc->>WS: State changed: Unauthenticated (Logout)
    WS->>Gate: Disconnect socket
    WS->>WS: Enter state: Disconnected
```

---

## 3. Sequence Diagram: Reconnection Telemetry Reconciliation

Demonstrates how the client handles network dropouts and prevents stale online/offline UI statuses.

```mermaid
sequenceDiagram
    autonumber
    participant App as CameraListPage UI
    participant Bloc as CameraBloc
    participant WS as WebSocketService
    participant Repo as CameraRepository
    participant Gate as WS Broadcaster / Gateway

    WS->>Gate: Connection active (Subscribed: Site_X)
    Note over Gate: WAN outage occurs / Socket disconnects
    Gate-xWS: Connection lost
    WS->>WS: Trigger status change -> disconnected
    WS->>Bloc: Broadcast status change
    
    Note over WS: Exponential Reconnect loop starts (1s, 2s, 4s...)
    WS->>Gate: Try reconnection
    Gate-->>WS: Reconnected (Status: Connected)
    
    WS->>Gate: Resend subscription: subscribe:site (Site_X)
    WS->>Bloc: Broadcast status change -> connected
    
    Note over Bloc: Reconciliation on Resume triggered!
    Bloc->>Repo: FetchCameras(siteId: Site_X)
    Repo->>Gate: GET /api/v5/cameras?siteId=Site_X
    Gate-->>Repo: Paginated list (Updated telemetry states)
    Repo-->>Bloc: List of Cameras
    Bloc->>App: Yield CameraLoaded (Repaint UI with reconciled states)
```

---

## 4. Block Diagram: Camera Domain Structure & Site Grouping

```mermaid
graph TD
    subgraph Repository [Camera Data Repository]
        Fetch[GET /api/v5/cameras]
    end

    subgraph Service [Telemetry Broadcast Service]
        WSStream[WebSocket Service Event Stream]
    end

    subgraph Bloc [Camera Bloc State Machine]
        FetchEvent[FetchCameras Event]
        StatusEvent[UpdateCameraStatus Event]
        State[CameraLoaded State]
        
        FetchEvent -->|Calls Repository| Fetch
        StatusEvent -->|Modifies Telemetry| State
        WSStream -->|Translates camera.status| StatusEvent
    end

    subgraph UI [CameraListPage UI Viewport]
        Group[Group & Sort by siteId]
        Render[Render Grouped Cards]
        Jade[ONLINE Indicator dot: #02965E]
        Crimson[OFFLINE Indicator dot: #D32F2F]
        
        State -->|Feeds list| Group
        Group --> Render
        Render -->|Status == CONNECTED| Jade
        Render -->|Status != CONNECTED| Crimson
    end
    
    classDef domain fill:#14161F,stroke:#E65100,stroke-width:2px,color:#E2E8F0;
    classDef uiStyle fill:#0D0E12,stroke:#02965E,stroke-width:2px,color:#E2E8F0;
    classDef leaf fill:#14161F,stroke:#70788C,stroke-width:1px,color:#E2E8F0;
    
    class Repository,Service,Bloc domain;
    class UI uiStyle;
    class Group,Render,Jade,Crimson leaf;
```

---

## 5. Implementation File References

*   **Camera Model:** [camera_model.dart](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/lib/features/camera/models/camera_model.dart)
*   **REST Repository Client:** [camera_repository.dart](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/lib/features/camera/data/camera_repository.dart)
*   **WebSocket Broadcast Service:** [websocket_service.dart](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/lib/core/network/websocket_service.dart)
*   **Camera Directory State Bloc:** [camera_bloc.dart](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/lib/features/camera/bloc/camera_bloc.dart)
*   **Directory Viewport Layout:** [camera_list_page.dart](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/lib/features/camera/presentation/camera_list_page.dart)
