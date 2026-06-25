# Monorepo Path: docs/ownership/sagar_ownership.md

## Sagar — Phase 1 Ownership: Flutter Secure Core & Client UI Workspace (Track C)

**Role:** Sovereign Lead of Cross-Platform Mobile & Client UI Workspace
**Monorepo Target Workspace:** `mobile/` & `apps/web-client/features/`
**Phase:** 1 Standard SaaS Revision
**Features Lead (Mobile Client Layer Only):**
- F02 — Mobile HLS Live View Grid (1×1 and 2×2 only, Flutter only)
- F05 — Mobile Playback Timeline Scrubber UI (Flutter only — web portal F05 UI = Vivek)
- F06 — Mobile Evidence Export Wizard UI (Flutter only — export engine = Saurabh, web export UI = Vivek)
- F09 — Solo Cross-Platform Mobile App (Secure Auth, Hardware Token Containment, HLS Streaming)

> **Boundary Note (project.md Section 8):**
> - F02 full ownership = Saurabh (Media Core) + Vivek (Web Client). Sagar owns **mobile HLS shell only**.
> - F05 full ownership = Saurabh (Engine + Thumbnails) + Vivek (Web Portal UI). Sagar owns **mobile scrubber widget only**.
> - F06 full ownership = Saurabh (fMP4 assembly, watermarking, signing). Sagar owns **mobile export wizard UI only**.
> - F10 (System Encryption & Audits — Vault PKI, mTLS, HashiCorp CA, audit engine) = **Vivek exclusively**. Sagar's hardware token storage is F09 client-side Pillar 8 concern only.

---

## Architectural Mandate

- **Sovereign Track Ownership:** Sagar maintains sovereign control over the `mobile/` cross-platform Flutter codebase AND the `apps/web-client/features/playback/` & `apps/web-client/features/export/` workspace components to ensure UI/UX parity between desktop control rooms and field-mobile environments.
- **Dark Engineering Ergonomics (Anti-AI Vibe):** Interface construction must reject all "AI-generated" aesthetic trends (e.g., rainbow gradients, neon glows, glassmorphism, or amorphous meshes). UI must look human-made, structural, and utilitarian, modeled after premium dark tactical industrial cockpits.
- **Long-Shift Ergonomic Constraint:** High-contrast text glare and backlit glowing neons are prohibited. Readability is achieved via low-contrast matte surfaces (Primary Base: `#0D0E12`) and muted tactical accent colors, ensuring zero ophthalmic fatigue during 8-hour surveillance shifts.

Phase 1 mobile is STRICTLY LIMITED TO:
1. Secure login FORM — send credentials to Vivek's `/api/v5/auth/login` endpoint (Sagar does NOT implement login logic, only the UI + HTTP call)
2. Receive and store JWT access token in-memory (AuthBloc state only — never written to disk)
3. Store refresh token in hardware-backed native storage (Android Keystore / iOS Keychain) — F09 client-side Pillar 8 mandate
4. HLS live-view fallback via Cloud Media Core HLS endpoints
5. Playback timeline scrubbing UI (F05) — up to 16x speed, color-coded segments, keyframe thumbnails
6. Evidence export wizard UI (F06) — watermarked MP4 clip assembly

Phase 1 mobile does NOT include:
- WebRTC (deferred to Phase 2)
- WebAuthn FIDO2 (deferred to Phase 2)
- Alarm push handling (deferred to Phase 2)
- GPS stream-back (deferred to Phase 3)
- PTZ control (deferred to Phase 3)

Mobile app NEVER receives elevated session scope in Phase 1.

CRITICAL DISTINCTION FOR PEN TEST / AUDIT ACCURACY:
- Android Keystore: manages KEYS only (not JWT bytes). JWT bytes stored in
  EncryptedSharedPreferences encrypted with a Keystore-backed AES256-GCM key.
- iOS Keychain: stores JWT bytes directly inside the Keychain database, with
  kSecAttrAccessibleWhenUnlockedThisDeviceOnly attribute.
  These two must NEVER be described interchangeably in any documentation.

---

