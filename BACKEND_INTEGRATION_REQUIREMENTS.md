# SentinVMS — Backend & Web API Integration Handover Specification

> **Document Type:** Technical Integration & API Requirement Specification  
> **Target Audience:** Backend Engineers, Web Developers & System Architects  
> **Client Platform:** SentinVMS Mobile App (Flutter / Clean Architecture + BLoC)  
> **API Version Standard:** v5 (`/api/v5`)  
> **Protocol Standard:** HTTPS / REST + Socket.io / WSS Telemetry

---

## 1. Executive Summary

This document outlines the exact technical requirements, REST API endpoints, real-time WebSocket contracts, and streaming specifications needed to integrate the **SentinVMS Central Web / Backend Server** with the **SentinVMS Mobile Client Application**.

The mobile application is completely built and tested. To enable live communication between the web platform and the mobile application, the backend team must provide the endpoints and configurations detailed below.

---

## 2. Server Base URLs & Environment Configuration

Please provide the URLs for the target operating environment(s):

| Environment | Base REST API URL | WebSocket / Socket.io Broadcaster URL |
| :--- | :--- | :--- |
| **Development (Local/LAN)** | `http://<LAN_IP>:<PORT>/api/v5` | `http://<LAN_IP>:<PORT>` |
| **Staging** | `https://staging-api.yourdomain.com/api/v5` | `https://staging-api.yourdomain.com` |
| **Production** | `https://api.yourdomain.com/api/v5` | `https://api.yourdomain.com` |

* **WebSocket Sub-path / Namespace:** `/ws/v5/telemetry` *(or your custom Socket.io namespace)*.
* **CORS / Network Policy:** Ensure mobile clients (Android/iOS) have unrestricted network access with proper SSL/TLS certificates.

---

## 3. Authentication & Security Specifications

All authenticated requests from the mobile app will carry the standard `Bearer <access_token>` in the `Authorization` header.

### 3.1. User Login
* **Endpoint:** `POST /api/v5/auth/login`
* **Request Headers:** `Content-Type: application/json`
* **Request Body:**
  ```json
  {
    "email": "operator@sentinvms.com",
    "password": "SecurePassword123!",
    "tenant_id": "org_enterprise_01"
  }
  ```
* **Success Response (MFA Required):** `200 OK`
  ```json
  {
    "status": "success",
    "mfa_required": true,
    "session_token": "temp_mfa_session_token_xyz"
  }
  ```
* **Success Response (Direct Login / MFA Disabled):** `200 OK`
  ```json
  {
    "status": "success",
    "access_token": "eyJhbGciOi...",
    "refresh_token": "d7a8b9c0...",
    "expires_in": 3600,
    "user": {
      "id": "usr_991",
      "name": "Alex Mercer",
      "email": "operator@sentinvms.com",
      "role": "SECURITY_OPERATOR",
      "tenant_id": "org_enterprise_01"
    }
  }
  ```

### 3.2. MFA / OTP Verification
* **Endpoint:** `POST /api/v5/auth/verify-otp`
* **Request Body:**
  ```json
  {
    "session_token": "temp_mfa_session_token_xyz",
    "otp": "849201"
  }
  ```
* **Success Response:** `200 OK` (Returns `access_token`, `refresh_token`, and `user` object).

### 3.3. Token Refresh Handshake
* **Endpoint:** `POST /api/v5/auth/refresh`
* **Request Body:**
  ```json
  {
    "refresh_token": "d7a8b9c0..."
  }
  ```
* **Success Response:** `200 OK`
  ```json
  {
    "access_token": "eyJhbGciOi...new_token",
    "refresh_token": "d7a8b9c0...new_refresh",
    "expires_in": 3600
  }
  ```

---

## 4. Camera Directory & Stream Metadata APIs

### 4.1. List Registered Cameras
* **Endpoint:** `GET /api/v5/cameras`
* **Headers:** `Authorization: Bearer <access_token>`
* **Success Response:** `200 OK`
  ```json
  {
    "cameras": [
      {
        "id": "cam_001",
        "name": "North Gate Entrance PTZ",
        "site_id": "site_hq",
        "site_name": "Headquarters Perimeter",
        "zone": "Gate 1",
        "ip_address": "192.168.10.45",
        "is_online": true,
        "is_ptz_capable": true,
        "hls_stream_url": "https://stream.yourdomain.com/live/cam_001/index.m3u8",
        "rtsp_stream_url": "rtsp://edge.yourdomain.com:554/live/cam_001",
        "thumbnail_url": "https://media.yourdomain.com/snapshots/cam_001.jpg"
      }
    ]
  }
  ```

### 4.2. Scoped PTZ (Pan-Tilt-Zoom) Camera Control
* **Endpoint:** `POST /api/v5/cameras/{cameraId}/ptz`
* **Headers:** `Authorization: Bearer <access_token>`
* **Request Body:**
  ```json
  {
    "action": "PAN_LEFT", 
    "speed": 1.0,
    "preset_id": "preset_gate_focus"
  }
  ```
  *(Supported `action` values: `PAN_LEFT`, `PAN_RIGHT`, `TILT_UP`, `TILT_DOWN`, `ZOOM_IN`, `ZOOM_OUT`, `STOP`, `RECALL_PRESET`)*

