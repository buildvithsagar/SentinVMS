import 'package:app/core/theme/vms_theme.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class HlsPlayerPane extends StatefulWidget {
  const HlsPlayerPane({required this.uri, super.key});

  final Uri uri;

  @override
  State<HlsPlayerPane> createState() => _HlsPlayerPaneState();
}

class _HlsPlayerPaneState extends State<HlsPlayerPane>
    with WidgetsBindingObserver {
  late final VideoPlayerController _controller;
  Object? _error;
  var _muted = false;
  var _resumePlayback = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = VideoPlayerController.networkUrl(widget.uri);
    _initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_resumePlayback) {
          _resumePlayback = false;
          _controller.play();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _resumePlayback = _controller.value.isPlaying;
        if (_resumePlayback) _controller.pause();
    }
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      await _controller.play();
    } catch (error) {
      _error = error;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      await _controller.play();
    }
  }

  Future<void> _toggleMute() async {
    _muted = !_muted;
    await _controller.setVolume(_muted ? 0 : 1);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: _controller,
          child: VideoPlayer(_controller),
          builder: (context, value, player) => AspectRatio(
            aspectRatio: value.isInitialized ? value.aspectRatio : 16 / 9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(
                  color: VmsColors.primary.withValues(alpha: 0.35),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: _error != null
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Unable to open this HLS feed. Check the playlist URL and network access.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: VmsColors.danger),
                          ),
                        ),
                      )
                    : value.isInitialized
                    ? player!
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: _controller,
          builder: (context, value, _) => Row(
            children: [
              Text(
                _error != null
                    ? 'HLS ERROR'
                    : value.isPlaying
                    ? 'HLS LIVE'
                    : 'CONNECTING',
                style: TextStyle(
                  color: _error != null ? VmsColors.danger : VmsColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: value.isPlaying ? 'Pause' : 'Play',
                onPressed: value.isInitialized ? _togglePlayback : null,
                icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                color: Colors.white,
              ),
              IconButton(
                tooltip: _muted ? 'Unmute' : 'Mute',
                onPressed: value.isInitialized ? _toggleMute : null,
                icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
                color: Colors.white,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
