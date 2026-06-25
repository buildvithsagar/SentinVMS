# Enterprise VMS Mobile Client — Micro-Phase A Architectural Blueprint

This document contains visual architectural specifications, flow diagrams, and detailed descriptions of **Micro-Phase A: Security, Auth & Storage (Foundation)**. 

You can directly copy-paste the `mermaid` code blocks below into any markdown editor (like VS Code, GitHub) or the **[Mermaid Live Editor](https://mermaid.live)** to generate vector diagrams for design reviews, presentations, or onboarding team members.

---

## Table of Contents
1. [Network Layer Trust Validation (Intermediate CA Pinning & Dev Bypass)](#1-network-layer-trust-validation)
2. [Secure Multi-Tenant Login Sequence](#2-secure-multi-tenant-login-sequence)
3. [Concurrent Token Rotation & RefreshLock Flow](#3-concurrent-token-rotation--refreshlock-flow)
4. [Memory Separation Architecture (Volatile RAM vs. OS Sandboxing)](#4-memory-separation-architecture)
5. [Code Mapping Reference](#5-code-mapping-reference)

---

## 1. Network Layer Trust Validation

### The Problem it Solves
Standard mobile applications trust all Root Certificate Authorities (CAs) pre-installed on the user's operating system. If a malicious actor installs a rogue Root CA on a device (or compromises a public CA), they can conduct a Man-in-the-Middle (MitM) attack, decrypting TLS traffic. 

### Architectural Approach
We restrict the application's network client (`Dio`) to **only trust our specific Intermediate CA certificate**. This is called **SPKI (Subject Public Key Info) Pinning** at the certificate chain level.
* **Production Mode:** Native `SecurityContext` rejects all traffic unless verified by the compiled PEM-encoded Intermediate CA certificate.
* **Development Mode:** An environment flag (`--dart-define=BYPASS_PINNING=true`) triggers a fallback to the OS default context, enabling bad certificate callbacks for self-signed development certificates on local emulators.

### Mermaid Diagram Code
```mermaid
graph TD
    subgraph NetworkClient [Dio Client Adapter Initialization]
        A[Start API Request] --> B{Bypass Pinning Enabled?<br>--dart-define=BYPASS_PINNING=true}
    end

    subgraph DevMode [Development Sandbox]
        B -->|Yes| C[Use SecurityContext.defaultContext]
        C --> D[Allow Self-Signed Certs<br>badCertificateCallback = true]
        D --> E[Establish Connection to Dev Server]
    end

    subgraph ProdMode [Hardened Production Mode]
        B -->|No| F[Create clean SecurityContext]
        F --> G[Inject Compiled Intermediate CA PEM Bytes]
        G --> H[Strictly Reject bad certificates<br>badCertificateCallback = false]
        H --> I{Verify Server Certificate Chain}
        I -->|Signature Matches CA Pin| J[TLS Handshake Complete<br>Allow Request]
        I -->|Signature Mismatch / Untrusted CA| K[Strict TLS Rejection<br>Handshake Exception]
    end

    classDef dev fill:#14161F,stroke:#E65100,stroke-width:2px,color:#E2E8F0;
    classDef prod fill:#14161F,stroke:#02965E,stroke-width:2px,color:#E2E8F0;
    classDef base fill:#0D0E12,stroke:#70788C,stroke-width:1px,color:#E2E8F0;
    
    class C,D,E dev;
    class F,G,H,I,J,K prod;
    class A,B base;
```

---

## 2. Secure Multi-Tenant Login Sequence

### The Problem it Solves
User credentials and sessions must be sharded by tenant identifier (`customer_id`) to ensure isolation in Vivek's Control Plane. Access tokens must remain transient, while refresh tokens must be securely stored inside platform hardware without manual interception.

### Architectural Approach
1. The user logs in with credentials alongside their `customer_id`.
2. The server responds with a short-lived `accessToken` in the JSON body, and a long-lived `vms_refresh` token via a secure `Set-Cookie` header.
3. The client repository extracts the `vms_refresh` token, saving it to secure native hardware storage via platform method channels, and fires an event to transition the state machine (`AuthBloc`) using only the volatile access token in RAM.

### Mermaid Diagram Code
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

## 3. Concurrent Token Rotation & RefreshLock Flow

### The Problem it Solves
When a multi-tile dashboard viewport loads, the app fires multiple parallel API calls simultaneously. If the access token expires, all concurrent calls return a `401 Unauthorized` status at the same moment. Without a concurrency gate (a "Refresh Lock"), the app would attempt to refresh the token multiple times concurrently, causing race conditions, invalidating rotated tokens, and force-logging the user out.

### Architectural Approach
We use an asynchronous **`Completer`** lock in the `RefreshTokenInterceptor`:
1. The first request that fails with a `401` instantiates a `Completer<void>? _refreshCompleter = Completer()`.
2. Subsequent `401` errors detect this active completer and pause their execution by awaiting its future.
3. Once the first request successfully executes the token refresh and stores the new credentials, it completes the completer, resolving the paused queue.
4. All waiting requests wake up, update their headers with the brand new access token, and retry their operations without the user experiencing any interruption.

### Mermaid Diagram Code
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

## 4. Memory Separation Architecture

### The Problem it Solves
If a device is root-compromised or subjected to physical memory extraction, any sensitive security token stored on the persistent disk layer can be recovered. 

### Architectural Approach
We enforce strict data containment zones:
* **In-Memory RAM Zone:** The short-lived `accessToken` is stored in the volatile heap context of the `AuthBloc` state. It is never written to disk, and is destroyed instantly when the application is swiped closed or the device loses power.
* **Native Platform Sandbox Zone:** The long-lived `vms_refresh` token is sent over method channels to OS-level storage. On Android, it utilizes `EncryptedSharedPreferences` backed by the hardware Keystore's Trusted Execution Environment (TEE) or StrongBox. On iOS, it uses the Keychain API with the configuration `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, preventing iCloud synchronization or backup retrieval.

### Mermaid Diagram Code
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

## 5. Code Mapping Reference

Here is a map of the architectural concepts to their specific implementation files in the codebase, enabling developers to jump directly to the code representing these designs:

* **Certificate Pinning & TLS Config:** [dio_factory.dart](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/lib/core/network/dio_factory.dart)
* **RefreshLock & Concurrency Gate:** [refresh_token_interceptor.dart](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/lib/core/network/refresh_token_interceptor.dart)
* **Platform Security Channels:** [secure_storage_service.dart](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/lib/core/storage/secure_storage_service.dart)
* **Transient State Machine:** [auth_bloc.dart](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/lib/core/auth/auth_bloc.dart)
* **Login & Authentication Handler:** [auth_repository.dart](file:///c:/Users/Sagar%20Agnihotri/OneDrive/Desktop/saasvms/mobile/lib/features/login/data/auth_repository.dart)
