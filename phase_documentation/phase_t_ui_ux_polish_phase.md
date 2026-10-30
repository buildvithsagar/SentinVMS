# Phase T: Subtle Dark Glassmorphism Design System, Manual RTSP Onboarding & Device Code Autofill

## 1. Specification Overview
* **Scope:** Enterprise-wide UI polish applying Subtle Dark Glassmorphism across all core modules, Direct RTSP camera manual onboarding, QR/Barcode payload autofill parsing, and local encrypted camera store persistence.
* **Design Guidelines:** Dark Slate `#0F172A` canvas, `BackdropFilter` translucent glass with `sigmaX: 8–12, sigmaY: 8–12`, subtle opacity `0.04–0.08`, Electric Teal `#2DD4BF` active accents, and Crimson `#EF4444` alerts.
* **Architecture:** Feature-first Clean Architecture, secure on-device credentials via `LocalCameraStore`, and modular reusable UI component library (`vms_ui.dart`).

## 2. Key Changes
* **UI Components:** Implemented `vms_ui.dart` providing `GlassCard`, `GlassContainer`, `GlassTextField`, `GlassDropdown`, `VmsPrimaryButton`, `VmsSecondaryButton`, and `VmsBadge`.
* **Navigation & Drawer:** Standardized `VmsDrawer` and created `VmsNavigationBar` matching the glassmorphic aesthetic.
* **Screens Polished:** `LiveGridPage`, `CameraListPage`, `PlaybackPage`, `AlarmListPage`, `ExportPage`, `StreamDemoPage`, `LoginPage`.
* **RTSP Parser & Manual RTSP Camera:** Implemented `rtsp_uri.dart`, `LocalCameraStore`, `ManualRtspCameraPage`, and `DirectRtspVideoTile`.
* **Code Autofill:** Built `DeviceCodePayload` with support for JSON, query parameters, and raw RTSP URLs with automatic form pre-filling.