---

## 5. Timeline Playback & Recorded Footage APIs

### 5.1. 24-Hour Timeline Metadata & Segments
* **Endpoint:** `GET /api/v5/cameras/{cameraId}/timeline?date=2026-08-25`
* **Headers:** `Authorization: Bearer <access_token>`
* **Success Response:** `200 OK`
  ```json
  {
    "camera_id": "cam_001",
    "date": "2026-08-25",
    "segments": [
      {
        "segment_id": "seg_101",
        "start_time": "2026-08-25T08:00:00Z",
        "end_time": "2026-08-25T12:00:00Z",
        "type": "CONTINUOUS",
        "hls_url": "https://stream.yourdomain.com/vod/cam_001/seg_101/index.m3u8"
      },
      {
        "segment_id": "seg_102",
        "start_time": "2026-08-25T14:32:10Z",
        "end_time": "2026-08-25T14:45:00Z",
        "type": "MOTION_EVENT",
        "hls_url": "https://stream.yourdomain.com/vod/cam_001/seg_102/index.m3u8"
      }
    ]
  }
  ```

---

## 6. Real-Time Telemetry & Socket.io Event Channels

The mobile app connects to the Socket.io broadcaster immediately after user authentication.

### 6.1. Connection Handshake
* **Path:** `/ws/v5/telemetry`
* **Auth Query / Headers:** `{ "token": "<access_token>" }`

### 6.2. Events Emitted by Backend Server to Mobile Client:

#### A. AI Threat Alarm Event (`threat_alert`)
```json
{
  "id": "alert_89201",
  "camera_id": "cam_001",
  "camera_name": "North Gate Entrance PTZ",
  "site_id": "site_hq",
  "threat_type": "INTRUSION", 
  "severity": "CRITICAL",
  "confidence": 0.94,
  "timestamp": "2026-08-25T19:30:15Z",
  "snapshot_url": "https://media.yourdomain.com/alerts/alert_89201.jpg",
  "metadata": {
    "bounding_box": [120, 45, 300, 400],
    "zone": "Perimeter Fence North"
  }
}
```
*(Threat types: `INTRUSION`, `FIRE`, `SMOKE`, `LOITERING`, `VANDALISM`, `WEAPON_DETECTED`)*

#### B. Camera Status Change (`camera_status`)
```json
{
  "camera_id": "cam_001",
  "is_online": false,
  "last_seen": "2026-08-25T19:35:00Z",
  "reason": "CONNECTION_TIMEOUT"
}
```

#### C. Control Room Emergency Panic Broadcast (`panic_broadcast`)
```json
{
  "panic_id": "panic_771",
  "initiated_by": "Alex Mercer",
  "camera_id": "cam_001",
  "site_id": "site_hq",
  "timestamp": "2026-08-25T19:40:00Z",
  "silent_mode": false,
  "status": "DISPATCHED"
}
```

---

## 7. Emergency Panic Dispatch & Cryptographic Evidence Export

### 7.1. Emergency Panic Dispatch (Mobile to Backend)
* **Endpoint:** `POST /api/v5/panic/dispatch`
* **Request Body:**
  ```json
  {
    "camera_id": "cam_001",
    "site_id": "site_hq",
    "alert_type": "CONTROL_ROOM_SIREN",
    "silent": false,
    "timestamp": "2026-08-25T19:40:00Z"
  }
  ```

### 7.2. Video Evidence Export & Cryptographic Verification
* **Endpoint:** `POST /api/v5/exports`
* **Request Body:**
  ```json
  {
    "camera_id": "cam_001",
    "start_time": "2026-08-25T14:30:00Z",
    "end_time": "2026-08-25T14:45:00Z",
    "case_reference_id": "CASE-2026-8891",
    "include_watermark": true
  }
  ```
* **Poll Status:** `GET /api/v5/exports/{exportId}`
* **Response (Completed):**
  ```json
  {
    "export_id": "exp_5501",
    "status": "COMPLETED",
    "download_url": "https://media.yourdomain.com/exports/clip_5501.mp4",
    "sha256_checksum": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "watermark_verified": true
  }
  ```

---

## 8. ONVIF Device Onboarding API

* **Endpoint:** `POST /api/v5/devices/onboard`
* **Request Body:**
  ```json
  {
    "ip_address": "192.168.1.120",
    "onvif_port": 80,
    "rtsp_port": 554,
    "username": "admin",
    "password": "CameraPassword!",
    "camera_name": "Warehouse Aisle 4",
    "site_id": "site_hq"
  }
  ```

---

## 9. Deliverable Checklist for the Backend Team

Please fill out and return the following details to the mobile development team:

- [ ] **REST API Base URL:** `___________________________________`
- [ ] **Socket.io / WSS Telemetry URL:** `___________________________________`
- [ ] **Test Admin / Operator Credentials:**
  - Email: `___________________________`
  - Password: `___________________________`
  - Tenant ID: `___________________________`
  - Static Test OTP: `___________________________`
- [ ] **Test Camera Stream URL (HLS `.m3u8` or RTSP):** `___________________________________`
- [ ] **Postman / Swagger Collection Link (Optional but recommended):** `___________________________________`

---

*For technical inquiries or payload adjustments, please reach out to the Mobile Application Engineering Team.*
