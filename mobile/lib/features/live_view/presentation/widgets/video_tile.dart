import 'dart:async';

import 'package:app/core/core.dart';
import 'package:app/features/camera/camera.dart';
import 'package:app/features/live_view/presentation/widgets/direct_rtsp_video_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:video_player/video_player.dart';

class VideoTile extends StatefulWidget {
  const VideoTile({
    required this.camera,
    required this.cameraRepository,
    required this.decoderPool,
    this.webRtcService,
    this.showPtzOverlay = false,
    this.gridDimension = 1,
    super.key,
  });

  final Camera camera;
  final CameraRepository cameraRepository;
  final DecoderPool decoderPool;
  final WebRtcService? webRtcService;
  final bool showPtzOverlay;
  final int gridDimension;

  @override
  State<VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends State<VideoTile> with WidgetsBindingObserver {
  LiveStreamService? _streamService;
  StreamSubscription<LiveStreamState>? _stateSubscription;
  LiveStreamState _streamState = const LiveStreamState.idle();
  var _initializationId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
  }

  @override
  void didUpdateWidget(VideoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.camera.id != widget.camera.id ||
        oldWidget.camera.siteId != widget.camera.siteId ||
        oldWidget.gridDimension != widget.gridDimension) {
      unawaited(_initializePlayer());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _initializationId++;
    unawaited(_cleanupPlayer());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_initializePlayer());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_streamService?.stop() ?? Future<void>.value());
    }
  }

  Future<void> _initializePlayer() async {
    if (!mounted) return;
    final initializationId = ++_initializationId;
    if (widget.camera.usesDirectRtsp) {
      await _cleanupPlayer();
      return;
    }
    setState(() {
      _streamState = const LiveStreamState(
        phase: LiveStreamPhase.connectingWebRtc,
      );
    });

    await _cleanupPlayer();
    if (!mounted || initializationId != _initializationId) return;

    final service = LiveStreamService(
      cameraRepository: widget.cameraRepository,
      decoderPool: widget.decoderPool,
      webRtcService: widget.webRtcService ?? const WebRtcService(),
    );
    _streamService = service;
    _stateSubscription = service.stateStream.listen((state) {
      if (mounted) setState(() => _streamState = state);
    });
    unawaited(
      service.start(
        cameraId: widget.camera.id,
        siteId: widget.camera.siteId,
        quality: widget.gridDimension >= 3 ? 'sub' : 'main',
      ),
    );
  }

  Future<void> _cleanupPlayer() async {
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    final service = _streamService;
    _streamService = null;
    if (service != null) await service.dispose();
  }

  Future<void> _handlePtzMove(String direction) async {
    try {
      await widget.cameraRepository.movePtz(
        siteId: widget.camera.siteId,
        cameraId: widget.camera.id,
        direction: direction,
      );
      _showPtzResult('Camera moved $direction.');
    } catch (_) {
      _showPtzResult(
        'PTZ move failed. Check the camera connection.',
        error: true,
      );
    }
  }

  Future<void> _handlePtzZoom(String mode) async {
    try {
      await widget.cameraRepository.zoomPtz(
        siteId: widget.camera.siteId,
        cameraId: widget.camera.id,
        zoomMode: mode,
      );
      _showPtzResult('Camera zoom updated.');
    } catch (_) {
      _showPtzResult(
        'PTZ zoom failed. Check the camera connection.',
        error: true,
      );
    }
  }

  Future<void> _handlePtzPreset(int presetId, String name) async {
    try {
      await widget.cameraRepository.presetPtz(
        siteId: widget.camera.siteId,
        cameraId: widget.camera.id,
        presetId: presetId,
      );
      _showPtzResult('Preset $presetId ($name) recalled.');
    } catch (_) {
      _showPtzResult(
        'PTZ preset failed. Check the camera connection.',
        error: true,
      );
    }
  }

  void _showPtzResult(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1600),
          backgroundColor: error ? VmsColors.danger : VmsColors.surfaceHigh,
        ),
      );
  }

  void _showPtzPresetsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final presets = [
          {'id': 1, 'name': 'Main Gate Turnstile'},
          {'id': 2, 'name': 'VIP Parking Bay'},
          {'id': 3, 'name': 'Perimeter North Fence'},
        ];

        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'RECALL PTZ PRESETS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              ...presets.map((p) {
                return ListTile(
                  leading: const Icon(Icons.bookmark, color: Color(0xFF2DD4BF)),
                  title: Text(
                    'Preset ${p['id']}: ${p['name']}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white54,
                    size: 14,
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _handlePtzPreset(p['id']! as int, p['name']! as String);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.camera.usesDirectRtsp) {
      return DirectRtspVideoTile(
        camera: widget.camera,
        gridDimension: widget.gridDimension,
      );
    }
    final hasActiveVideo = _streamState.isLive;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border.all(
          color: hasActiveVideo
              ? const Color(0xFF2563EB).withValues(alpha: 0.4)
              : const Color(0x1FFFFFFF),
        ),
      ),
      child: ClipRRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // RepaintBoundary isolates high-FPS video renders
            RepaintBoundary(child: _buildVideoContent()),

            // Top-Left Camera Name Pill Badge
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.camera.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Top-Right Live Status Pill Badge
            if (hasActiveVideo)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _BlinkingDot(),
                      const SizedBox(width: 4),
                      Text(
                        _streamState.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // PTZ Stub Controls Overlay
            if (widget.camera.ptzCapable && widget.showPtzOverlay)
              _buildPtzOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContent() {
    if (_streamState.phase == LiveStreamPhase.failed) {
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFEF4444),
                  size: 24,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Stream Error',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _initializePlayer,
                  child: const Text('Retry', style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_streamState.phase == LiveStreamPhase.webRtcConnected) {
      final renderer = _streamService?.webRtcConnection?.renderer;
      if (renderer != null) {
        return RTCVideoView(
          renderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        );
      }
    }

    if (_streamState.phase == LiveStreamPhase.hlsConnected) {
      final controller = _streamService?.hlsController;
      if (controller != null && controller.value.isInitialized) {
        return Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        );
      }
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
          ),
          const SizedBox(height: 8),
          Text(
            _streamState.label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPtzOverlay() {
    return Positioned(
      bottom: 8,
      right: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zoom In/Out
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: const Icon(Icons.zoom_in, color: Colors.white),
                  onPressed: () => _handlePtzZoom('in'),
                ),
                Container(width: 1, height: 16, color: Colors.white24),
                IconButton(
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: const Icon(Icons.zoom_out, color: Colors.white),
                  onPressed: () => _handlePtzZoom('out'),
                ),
                Container(width: 1, height: 16, color: Colors.white24),
                IconButton(
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: const Icon(
                    Icons.bookmark_outline,
                    color: Color(0xFF2DD4BF),
                  ),
                  onPressed: _showPtzPresetsSheet,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Directional Pad
          Container(
            width: 144,
            height: 144,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: IconButton(
                    tooltip: 'Tilt up',
                    iconSize: 24,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: const Icon(Icons.arrow_drop_up, color: Colors.white),
                    onPressed: () => _handlePtzMove('up'),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: IconButton(
                    tooltip: 'Tilt down',
                    iconSize: 24,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white,
                    ),
                    onPressed: () => _handlePtzMove('down'),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Pan left',
                    iconSize: 24,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: const Icon(Icons.arrow_left, color: Colors.white),
                    onPressed: () => _handlePtzMove('left'),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Pan right',
                    iconSize: 24,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: const Icon(Icons.arrow_right, color: Colors.white),
                    onPressed: () => _handlePtzMove('right'),
                  ),
                ),
                Align(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlinkingDot extends StatelessWidget {
  const _BlinkingDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: Color(0xFFEF4444),
        shape: BoxShape.circle,
      ),
    );
  }
}
