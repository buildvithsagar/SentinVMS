# Phase T — Context: UI/UX Subtle Dark Glassmorphism Polish, Manual RTSP Onboarding & Device Code Autofill

## 1. Problem Definition
1. **Design Inconsistency:** Screen components across Camera List, Playback, Alarms, Exports, and Drawer lacked unified dark glassmorphism tokens, leading to varied border radiuses, harsh gradients, and inconsistent padding.
2. **Manual RTSP Addition:** Users lacked the ability to directly add custom RTSP cameras without going through the complete ONVIF discovery or cloud backend provisioning pipeline.
3. **QR / Barcode Autofill Friction:** Scanning camera QR codes, barcodes, or payload strings required manual entry if standard schemas were omitted or slightly varied.
4. **Local Device Persistence:** Custom RTSP cameras added on-device needed encrypted offline persistence so they remain available even without internet or backend connectivity.

## 2. Solution Implemented
1. **Subtle Dark Glassmorphism Design System (`vms_ui.dart` & `vms_theme.dart`):**
   - Established unified glass container cards with Dark Slate `#0F172A` canvas, `BackdropFilter` with `sigmaX: 10, sigmaY: 10`, subtle white opacity `0.05`–`0.08`, and Electric Teal `#2DD4BF` active borders/accents.
   - Standardized typography, badges, glass buttons (`VmsPrimaryButton`, `VmsGlassButton`), and glass navigation bar (`VmsNavigationBar`).
2. **Manual RTSP Onboarding (`ManualRtspCameraPage` & `RtspUri`):**
   - Implemented `rtsp_uri.dart` parser to validate, extract host, port, path, and safely sanitize/mask passwords in logs and UI.
   - Created `ManualRtspCameraPage` for direct RTSP configuration with stream validation and category assignment.
3. **Device Code Payload Parser (`DeviceCodePayload`):**
   - Handles structured JSON, query-string key-values, and raw URLs from QR/barcode scanners with robust fallback parsing.
   - Integrated into `DeviceDetailsFormPage` and `DeviceCategoryPage` for instant field auto-population.
4. **Local Camera Store (`LocalCameraStore`):**
   - Encrypted local persistence for direct RTSP and user-added cameras via `SecureStorageService`.
   - Unified repository integration in `CameraRepository` merging server and local device registries seamlessly.
