import 'dart:io';
import 'package:app/core/video/decoder_pool.dart';
import 'package:app/features/camera/data/camera_repository.dart';
import 'package:app/features/camera/models/camera_model.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoTile extends StatefulWidget {
  const VideoTile({
    required this.camera,
    required this.cameraRepository,
    required this.decoderPool,
    super.key,
  });

  final Camera camera;
  final CameraRepository cameraRepository;
  final DecoderPool decoderPool;

  @override
  State<VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends State<VideoTile> {
  VideoPlayerController? _controller;
  DecoderLease? _lease;
  bool _isLoading = false;
  bool _isEvicted = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _cleanupPlayer();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _isEvicted = false;
      _errorMessage = null;
    });

    _cleanupPlayer();

    try {
      final hlsUrl = await widget.cameraRepository.getLiveStreamUrl(
        siteId: widget.camera.siteId,
        cameraId: widget.camera.id,
      );

      final controller = VideoPlayerController.networkUrl(Uri.parse(hlsUrl));
      _controller = controller;

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      // Acquire hardware decoder lease
      final lease = await widget.decoderPool.acquire(
        cameraId: widget.camera.id,
        controller: controller,
        onEvicted: () {
          if (mounted) {
            setState(() {
              _isEvicted = true;
            });
          }
        },
      );

      _lease = lease;

      if (!mounted) {
        widget.decoderPool.release(lease);
        return;
      }

      await controller.play();
      await controller.setLooping(true);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _cleanupPlayer() {
    final lease = _lease;
    if (lease != null) {
      widget.decoderPool.release(lease);
      _lease = null;
    } else {
      final controller = _controller;
      if (controller != null) {
        try {
          controller.dispose();
        } catch (_) {}
      }
    }
    _controller = null;
  }

  void _showPtzStubToast(String action) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('PTZ $action triggered (Phase 1 UI Stub)'),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF02965E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveVideo = _controller != null &&
        _controller!.value.isInitialized &&
        !_isEvicted &&
        !_isLoading;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0E12),
        border: Border.all(
          color: hasActiveVideo
              ? const Color(0xFF02965E).withValues(alpha: 0.3)
              : const Color(0x2670788C),
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // RepaintBoundary isolates high-FPS video renders
            RepaintBoundary(
              child: _buildVideoContent(),
            ),

            // HUD Tactical Corner Brackets
            if (hasActiveVideo)
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: HUDPainter(),
                  ),
                ),
              ),

            // Top Bar Overlay (Camera Name + Live Telemetry)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: const Color(0xB30D0E12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.camera.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (hasActiveVideo)
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _BlinkingDot(),
                          SizedBox(width: 6),
                          Text(
                            'LIVE • H.265 • 24 FPS • 2.8 Mbps',
                            style: TextStyle(
                              color: Color(0xFF02965E),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // PTZ Stub Controls Overlay
            if (widget.camera.ptzCapable) _buildPtzOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContent() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 32),
              const SizedBox(height: 8),
              const Text(
                'Stream Error',
                style: TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                ),
                onPressed: _initializePlayer,
                child: const Text('Retry', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      );
    }

    if (_isEvicted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pause_circle_outline, color: Color(0xFF70788C), size: 32),
              const SizedBox(height: 8),
              const Text(
                'Playback Paused',
                style: TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Paused to save decoder resources',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF70788C), fontSize: 10),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                ),
                onPressed: _initializePlayer,
                child: const Text('Resume', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading || _controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF02965E)),
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
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
              color: const Color(0xCC14161F),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0x2670788C), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: const Icon(Icons.zoom_in, color: Color(0xFFE2E8F0)),
                  onPressed: () => _showPtzStubToast('Zoom In'),
                ),
                Container(width: 0.5, height: 16, color: const Color(0x2670788C)),
                IconButton(
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: const Icon(Icons.zoom_out, color: Color(0xFFE2E8F0)),
                  onPressed: () => _showPtzStubToast('Zoom Out'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Directional Pad
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xCC14161F),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x2670788C), width: 0.5),
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: IconButton(
                    iconSize: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    icon: const Icon(Icons.arrow_drop_up, color: Color(0xFFE2E8F0)),
                    onPressed: () => _showPtzStubToast('Pan Up'),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: IconButton(
                    iconSize: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFE2E8F0)),
                    onPressed: () => _showPtzStubToast('Pan Down'),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    iconSize: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    icon: const Icon(Icons.arrow_left, color: Color(0xFFE2E8F0)),
                    onPressed: () => _showPtzStubToast('Tilt Left'),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    iconSize: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    icon: const Icon(Icons.arrow_right, color: Color(0xFFE2E8F0)),
                    onPressed: () => _showPtzStubToast('Tilt Right'),
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

class HUDPainter extends CustomPainter {
  const HUDPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF02965E).withValues(alpha: 0.4)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const len = 12.0;

    // Top-Left
    canvas
      ..drawPath(
        Path()
          ..moveTo(0, len)
          ..lineTo(0, 0)
          ..lineTo(len, 0),
        paint,
      )
      // Top-Right
      ..drawPath(
        Path()
          ..moveTo(size.width - len, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, len),
        paint,
      )
      // Bottom-Left
      ..drawPath(
        Path()
          ..moveTo(0, size.height - len)
          ..lineTo(0, size.height)
          ..lineTo(len, size.height),
        paint,
      )
      // Bottom-Right
      ..drawPath(
        Path()
          ..moveTo(size.width - len, size.height)
          ..lineTo(size.width, size.height)
          ..lineTo(size.width, size.height - len),
        paint,
      );
  }

  @override
  bool shouldRepaint(covariant HUDPainter oldDelegate) => false;
}

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: Color(0xFF02965E),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
