# Phase F - NestJS Backend Integration & Login Screen Simplification

## Phase Objectives
1. Eliminate Organization ID and initial TOTP input fields from the login screen (mirroring the Web Client login style).
2. Create a dedicated OTP verification sub-screen/page on the mobile app.
3. Chained Two-Step Authentication integration with the NestJS gateway.
4. Support the Socket.io Gateway for real-time telemetry instead of raw WebSockets.
5. Bring unit and widget test coverage to 100% success rate.

## Key Changes
- Modified `auth_repository.dart` to split operations into `loginStep1()` and `loginStep2()`.
- Updated `login_bloc.dart` with `LoginSubmitted` (Step 1), `LoginOtpSubmitted` (Step 2), and `LoginReset` events.
- Simplified `login_page.dart` to swap views between Credentials entry (Email/Password) and OTP Verification (6 character code).
- Integrated `socket_io_client` into `WebSocketService` listening to telemetry channels `/ws/v5/telemetry`.
- Refactored `AlarmRepository`, `CameraRepository`, `ExportRepository`, and `PlaybackRepository` paths to relative endpoints.
- Updated and fixed unit/widget tests inside `test/unit/` and `test/widget/` suites.
