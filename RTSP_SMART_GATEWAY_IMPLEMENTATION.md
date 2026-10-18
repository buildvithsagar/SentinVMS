# SentinVMS RTSP and Smart Gateway Implementation

Last verified: 19 October 2026

## Purpose

SentinVMS can demonstrate a CCTV feed supplied as an RTSP URL in three ways:

1. **Direct RTSP** - the Android app opens the camera directly with VLC.
2. **Smart Gateway** - a computer receives RTSP, optionally converts H.265 to
   H.264, and delivers the result to the app with WebRTC and automatic HLS
   fallback.
3. **Server HLS** - the app plays an existing HTTP(S) `.m3u8` playlist.

Camera URLs and gateway tokens are entered at runtime. They are not committed
to this repository, and the stream form keeps credentials in memory only.

## Implemented architecture

```text
Direct mode
CCTV RTSP -> flutter_vlc_player -> Android decoder -> SentinVMS UI

Smart Gateway mode
CCTV RTSP (H.264/H.265)
    -> Gateway API
    -> FFmpeg probe/transcode
    -> MediaMTX
    -> WHEP WebRTC (primary) or low-latency HLS (fallback)
    -> SentinVMS UI

Existing HLS mode
HLS server (.m3u8) -> video_player -> SentinVMS UI
```

Docker is not installed on the phone. It is only one way to run FFmpeg,
MediaMTX, and the gateway API on a laptop, mini-PC, NVR server, or other
computer that can reach the camera. A native Windows launcher is also included.

## Flutter implementation

The `RTSP / Server Test` screen is available from the application drawer and
supports:

- selection between Direct RTSP, Smart Gateway, and Server HLS;
- RTSP, RTSPS, HTTP, and HTTPS validation appropriate to the selected mode;
- safe normalization of credentials containing reserved characters such as
  `@`;
- RTSP-over-TCP, hardware acceleration, and a short VLC network cache;
- gateway health checks and bearer-token authentication;
- H.265 compatibility conversion control;
- WebRTC-first playback with automatic HLS fallback;
- visible connection, codec, and transcode status;
- player cleanup when the page closes or the app moves to the background;
- automatic gateway stream deletion when a Smart Gateway session ends.

Important implementation files:

- `mobile/lib/features/stream_demo/presentation/pages/stream_demo_page.dart`
- `mobile/lib/features/stream_demo/presentation/widgets/rtsp_player_pane.dart`
- `mobile/lib/features/stream_demo/presentation/widgets/local_gateway_player_pane.dart`
- `mobile/lib/features/stream_demo/presentation/widgets/hls_player_pane.dart`
- `mobile/lib/features/stream_demo/data/local_gateway_client.dart`
- `mobile/lib/features/stream_demo/models/stream_demo_source.dart`
- `mobile/lib/core/video/whep_service.dart`
- `mobile/lib/core/video/webrtc_service.dart`

The project pins the VLC platform interface to the compatible upstream commit
because the published Android and Dart Pigeon channel names were mismatched in
the dependency combination previously resolved by Pub.

## Local gateway implementation

The gateway is located in `local_media_gateway/` and provides:

- authenticated `GET /health`;
- authenticated stream creation through `POST /api/v1/streams`;
- individual session inspection and deletion;
- RTSP source validation and codec probing;
- H.264 pass-through where appropriate;
- H.265-to-H.264 compatibility transcoding through FFmpeg;
- MediaMTX WHEP WebRTC and low-latency HLS output;
- a maximum stream limit and automatic stream TTL cleanup;
- Docker and native Windows launch paths;
- LAN connectivity preflight checks.

Default phone-facing ports:

| Port | Protocol | Purpose |
| ---: | --- | --- |
| 8090 | TCP | Gateway control API |
| 8888 | TCP | MediaMTX HLS |
| 8889 | TCP | MediaMTX WebRTC/WHEP HTTP signalling |
| 8189 | UDP/TCP | MediaMTX WebRTC media/ICE |

