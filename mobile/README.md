# SentinVMS Mobile Application

**SentinVMS Mobile** is a modern, enterprise-grade Flutter application engineered for real-time video surveillance, multi-tenant camera stream monitoring, historical recording playback, alarm triage, and device onboarding.

Built as part of the **SentinVMS Enterprise SaaS Platform**, the mobile client delivers high-performance live HLS video feeds, interactive timeline scrubbing, evidence clip exports, real-time WebSocket telemetry, and biometric/secure authentication.

---

## 🎨 UI/UX Design System

SentinVMS Mobile enforces a sleek **Subtle Dark Glassmorphism** design system across all screens:

- **Base Canvas:** Dark Slate (`#0F172A`)
- **Translucent Glass:** `BackdropFilter` with `sigmaX: 8–12, sigmaY: 8–12` & low-opacity white/teal highlights (`0.04`–`0.08`)
- **Primary Active Accent:** Subtle Electric Teal (`#2DD4BF`)
- **Alert & Danger Accent:** Crimson Red (`#EF4444`)
- **Aesthetic Standard:** Professional, enterprise security console look inspired by Verkada/Apple software design without flashy gaming glows.

---

## ✨ Key Features

- 📹 **Live View Grid:**
  - Multi-tile camera grid layouts (`1x1`, `2x2`, `3x3`) with dynamic slot assignment.
  - HLS video player integration with auto-reconnect, fallback poster states, and full-screen focus modes.
- ⏪ **Playback & Timeline Scrubber:**
  - Interactive multi-scale timeline scrubber (`24h`, `12h`, `6h`, `3h`, `1h`, `60m`, `30m`, `15m`, `5m`).
  - HLS recording playback synchronized with event segments (Continuous vs. Motion).
  - Trimming mode for extracting evidence clips and initiating export jobs.
- 🚨 **Real-Time Alarms & Events:**
  - WebSocket-driven real-time alert notifications and alarm feed.
  - Severity filtering, acknowledgment flow, and direct camera jump from alarm events.
- 📱 **Device Onboarding & Scanner:**
  - QR Code / InstaOn camera scanner powered by `mobile_scanner`.
  - Manual IP/Domain configuration forms with built-in validation.
- 📁 **Export Vault:**
  - Track background clip export jobs, view progress, and download MP4 clips with watermarking.
- 🔒 **Security & Authentication:**
  - Secure hardware-backed storage (`flutter_secure_storage`) for refresh tokens and auth credentials.
  - JWT token auto-refresh interceptors for seamless session lifecycle management.

---

## 🛠️ Architecture & Tech Stack

| Component | Technology / Package | Purpose |
| :--- | :--- | :--- |
| **Framework** | Flutter 3.x / Dart 3.x | Cross-platform mobile development |
| **State Management** | `flutter_bloc`, `get_it` | Predictable state flow & dependency injection |
| **Routing** | `go_router` | Declarative deep-linking and path management |
| **HTTP Client** | `dio` | REST API consumption & token refresh interceptors |
| **Real-time Telemetry** | `socket_io_client` | WebSocket event streaming for alarms & status |
| **Video Playback** | `video_player` | Native HLS video playback engine |
| **Scanner** | `mobile_scanner` | Camera QR code & barcode scanning |
| **Secure Storage** | `flutter_secure_storage` | Cryptographically secured token storage |

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.27+)
- Android Studio / Xcode for emulators and physical device deployment
- Access to SentinVMS Control Plane API Gateway

### Setup & Run

1. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

2. **Run Static Code Analysis:**
   ```bash
   flutter analyze
   ```

3. **Execute Unit & Widget Tests:**
   ```bash
   flutter test
   ```

4. **Launch Application:**
   ```bash
   # Run on connected device or emulator
   flutter run
   ```

---

## 🧪 Testing Standard

The codebase maintains strict quality guidelines:
- Zero linting errors (`flutter analyze` clean pass).
- Comprehensive unit tests covering repositories, BLoCs, storage services, and interceptors.
- Widget tests covering UI views (`LiveGridPage`, `LoginPage`, `VideoTile`).

Run all tests:
```bash
flutter test --coverage
```
