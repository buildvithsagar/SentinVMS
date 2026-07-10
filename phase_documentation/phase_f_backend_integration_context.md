# Phase F Context - Backend Integration & Login Simplification

## Workspace Overview
The workspace consists of a Flutter mobile application (`mobile/`) being integrated with a NestJS backend services platform.

## Dependencies & Infrastructure
- HTTP Client: `dio` with a customized `RefreshTokenInterceptor`
- WebSocket Client: `socket_io_client` configured for Path `/ws/v5/telemetry`
- Authentication State Management: `flutter_bloc` (`AuthBloc`, `LoginBloc`)
- Local Vault: `flutter_secure_storage`

## System Configuration
- Base URL prefix resolved via Relative Paths appending to double prefix Gateway (`api/api/v5/`)
- Dev local bypass OTP code set to `000000`
