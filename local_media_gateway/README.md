# SentinVMS Local Media Gateway

This demo gateway converts an interviewer-provided CCTV RTSP stream into:

- WebRTC through MediaMTX WHEP (primary)
- Low-latency HLS (automatic Flutter fallback)

H.264 and H.265 sources are accepted. Compatibility mode transcodes the video
to H.264 baseline with no B-frames so that WebRTC receivers can decode it
reliably. Audio is intentionally disabled in this hiring-demo pipeline.

## Start on Windows

### Docker mode

Open PowerShell in this directory:

```powershell
.\Start-Gateway.cmd
```

The script detects the Windows LAN IPv4 address, creates a gateway access token
when one does not already exist, builds the gateway image, and starts MediaMTX
and the FFmpeg gateway. The token is preserved across restarts. Copy the
printed token into the app.

If automatic address detection chooses the wrong interface:

```powershell
.\Start-Gateway.cmd -HostIp 192.168.1.10
```

Then enter `http://192.168.1.10:8090` and the CCTV RTSP URL in the Flutter
`RTSP / Server Test` screen.

The first Docker build downloads Dart and FFmpeg base layers, so it can take
several minutes on a slow connection. Later starts reuse the local cache.

Before opening the Flutter app, run:

```powershell
.\Test-Gateway.cmd
```

It verifies the authenticated health endpoint and all phone-facing TCP ports.
The `.cmd` launchers work even when Windows blocks direct `.ps1` execution.

### Native Windows mode (no Docker or WSL required)

If Docker Desktop cannot start because WSL or Virtual Machine Platform is not
available, use the portable native path:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-Gateway-Tools.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Start-Gateway-Native.ps1
```

The installer uses WinGet for the FFmpeg Windows build referenced by the
official FFmpeg download page and downloads the official MediaMTX Windows
release from GitHub. The start script runs both services in hidden windows and
prints the gateway URL and generated access token. Stop them with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Stop-Gateway-Native.ps1
```

## Flutter demo flow

1. Keep the gateway computer and Android phone on mutually reachable networks.
2. Open the app drawer and choose `RTSP / Server Test`.
3. Choose `Smart Gateway`.
4. Enter the gateway URL and access token printed by the startup script, then
   enter the CCTV RTSP URL.
5. Keep compatibility transcoding enabled for H.265 cameras, then tap `CONNECT`.

The player tries WHEP WebRTC first and automatically switches to HLS if the
WebRTC connection cannot be established.

## API

Create a stream:

```http
POST /api/v1/streams
Content-Type: application/json

{
  "rtsp_url": "rtsp://user:password@camera-ip:554/stream",
  "transcode": "always"
}
```

The response contains `whep_url`, `hls_url`, detected `source_codec`, and
`delivery_codec`. Stop it with `DELETE /api/v1/streams/{id}`.

## Security boundary

This is a LAN hiring/demo gateway, not the production customer gateway. RTSP
credentials are kept in process memory and are never returned or logged. The
startup script generates `SENTINVMS_GATEWAY_TOKEN` to protect the control API.
Production must
add TLS, authenticated MediaMTX read/publish permissions, secret storage, TURN,
RBAC, and network segmentation.