## Group C Target Work Distribution Split

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       VMS CLIENT UI & MOBILE REPOSITORY                     │
├──────────────────────────────────────┬──────────────────────────────────────┤
│ Track C1: Mobile Secure Core         │ Track C2: Client UI Workspace        │
│ Primary Owner: SAGAR                 │ Primary Owner: SAGAR                 │
├──────────────────────────────────────┼──────────────────────────────────────┤
│ — Flutter App (Secure Auth)          │ — Playback Timeline Scrubber UI      │
│ — Hardware-Isolated JWT Tokens       │ — Evidence Clip Export Wizard        │
│ — HLS Video Grid Engine              │ — Dynamic Site Management Selectors  │
│ — SPKI Certificate Pinning           │ — Ergonomic UI Palette Integration   │
└──────────────────────────────────────┴──────────────────────────────────────┘
```

---

## Sub-Phase C.0 — Flutter Repository Foundation

### Task C.0.1 — Flutter Project Initialization

```
mobile/
├── pubspec.yaml
├── analysis_options.yaml             -- very_good_analysis ruleset (strict)
├── lib/
│   ├── main.dart                     -- environment-aware entry point (dev/staging/prod)
│   ├── app/
│   │   ├── app.dart                  -- MaterialApp.router + GoRouter
│   │   └── router.dart               -- GoRouter with auth guard
│   ├── core/
│   │   ├── auth/                     -- AuthBloc, AuthState, AuthRepository
│   │   ├── network/                  -- Dio client, interceptors, SPKI pinning
│   │   ├── storage/                  -- platform channel abstraction
│   │   └── constants/                -- API URLs, timeouts, env config
│   ├── features/
│   │   ├── login/                    -- LoginPage, LoginBloc, LoginRepository
│   │   ├── live_view/                -- LiveViewPage shell (F02 — HLS grid)
│   │   ├── playback/                 -- TimelineScrubber, PlaybackBloc (F05)
│   │   └── export/                   -- ExportWizard, ExportBloc (F06)
│   └── l10n/                         -- ARB files EN + HI (Phase 2)
├── android/
│   └── app/src/main/kotlin/com/vms/app/
│       ├── MainActivity.kt
│       └── SecureStoragePlugin.kt    -- Android Keystore platform channel
├── ios/
│   └── Runner/
│       ├── AppDelegate.swift
│       └── SecureStoragePlugin.swift -- iOS Keychain + Secure Enclave platform channel
└── test/
    ├── unit/
    ├── widget/
    └── integration/
```

### Task C.0.2 — pubspec.yaml Dependencies

> **CLAUDE.md Alignment Note:** CLAUDE.md Section 7 mentions `flutter_secure_storage`. This project uses a **custom platform channel** (`SecureStoragePlugin.kt` / `SecureStoragePlugin.swift`) instead of the third-party package. Rationale: custom channel gives direct access to Android Keystore AES256-GCM key generation (not available via flutter_secure_storage's abstraction layer) and allows pen-test-accurate documentation of the exact security primitive used per platform. `flutter_secure_storage` would be an acceptable Phase 2 simplification after security audit sign-off.

```yaml
dependencies:
  flutter: { sdk: flutter }
  go_router: ^13.0.0
  flutter_bloc: ^8.1.0
  equatable: ^2.0.0
  dio: ^5.4.0
  video_player: ^2.8.0         # Saurabh's domain — declared here
  get_it: ^7.6.0
  logger: ^2.0.0
  mutex: ^3.1.0                # RefreshLock Completer pattern

dev_dependencies:
  very_good_analysis: ^6.0.0
  mocktail: ^1.0.0
  bloc_test: ^9.1.0
  build_runner: ^2.4.0
  json_serializable: ^6.7.0
```

### Task C.0.3 — analysis_options.yaml (Strict Lint)

```yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  errors:
    avoid_print: error
    prefer_const_constructors: warning
  exclude:
    - '**/*.g.dart'
    - '**/*.freezed.dart'

linter:
  rules:
    avoid_dynamic_calls: true
    avoid_type_to_string: true
    no_adjacent_strings_in_list: true
    prefer_final_locals: true
    avoid_classes_with_only_static_members: true
```

### Task C.0.4 — CI/CD Mobile Pipeline

```yaml
# .github/workflows/mobile-ci.yml
jobs:
  analyze:
    steps:
      - run: flutter analyze --fatal-infos --fatal-warnings
  test:
    steps:
      - run: flutter test --coverage
  build-android:
    steps:
      - run: flutter build apk --release --obfuscate --split-debug-info=build/debug-info/android
  build-ios:
    steps:
      - run: flutter build ipa --release --obfuscate --split-debug-info=build/debug-info/ios
  security-scan:
    steps:
      - run: mobsf-scan on APK and IPA artifacts
