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
        backgroundColor: const Color(0xFF2563EB),
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
            RepaintBoundary(
              child: _buildVideoContent(),
            ),

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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BlinkingDot(),
                      SizedBox(width: 4),
                      Text(
                        'LIVE • 24 FPS',
                        style: TextStyle(
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
              const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 32),
              const SizedBox(height: 8),
              const Text(
                'Stream Error',
                style: TextStyle(
                  color: Color(0xFF1E293B),
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
              const Icon(Icons.pause_circle_outline, color: Color(0xFF64748B), size: 32),
              const SizedBox(height: 8),
              const Text(
                'Playback Paused',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Paused to save decoder resources',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), fontSize: 10),
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
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
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
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.zoom_in, color: Colors.white),
                  onPressed: () => _showPtzStubToast('Zoom In'),
                ),
                Container(width: 1, height: 16, color: Colors.white24),
                IconButton(
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.zoom_out, color: Colors.white),
                  onPressed: () => _showPtzStubToast('Zoom Out'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Directional Pad
          Container(
            width: 80,
            height: 80,
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
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: const Icon(Icons.arrow_drop_up, color: Colors.white),
                    onPressed: () => _showPtzStubToast('Pan Up'),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: IconButton(
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                    onPressed: () => _showPtzStubToast('Pan Down'),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: const Icon(Icons.arrow_left, color: Colors.white),
                    onPressed: () => _showPtzStubToast('Tilt Left'),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: const Icon(Icons.arrow_right, color: Colors.white),
                    onPressed: () => _showPtzStubToast('Tilt Right'),
                  ),
                ),
                Align(
                  child: Container(
                    width: 24,
                    height: 24,
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
          color: Color(0xFFEF4444),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