The `.env` file, generated access token, downloaded native tools, generated
certificates, and build output are intentionally excluded from Git.

## Start the gateway with Docker

From the repository root:

```powershell
cd local_media_gateway
.\Start-Gateway.cmd
.\Test-Gateway.cmd
```

The startup command prints the computer's gateway URL and generated access
token. Keep both private. Enter them in Smart Gateway mode together with the
camera RTSP URL.

If the wrong network interface is selected, provide the reachable address:

```powershell
.\Start-Gateway.cmd -HostIp 192.168.1.10
```

Stop the Docker gateway with:

```powershell
.\Stop-Gateway.cmd
```

## Start the gateway without Docker

The native Windows option still requires FFmpeg and MediaMTX, but does not
require Docker Desktop or WSL:

```powershell
cd local_media_gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-Gateway-Tools.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Start-Gateway-Native.ps1
```

Stop it with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Stop-Gateway-Native.ps1
```

## Phone connection scenarios

### Public RTSP over SIM/mobile data

Direct RTSP can work without a gateway when the camera address and RTSP port
are reachable from the public internet and the phone can decode the camera
codec. RTSP-over-TCP is enabled in the app. H.265 success still depends on the
physical phone's decoder and the mobile network.

### Private camera and phone on the same LAN

Run the gateway on a computer that can reach the camera. Connect the phone to
the same Wi-Fi and use the computer's LAN address, for example
`http://192.168.1.10:8090`.

### Private camera and remote phone on SIM/mobile data

A private camera cannot be reached directly through NAT. Keep an always-on
gateway device at the camera site and connect the gateway device and phone with
an encrypted VPN such as Tailscale or WireGuard. Start the gateway with the VPN
address advertised to MediaMTX:

```powershell
.\Start-Gateway.cmd -HostIp 100.x.x.x
```

Then use `http://100.x.x.x:8090` in the phone app. The VPN/firewall policy must
allow the four phone-facing ports listed above. This avoids exposing the RTSP
camera port directly to the internet.

For a production public service, use a managed gateway with HTTPS, TURN,
authenticated MediaMTX access, secret storage, RBAC, monitoring, and network
segmentation instead of exposing this LAN demo service directly.

## Verification completed

The following checks have been completed with an actual H.265 CCTV source; no
camera credentials are stored in the repository:

- Direct RTSP opened and rendered through VLC on the Android emulator.
- Smart Gateway detected the source as H.265.
- FFmpeg delivered an H.264 transcoded stream to MediaMTX.
- WHEP negotiation reached the connected state.
- The Android H.264 decoder initialized and continued receiving packets.
- The UI reported `LIVE - LOW LATENCY` and `H265 -> H264 - transcoded`.
- Gateway health and ports 8090, 8888, 8889, and 8189 passed preflight.
- The temporary session was deleted after the test and active streams returned
  to zero.
- Focused Flutter analysis/tests and gateway unit tests cover URL parsing,
  gateway models, FFmpeg commands, and stream screen behaviour.

## Remaining validation

- Repeat Direct RTSP and Smart Gateway playback on a physical Android phone.
- Test once on the intended phone using SIM/mobile data.
- Validate the VPN route and firewall rules before a remote private-network
  demonstration.
- Add TURN/TLS and production authentication before offering the gateway as a
  public internet service.

## Troubleshooting

- **Gateway unreachable:** never enter `localhost` on the phone; use the
  gateway computer's LAN/VPN IP and confirm the firewall ports.
- **Gateway can start but cannot reach camera:** verify RTSP credentials,
  camera path, routing, and RTSP-over-TCP availability from the gateway host.
- **Direct RTSP black screen:** enable Smart Gateway compatibility conversion;
  the phone may not support the source's H.265 profile.
- **WebRTC does not connect:** confirm advertised host and port 8189. The app
  will attempt HLS automatically if the gateway returned a valid HLS URL.
- **First connection is slower:** codec probing and an H.265 transcode process
  can take several seconds to become ready.