```

---

## Sub-Phase C.1 — Playback & Export Workspace (Track C2 — F05, F06)

### Task C.1.1 — Timeline Playback Scrubber (F05 — Standard Edition)

Port the timeline visualizer logic from the web client into the shared `libs/ui/` library, consumed by both Flutter and React portal.

**Phase 1 Feature Alignment (VMSfeatures_v6 #5):** Timeline scrubbing, fast forward/rewind up to 16x, thumbnails.

- **Requirement:** Color-coded segment rendering:
  - Blue = Continuous recording
  - Orange = Motion-triggered recording
  - Green = Scheduled recording
- **Requirement:** P95 latency ceiling of ≤ 2 seconds for fragment retrieval.
- **Requirement:** Implementation of `RepaintBoundary` on the scrubber component to ensure dragging events do not trigger full widget tree re-paints.
- **Requirement:** Playback speed controls — 1x, 2x, 4x, 8x, 16x forward; 2x, 4x rewind.
- **Requirement:** Keyframe thumbnail generation at scrub position (served via `GET /api/v5/recordings/{segmentId}/thumbnail?ts={timestamp}`).

### Task C.1.2 — Evidence Export Management UI (F06 — Standard Edition)

Build the evidence management wizard allowing operators to define time-bound export clips.

**Phase 1 Feature Alignment (VMSfeatures_v6 #6):** Save clips with watermark, share with in-built player, quick navigation.

- **Requirement:** UI must explicitly list watermarking toggles:
  - System Name
  - Camera ID / Name
  - Timestamp
  - Operator User ID
- **Integration:** Hook into `POST /api/v5/recordings/{segmentId}/export` and display the real-time assembly progress of the MP4 clip container.
- **Integration:** Poll `GET /api/v5/recordings/exports/{id}` to track export job completion and surface MinIO download path.
- **Requirement:** Export file naming convention: `{customer_id}_{camera_id}_{start_ts}_{end_ts}.mp4`.

---

## Sub-Phase C.2 — Mobile Hardware Token Storage (F09 — Pillar 8 Client-Side Mandate)

> **Scope Clarification:** This is NOT F10. F10 (JWT signing, Vault PKI, mTLS, audit logs) is Vivek's domain. This sub-phase covers only the **mobile device-side secure storage** of the access token received FROM Vivek's auth endpoint. Sagar stores it safely — he does not issue, sign, or validate it.

### Task C.2.1 — Platform Channel Architecture

```
SecureStorageService (Dart — abstract interface)
    ├── Android implementation (Kotlin) → EncryptedSharedPreferences + Android Keystore AES256-GCM key
    └── iOS implementation (Swift)      → Keychain with kSecAttrAccessibleWhenUnlockedThisDeviceOnly
```

Access token policy: lives in-memory ONLY (Bloc/Cubit state).
Refresh token policy: stored in SecureStorage (platform-specific, above).

### Task C.2.2 — Android Platform Channel (Kotlin)

```kotlin
// android/app/src/main/kotlin/com/vms/app/SecureStoragePlugin.kt

class SecureStoragePlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var encryptedPrefs: SharedPreferences

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    val masterKey = MasterKey.Builder(binding.applicationContext)
      .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
      // AES256_GCM key is generated inside Android Keystore (hardware-backed on supporting devices)
      // JWT BYTES live in EncryptedSharedPreferences — NOT inside Keystore TEE
      .build()

    encryptedPrefs = EncryptedSharedPreferences.create(
      binding.applicationContext,
      "vms_secure_prefs",
      masterKey,
      EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
      EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
    )

    MethodChannel(binding.binaryMessenger, "com.vms.app/secure_storage")
      .setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "write" -> {
        val key   = call.argument<String>("key")   ?: return result.error("INVALID","key required",null)
        val value = call.argument<String>("value") ?: return result.error("INVALID","value required",null)
        encryptedPrefs.edit().putString(key, value).apply()
        result.success(null)
      }
      "read" -> {
        val key = call.argument<String>("key") ?: return result.error("INVALID","key required",null)
        result.success(encryptedPrefs.getString(key, null))
      }
      "delete" -> {
        val key = call.argument<String>("key") ?: return result.error("INVALID","key required",null)
        encryptedPrefs.edit().remove(key).apply()
        result.success(null)
      }
      "clear" -> {
        encryptedPrefs.edit().clear().apply()
        result.success(null)
      }
      else -> result.notImplemented()
    }
  }
}
```

### Task C.2.3 — iOS Platform Channel (Swift)

```swift
// ios/Runner/SecureStoragePlugin.swift

class SecureStoragePlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.vms.app/secure_storage",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(SecureStoragePlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "write":
      guard let key = args?["key"] as? String, let value = args?["value"] as? String else {
        result(FlutterError(code:"INVALID",message:"key and value required",details:nil)); return
      }
      let query: [CFString: Any] = [
        kSecClass:            kSecClassGenericPassword,
        kSecAttrService:      "com.vms.app",
        kSecAttrAccount:      key,
        kSecValueData:        Data(value.utf8),
        // JWT bytes stored directly in Keychain with this access control
        kSecAttrAccessible:   kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        // Phase 2: add kSecAccessControl with .biometryAny for FIDO2-equivalent binding
      ]
      SecItemDelete(query as CFDictionary)            // upsert pattern
      let status = SecItemAdd(query as CFDictionary, nil)
      guard status == errSecSuccess else {
        result(FlutterError(code:"KEYCHAIN_ERROR",message:"Status: \(status)",details:nil)); return
      }
      result(nil)

    case "read":
      guard let key = args?["key"] as? String else {
        result(FlutterError(code:"INVALID",message:"key required",details:nil)); return
      }
      let query: [CFString: Any] = [
        kSecClass:       kSecClassGenericPassword,
        kSecAttrService: "com.vms.app",
        kSecAttrAccount: key,
        kSecReturnData:  true,
        kSecMatchLimit:  kSecMatchLimitOne,
      ]
      var ref: AnyObject?
      let status = SecItemCopyMatching(query as CFDictionary, &ref)
      if status == errSecSuccess, let data = ref as? Data {
        result(String(data: data, encoding: .utf8))
      } else {
        result(nil)
      }

    case "delete":
      guard let key = args?["key"] as? String else {
        result(FlutterError(code:"INVALID",message:"key required",details:nil)); return
      }
      SecItemDelete([
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: "com.vms.app",
        kSecAttrAccount: key,
      ] as CFDictionary)
      result(nil)

    case "clear":
      SecItemDelete([
        kSecClass:       kSecClassGenericPassword,
        kSecAttrService: "com.vms.app",
      ] as CFDictionary)
      result(nil)

    default: result(FlutterMethodNotImplemented)
    }
  }
}
```

### Task C.2.4 — Dart SecureStorageService

```dart
// lib/core/storage/secure_storage_service.dart

class SecureStorageService {
  static const _channel        = MethodChannel('com.vms.app/secure_storage');
  static const _refreshTokenKey = 'vms_refresh_token';

  Future<void> storeRefreshToken(String token) async {
    await _channel.invokeMethod<void>('write', {
      'key':   _refreshTokenKey,
      'value': token,
    });
  }

  Future<String?> getRefreshToken() async {
    return _channel.invokeMethod<String>('read', {'key': _refreshTokenKey});
  }

  Future<void> clearAll() async {
    await _channel.invokeMethod<void>('clear');
  }

  // Access token NEVER touches this service — it lives in AuthBloc state (in-memory)
}
```

---

## Sub-Phase C.3 — Ergonomic Design Palette (F02 UI Mandate — Non-AI Vibe)

All interfaces must adopt the **Tactical Industrial Palette**. No gradients, no glows, no neons.

| Palette Role | Hex Variable Token | Application Context Rule |
|---|---|---|
| **Primary Background** | `#0D0E12` | Canvas base. Pitch black is banned. |
| **Panel Surface Tiles** | `#14161F` | Grid tiles, sidebars, input boxes. |
| **Primary Text** | `#E2E8F0` | Labels, metrics, titles. White is banned. |
| **Muted Text** | `#70788C` | Timestamps, legends. |
| **Status Online** | `#02965E` | Muted Jade Emerald badge. |
| **Status Alarm** | `#D32F2F` | Muted Dark Crimson border/frame. |
| **Motion Segment** | `#E65100` | Burnt Deep Amber segment bar (F05 timeline). |

---

## Sub-Phase C.4 — TLS Certificate Pinning (F09 — Mobile Network Security, Client-Side)

> **Scope Clarification:** SPKI hash pinning here is the **mobile app's network security layer** — it ensures the Flutter Dio client only connects to Vivek's legitimate API Gateway. The intermediate CA certificate itself is issued and managed by Vivek via HashiCorp Vault (F10). Sagar only configures the **client-side pin** using the SPKI hash that Vivek provides.

