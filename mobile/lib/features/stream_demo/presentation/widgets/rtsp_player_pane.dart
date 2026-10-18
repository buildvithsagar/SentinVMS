import 'package:app/core/theme/vms_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

class RtspPlayerPane extends StatefulWidget {
  const RtspPlayerPane({required this.uri, super.key});

  final Uri uri;

  @override
  State<RtspPlayerPane> createState() => _RtspPlayerPaneState();
}

class _RtspPlayerPaneState extends State<RtspPlayerPane>
    with WidgetsBindingObserver {
  late final VlcPlayerController _controller;
  var _muted = false;
  var _resumePlayback = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = _createController(widget.uri);
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

  VlcPlayerController _createController(Uri uri) {
    return VlcPlayerController.network(
      uri.toString(),
      hwAcc: HwAcc.full,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          VlcAdvancedOptions.networkCaching(500),
          VlcAdvancedOptions.clockJitter(0),
          VlcAdvancedOptions.clockSynchronization(1),
        ]),
        http: VlcHttpOptions([VlcHttpOptions.httpReconnect(true)]),
        rtp: VlcRtpOptions([VlcRtpOptions.rtpOverRtsp(true)]),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller
      ..stop()
      ..dispose();
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
    await _controller.setVolume(_muted ? 0 : 100);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
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
              child: ValueListenableBuilder<VlcPlayerValue>(
                valueListenable: _controller,
                child: VlcPlayer(
                  controller: _controller,
                  aspectRatio: 16 / 9,
                  placeholder: const Center(child: CircularProgressIndicator()),
                ),
                builder: (context, value, player) => Stack(
                  fit: StackFit.expand,
                  children: [
                    player!,
                    if (!value.isInitialized)
                      const Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Connecting to RTSP over TCP...',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    if (value.hasError)
                      const ColoredBox(
                        color: Colors.black87,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Unable to open this RTSP feed. Check the camera URL, credentials, network access, and codec support.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: VmsColors.danger),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<VlcPlayerValue>(
          valueListenable: _controller,
          builder: (context, value, _) => Row(
            children: [
              _StatusChip(
                label: value.hasError
                    ? 'ERROR'
                    : value.isPlaying
                    ? 'RTSP LIVE'
                    : value.isBuffering
                    ? 'BUFFERING'
                    : 'CONNECTING',
                active: value.isPlaying,
              ),
              const Spacer(),
              IconButton(
                tooltip: value.isPlaying ? 'Pause' : 'Play',
                onPressed: _togglePlayback,
                icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                color: Colors.white,
              ),
              IconButton(
                tooltip: _muted ? 'Unmute' : 'Mute',
                onPressed: _toggleMute,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? VmsColors.success : VmsColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
