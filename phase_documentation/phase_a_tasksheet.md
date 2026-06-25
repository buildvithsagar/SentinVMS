# VMS Flutter Client — Micro-Phase A Tasksheet Checklist

## ── Micro-Phase A: Security, Auth & Storage (Foundation) ──
- `[x]` A.1: Configure project dependencies & strict analysis rules (`very_good_analysis`)
- `[x]` A.2: Create folder directory structure (`core/`, `features/`, etc.)
- `[x]` A.3: Implement native Android secure storage platform channel (`SecureStoragePlugin.kt`)
- `[x]` A.4: Implement native iOS secure storage platform channel (`SecureStoragePlugin.swift`)
- `[x]` A.5: Implement Dart `SecureStorageService` wrapper
- `[x]` A.6: Implement `DioFactory` with SPKI Intermediate CA pinning (and `--dart-define=BYPASS_PINNING=true` toggle)
- `[x]` A.7: Implement `RefreshTokenInterceptor` with Dart `Completer`-based `RefreshLock`
- `[x]` A.8: Implement `AuthBloc` (Volatile token management & tenant/role mapping)
- `[x]` A.9: Build LoginPage & MFA UI (Tactical Dark Industrial Palette)
- `[x]` A.10: Write unit/widget tests for secure storage, SPKI pinning, and RefreshLock