### Task C.4.1 — SPKI Hash Pinning via Dio Interceptor

**Critical rule: Pin against the INTERMEDIATE CA, not the leaf certificate.**
Leaf cert changes on every rotation → pinning leaf breaks connectivity.
Intermediate CA is stable across leaf rotations (typically valid 2+ years).

SPKI hash computation command:
```sh
openssl x509 -in intermediate-ca.crt -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | base64
```

```dart
// lib/core/network/dio_factory.dart

class DioFactory {
  // Called during app bootstrap; SPKI hashes provided by Vivek from Vault PKI
  static Dio create({
    required SecureStorageService storage,
    required List<String> pinnedSpkiHashes,   // base64 SHA-256 of intermediate CA SPKI
  }) {
    final dio = Dio(BaseOptions(
      baseUrl:        AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // Native HttpClient with certificate verification
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) {
        // Extract SubjectPublicKeyInfo DER, SHA-256 hash, base64
        // Compare against pinnedSpkiHashes — reject if no match
        final spkiHash = _computeSpkiHash(cert);
        return pinnedSpkiHashes.contains(spkiHash);
        // Returns true = accept; false = reject
        // badCertificateCallback returning false means connection proceeds
        // (confusingly named: true = bad cert is OK, false = reject)
        // Our implementation: if SPKI matches → return true (accept)
        //                     if SPKI no match → return false (reject conn)
      };
      return client;
    };

    dio.interceptors.addAll([
      RefreshTokenInterceptor(storage: storage, dio: dio),
      LogInterceptor(requestBody: false, responseBody: false),  // never log tokens
    ]);

    return dio;
  }

  static String _computeSpkiHash(X509Certificate cert) {
    // Extract DER-encoded SubjectPublicKeyInfo from cert.der bytes
    // SHA-256 hash → base64
    // Implementation uses dart:io X509Certificate.der
    // Parse ASN.1 to extract SPKI offset — or use platform channel for native impl
    // For Phase 1: use platform channel to native NSURLSession/OkHttp pinning
    // as a simpler and battle-tested alternative
    return base64Encode(sha256.convert(derBytes).bytes);
  }
}
```

### Task C.4.2 — JWT Refresh with Global RefreshLock (No Race Conditions)

```dart
// lib/core/network/refresh_token_interceptor.dart

class RefreshTokenInterceptor extends QueuedInterceptor {
  final SecureStorageService _storage;
  final Dio _dio;
  Completer<void>? _refreshCompleter;   // Global lock — exactly one refresh in-flight

  RefreshTokenInterceptor({required SecureStorageService storage, required Dio dio})
      : _storage = storage, _dio = dio;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) { handler.next(err); return; }

    // If a refresh is already in progress, wait for it then retry
    if (_refreshCompleter != null) {
      try {
        await _refreshCompleter!.future;
        handler.resolve(await _retry(err.requestOptions));
      } catch (_) {
        handler.next(err);
      }
      return;
    }

    _refreshCompleter = Completer<void>();
    try {
      await _performRefresh();
      _refreshCompleter!.complete();
      handler.resolve(await _retry(err.requestOptions));
    } catch (e) {
      _refreshCompleter!.completeError(e);
      handler.next(err);
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<void> _performRefresh() async {
    // POST /api/v5/auth/refresh
    // HttpOnly cookie sent automatically by platform HTTP stack
    // Response body contains new access token
    // New refresh token set in updated HttpOnly cookie by server
    final response = await _dio.post('/api/v5/auth/refresh');
    final newToken = response.data['accessToken'] as String;
    // Update AuthBloc in-memory state with new access token
    getIt<AuthBloc>().add(AuthTokenRefreshed(token: newToken));
  }

  Future<Response<dynamic>> _retry(RequestOptions options) async {
    final user = getIt<AuthBloc>().state.user;
    options.headers['Authorization'] = 'Bearer ${user?.accessToken}';
    return _dio.fetch(options);
  }
}
```

---

## Sub-Phase C.5 — Login UI & Mobile Onboarding (F09 — Standard Edition)

> **Boundary Reminder:** Sagar builds the **login screen UI + HTTP call only**. The actual auth logic (password hashing, JWT generation, session management, RBAC guard enforcement) is entirely Vivek's NestJS backend. Sagar is a **consumer** of Vivek's auth API — not an implementer of auth business logic.

