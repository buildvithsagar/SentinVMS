# Mobile Client — Micro-Phase A: Security, Auth & Storage

This document details the visual architectural specifications, implementation decisions, and code files created for **Micro-Phase A: Security, Auth & Storage (Foundation)**.

---

## 1. Approved Architectural Decisions

*   **Native Cryptoprocessors Storage (F09):** The sensitive `vms_refresh` token is persisted strictly inside hardware-backed storage (iOS Keychain utilizing `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`; Android Keystore utilizing `EncryptedSharedPreferences`).
*   **Transient Access Tokens:** The short-lived `accessToken` is stored strictly in volatile RAM (the heap space of `AuthBloc`). It is never written to disk.
*   **Intermediate CA SPKI Pinning (F10):** The `Dio` HTTP adapter pins connection trust to the HashiCorp Vault Intermediate CA certificate's public key hash (base64 SHA-256 SPKI), rejecting rogue certificates. A compile-time bypass flag (`--dart-define=BYPASS_PINNING=true`) is available for local emulators.
*   **Concurrent RefreshLock interceptor:** Fired concurrent requests waiting on 401 errors are paused using a single `Completer<void>? _refreshCompleter` lock queue, executing exactly one `/api/v5/auth/refresh` request and retrying when resolved.

---

## 2. Sequence Diagram: Authentication Lifecycle

Demonstrates the flow of credential submission down to NestJS Gateway, cookie extraction, and native MethodChannel storage partition.

```mermaid
sequenceDiagram
    autonumber
    actor Operator as Operator UI
    participant LoginBloc as LoginBloc
    participant AuthRepo as AuthRepository
    participant Gateway as NestJS API Gateway
    participant Storage as SecureStorageService
    participant Native as Native Keystore/Keychain
    participant AuthBloc as AuthBloc (In-Memory)

    Operator->>LoginBloc: Submit Credentials (customer_id, email, password, totp)
    LoginBloc->>AuthRepo: login(customerId, email, password, totp)
    AuthRepo->>Gateway: POST /api/v5/auth/login
    Note over Gateway: Authenticates & sets HttpOnly Cookie<br/>vms_refresh = sha256_hash
    Gateway-->>AuthRepo: Response: { accessToken, user } + Set-Cookie Header
    AuthRepo->>AuthRepo: Extract vms_refresh value from Set-Cookie header
    AuthRepo->>Storage: storeRefreshToken(vms_refresh)
    Storage->>Native: MethodChannel('write', key, value)
    Note over Native: Android: EncryptedSharedPreferences (AES256-GCM)<br/>iOS: Keychain (kSecAttrAccessibleWhenUnlocked)
    AuthRepo-->>LoginBloc: Return AuthResult
    LoginBloc->>AuthBloc: AuthLoggedIn(accessToken, user)
    Note over AuthBloc: Hydrates volatile state in memory.<br/>Access token never hits disk!
    LoginBloc-->>Operator: Transition UI -> /live_grid
```

---

## 3. Sequence Diagram: Concurrent Token Rotation (RefreshLock)

Demonstrates how the `Completer` gate handles multiple concurrent HTTP calls when the token expires.

```mermaid
sequenceDiagram
    autonumber
    participant Client as Multi-Tile Viewport (Dio)
    participant Interceptor as RefreshTokenInterceptor
    participant Bloc as AuthBloc
    participant Storage as SecureStorageService
    participant Gateway as NestJS API Gateway

    Note over Client: Concurrent requests (Req A & Req B) sent with expired token
    Client->>Interceptor: Request A fails (401 Unauthorized)
    Client->>Interceptor: Request B fails (401 Unauthorized)
    
    Note over Interceptor: Request A triggers rotation
    Note over Interceptor: Instantiates _refreshCompleter = Completer()
    Interceptor->>Storage: getRefreshToken()
    Storage-->>Interceptor: returns vms_refresh token
    
    Note over Interceptor: Request B detects active Completer!<br/>Awaits _refreshCompleter.future
    
    Interceptor->>Gateway: POST /api/v5/auth/refresh (Cookie: vms_refresh=...)
    Gateway-->>Interceptor: returns { accessToken } + new Set-Cookie (rotated)
    Interceptor->>Storage: storeRefreshToken(new_vms_refresh)
    Interceptor->>Bloc: AuthTokenRefreshed(newAccessToken)
    Note over Bloc: Updates in-memory token
    
    Interceptor-->>Interceptor: _refreshCompleter.complete()
    Note over Interceptor: Request B wakes up!
    
    Interceptor->>Client: Retry Request A (Authorization: Bearer newAccessToken)
    Interceptor->>Client: Retry Request B (Authorization: Bearer newAccessToken)
    
    Note over Client: Both requests complete successfully (200 OK)
```

---

## 4. Block Diagram: Volatile RAM vs. OS Sandboxing

```mermaid
graph TD
    subgraph RAM [Volatile Application RAM]
        AuthBloc[AuthBloc State]
        AT[accessToken: JWT String]
        User[UserProfile Object]
        AuthBloc --> AT
        AuthBloc --> User
    end

    subgraph Sandbox [Native Platform Security Sandbox]
        subgraph Android [Android Security Framework]
            EncPrefs[EncryptedSharedPreferences]
            Keystore[Android Keystore TEE / StrongBox]
            EncPrefs -.->|AES-256-GCM Encrypted| Keystore
        end

        subgraph iOS [iOS Security Framework]
            Keychain[Enclave-backed Keychain Service]
            Access[kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
            Keychain -.->|Access Control| Access
        end
    end

    StorageService[Dart SecureStorageService]
    StorageService -->|MethodChannel| EncPrefs
    StorageService -->|MethodChannel| Keychain
    
    RT[vms_refresh: Refresh Token Cookie]
    StorageService -.->|Persists & Rotates| RT
    RT --> EncPrefs
    RT --> Keychain
    
    classDef RAMColor fill:#0D0E12,stroke:#02965E,stroke-width:2px,color:#E2E8F0;
    classDef SandboxColor fill:#14161F,stroke:#70788C,stroke-width:1px,color:#E2E8F0;
    class AuthBloc,AT,User RAMColor;
    class Android,iOS,EncPrefs,Keystore,Keychain,Access SandboxColor;
```

---

## 5. Implementation File References

*   **Security Methods Bridge:** [secure_storage_service.dart](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/lib/core/storage/secure_storage_service.dart)
*   **CA Pinning & HttpClient Adapter:** [dio_factory.dart](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/lib/core/network/dio_factory.dart)
*   **Rotation Interceptor:** [refresh_token_interceptor.dart](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/lib/core/network/refresh_token_interceptor.dart)
*   **Transient State Handler:** [auth_bloc.dart](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/lib/core/auth/auth_bloc.dart)
*   **Form Login Page Layout:** [login_page.dart](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/lib/features/login/login_page.dart)
