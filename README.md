# SentinVMS — Enterprise Video Management System

**SentinVMS** is a high-performance, centralized Shared-Control-Plane B2B Multi-Tenant SaaS Video Management System. Engineered for distributed IP camera fleets (targeting up to 50,000 cameras), it features a two-tier LAN multicast & WAN streaming model, WebRTC low-latency live viewing, HLS recording playback, AI-driven event analytics, and native mobile/desktop operator consoles.

---

## 🏗️ Architecture & Component Overview

```
                        +------------------------------------------+
                        |         SentinVMS Mobile App             |
                        |   (Flutter / BLoC / Dark Glassmorphism)   |
                        +--------------------+---------------------+
                                             |
                                  REST / WebSocket (JWT)
                                             v
+-----------------------+       +----------------------------------+       +-----------------------+
|  Edge Agent (Debian)  | ----> |  Control Plane (NestJS Gateway)  | <---> |  PostgreSQL 16 / HA   |
| (On-Prem Loopback)    | LAN   +----------------------------------+       +-----------------------+
+-----------------------+                    |                                         |
            |                                v                                         v
            | WAN Multicast        +----------------------------------+       +-----------------------+
            +--------------------> | Media Core (C++17 / GStreamer)   | <---> | MinIO Object Storage  |
                                   +----------------------------------+       +-----------------------+
```

### Core Architecture Highlights:
- **Composite Tenancy Addressing:** All camera streams, configs, and logs use composite key routing (`{customer_id}:{site_id}:{camera_id}`).
- **Two-Tier LAN Multicast with Edge Loopback:** Single camera stream output routed via LAN multicast to local clients and on-premise Edge Loopback proxies.
- **Process-Isolated Control Plane:** NestJS API Gateways run in isolated event loops from background event pipelines and alert consumers.
- **Low Latency Streaming:** LAN WebRTC (P95 <= 500ms), WAN TURN-relayed WebRTC (P95 <= 1.5s), and mobile HLS stream fallback.

---

## 🛠️ Technology Stack Summary

| Component | Technology | Description |
| :--- | :--- | :--- |
| **Mobile Track** | Flutter 3.x (Dart 3.x) | iOS & Android multi-tenant operator client |
| **Web Client** | React 18 + TypeScript + Vite | Browser operator platform & admin portal |
| **Control Plane** | NestJS 10 + Node.js 20 LTS | Microservice API Gateway & orchestration |
| **Media Core** | C++ 17 + GStreamer 1.22 | Real-time RTSP/HLS/WebRTC streaming server |
| **Edge Appliance** | C++ 17, Debian 12 | On-premise stream ingest & loopback proxy |
| **Database & Cache** | PostgreSQL 16, Redis 7, MongoDB 7 | Relational storage, caching, and append-only event logs |
| **Object Storage** | MinIO | Erasure-coded recording segment & clip storage |

---

## 📱 Mobile App (Sagar's Track)

The mobile client located in [`/mobile`](file:///c:/Users/SAGAR/vmsapp/SentinVMS/mobile) includes:
- **Subtle Dark Glassmorphism UI:** Slate background (`#0F172A`), electric teal accents (`#2DD4BF`), and glass translucency.
- **Live Grid:** Multi-camera views with slot controls (`1x1`, `2x2`, `3x3`).
- **Playback & Scrubber:** Multi-span recording timeline (`5m` to `24h`) with clip trimming.
- **Real-Time Alarms:** WebSocket event stream for instantaneous security notifications.
- **Device Onboarding:** QR Code camera scanner & manual IP setup workflows.

For detailed mobile setup and build instructions, refer to [`mobile/README.md`](file:///c:/Users/SAGAR/vmsapp/SentinVMS/mobile/README.md).

---

## 🚀 Quickstart

### Mobile Client:
```bash
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run
```

---

## 📄 License & Classification

**Classification:** Internal / Confidential  
**Standard:** IEEE Std 830-1998 | SRS Baseline v5.1  
Copyright © 2026 SentinVMS Enterprise SaaS Platform.