### Task C.5.1 — Multi-Tenant AuthRepository Integration

**Phase 1 Feature Alignment (VMSfeatures_v6 #9):** Mobile/Web Access — view live and playback remotely, role-based access.

**SaaS Registration Constraint:** Login gateway enforces multi-tenant enterprise ID fields. The `customer_id` field is MANDATORY in every login request — it is the B2B tenant sharding key used by backend-api to scope all subsequent RBAC, camera, and recording queries.

```dart
// lib/features/login/data/auth_repository.dart

class AuthRepository {
  final Dio _dio;
  final SecureStorageService _storage;

  AuthRepository({required Dio dio, required SecureStorageService storage})
      : _dio = dio, _storage = storage;

  Future<AuthResult> login({
    required String customerId, // Business License Token — B2B tenant key
    required String email,
    required String password,
  }) async {
    final response = await _dio.post('/api/v5/auth/login', data: {
      'customer_id': customerId,
      'email':       email,
      'password':    password,
    });
    // Access token: kept in AuthBloc state (in-memory) — never written to storage
    // Refresh token: HttpOnly cookie set by server — managed by platform HTTP stack
    // No explicit refresh token storage needed for cookie-flow
    final accessToken = response.data['accessToken'] as String;
    final user = UserProfile.fromJson(response.data['user'] as Map<String, Object?>);
    return AuthResult(accessToken: accessToken, user: user);
  }

  Future<void> logout() async {
    await _dio.post('/api/v5/auth/logout');
    await _storage.clearAll();
    // AuthBloc clears in-memory state
  }
}
```

### Task C.5.2 — LoginBloc

```dart
// lib/features/login/bloc/login_bloc.dart

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final AuthRepository _authRepository;

  LoginBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const LoginState.initial()) {
    on<LoginSubmitted>(_onLoginSubmitted);
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(const LoginState.loading());
    try {
      final result = await _authRepository.login(
        customerId: event.customerId,
        email: event.email,
        password: event.password,
      );
      emit(LoginState.success(user: result.user));
    } on UnauthorizedException {
      emit(const LoginState.failure(message: 'Invalid credentials'));
    } on RateLimitException {
      emit(const LoginState.failure(message: 'Too many attempts. Try again later.'));
    } on NetworkException {
      emit(const LoginState.failure(message: 'Network error. Check your connection.'));
    }
  }
}
```

### Task C.5.3 — LoginPage UI (Tactical Industrial Palette)
- Enterprise ID field (`customer_id`) — required; shown as "Organization ID" to the operator
- Email + password text fields
- Validation: organization ID non-empty, email format, password non-empty
- Show/hide password toggle
- Submit button: disabled while loading
- Error banner: plain-language message (never raw API error)
- No biometric UI in Phase 1 (deferred to Phase 2)
- No "remember me" option (no persistent auth state in Phase 1 beyond secure storage)
- All colors must conform to Tactical Industrial Palette defined in Sub-Phase C.3

---

## Cross-Owner Interfaces Matrix (Sagar ➔ Vivek)

| Interface Channel | Delivery Protocol | Directionality | Payload / Schema Requirements |
| --- | --- | --- | --- |
| `POST /api/v5/auth/login` | HTTPS REST | Sagar UI ➔ Vivek Gateway | `{customer_id, email, password}` |
| `GET /api/v5/recordings` | HTTPS REST | Sagar UI ➔ Vivek Gateway | `{customer_id, siteId, cameraId, type, date}` |
| `POST /api/v5/recordings/{segmentId}/export` | HTTPS REST | Sagar UI ➔ Vivek Gateway | `{customer_id, siteId, camera_id, start_time, end_time, watermark: bool}` |
| `GET /api/v5/recordings/exports/{id}` | HTTPS REST | Sagar UI ➔ Vivek Gateway | Polling for export status; returns MinIO path |
| `GET /api/v5/recordings/{segmentId}/thumbnail` | HTTPS REST | Sagar UI ➔ Vivek Gateway | `?ts={timestamp}` — returns keyframe JPEG for scrubber |

---

## Blocking Dependency (Sprint 1, Week 1)

Sagar's Task C.4.1 is BLOCKED until Vivek provides:
1. The base64 SHA-256 SPKI hash of the intermediate CA certificate from Vault PKI
2. A backup hash for rotation overlap

This must be resolved by end of Sprint 1 Week 1 before mobile CI can run against staging.
Raise as a Day 1 blocker in sprint planning.
