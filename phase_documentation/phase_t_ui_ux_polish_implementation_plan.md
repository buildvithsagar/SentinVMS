# Phase T Implementation Plan: UI/UX Subtle Dark Glassmorphism, Manual RTSP & Device Code Autofill

## Proposed Changes

### Core UI Framework
- `mobile/lib/core/widgets/vms_ui.dart`: Reusable glassmorphic atoms (cards, containers, buttons, inputs, badges).
- `mobile/lib/core/widgets/vms_navigation_bar.dart`: Glass dock navigation bar.
- `mobile/lib/core/theme/vms_theme.dart`: Standard color definitions and glass theme helpers.

### Direct RTSP Stream & Local Store
- `mobile/lib/core/video/rtsp_uri.dart`: RTSP URI parsing, credential sanitization, port/path validation.
- `mobile/lib/features/camera/data/local_camera_store.dart`: Local encrypted storage for direct RTSP cameras.
- `mobile/lib/features/camera/presentation/pages/manual_rtsp_camera_page.dart`: Direct RTSP camera onboarding view.
- `mobile/lib/features/live_view/presentation/widgets/direct_rtsp_video_tile.dart`: Direct RTSP video player widget.

### Device Onboarding
- `mobile/lib/features/device_onboarding/models/device_code_payload.dart`: Multi-format payload parsing (JSON, URI params, strings).
- `mobile/lib/features/device_onboarding/presentation/pages/device_details_form_page.dart`: Form autofill using scanned payload.

### Unit & Widget Testing
- `mobile/test/unit/rtsp_uri_test.dart`
- `mobile/test/unit/local_camera_store_test.dart`
- `mobile/test/unit/device_code_payload_test.dart`
- `mobile/test/widget/connectivity_banner_test.dart`
- `mobile/test/widget/device_code_autofill_test.dart`

## Verification Plan
1. Unit tests for RTSP parsing and device code payload extraction.
2. Local store encryption and round-trip persistence tests.
3. UI glassmorphism consistency check across all routes.
