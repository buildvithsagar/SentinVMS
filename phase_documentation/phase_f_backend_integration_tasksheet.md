# Phase F Tasksheet - Completed Items

- [x] Add `socket_io_client` to `pubspec.yaml`
- [x] Split `AuthRepository.login()` into `loginStep1()` (credentials) and `loginStep2()` (OTP verify)
- [x] Implement Base64 JWT local claims decoder for constructing `UserProfile`
- [x] Refactor REST repositories to relative endpoints to support double prefix Gateway (/api/api/v5)
- [x] Implement Socket.io integration inside `WebSocketService`
- [x] Remove Organization ID and TOTP inputs from initial `LoginPage` form
- [x] Create dedicated OTP Verification Form inside `LoginPage` with slide animations
- [x] Implement BLoC event `LoginReset` to clear failure states on Back navigation
- [x] Fix unit tests for `LoginBloc` and interceptors in `test/unit/`
- [x] Mock BLoC state in `login_page_test.dart` to solve test hangs and stubbing issues
- [x] Run `flutter analyze` and `flutter test` validating 100% test success rate
- [x] Commit and push changes to branch `working` on remote
