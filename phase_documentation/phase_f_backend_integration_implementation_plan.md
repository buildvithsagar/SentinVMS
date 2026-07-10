# Phase F Implementation Plan - E2E NestJS Mobile Client Integration

## Step 1: Library Dependencies
- Add Socket.io Client dart library to support websocket handshakes.
- Run `flutter pub get`.

## Step 2: REST Client Endpoint Alignment
- Modify all REST endpoints in `AlarmRepository`, `CameraRepository`, `ExportRepository`, and `PlaybackRepository` to relative paths.
- Ensure snake_case parameters are mapped properly for API Gateway queries.

## Step 3: Authenticated Handshake & MFA Flows
- Split login flow into independent steps.
- Set up cookie header extractor for relative interceptor refreshes.
- Support bypass code `000000` in verify-otp.

## Step 4: UI Redesign (Two-Step Page)
- Simplify credentials form (email & password only).
- Swap forms inside `LoginPage` using BLoC state `LoginOtpRequired`.
- Add back button to return to step 1 and reset state.

## Step 5: Test Execution and Quality Assurance
- Run analyzer to check lint rules.
- Execute widget tests validating input errors and layout rendering.
