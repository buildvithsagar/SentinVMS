import 'dart:async';

import 'package:app/core/core.dart';
import 'package:app/features/camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

class DirectRtspVideoTile extends StatefulWidget {
  const DirectRtspVideoTile({
    required this.camera,
    this.gridDimension = 1,
    super.key,
  });

  final Camera camera;
  final int gridDimension;

  @override
  State<DirectRtspVideoTile> createState() => _DirectRtspVideoTileState();
}

class _DirectRtspVideoTileState extends State<DirectRtspVideoTile>
    with WidgetsBindingObserver {
  VlcPlayerController? _controller;
  var _resumePlayback = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connect();
  }

  @override
  void didUpdateWidget(DirectRtspVideoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.camera.streamUrlForGrid(oldWidget.gridDimension) !=
        widget.camera.streamUrlForGrid(widget.gridDimension)) {
      _connect();
    }
  }

  void _connect() {
    final previous = _controller;
    final streamUrl = widget.camera.streamUrlForGrid(widget.gridDimension);
    final next = VlcPlayerController.network(
      streamUrl,
      hwAcc: HwAcc.full,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          VlcAdvancedOptions.networkCaching(500),
          VlcAdvancedOptions.clockJitter(0),
          VlcAdvancedOptions.clockSynchronization(1),
        ]),
        rtp: VlcRtpOptions([VlcRtpOptions.rtpOverRtsp(true)]),
      ),
    );
    if (mounted) setState(() => _controller = next);
    if (previous != null) {
      unawaited(previous.stop().whenComplete(previous.dispose));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (_resumePlayback) {
          _resumePlayback = false;
          unawaited(controller.play());
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _resumePlayback = controller.value.isPlaying;
        if (_resumePlayback) unawaited(controller.pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      unawaited(controller.stop().whenComplete(controller.dispose));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: ValueListenableBuilder<VlcPlayerValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: VlcPlayer(
                    controller: controller,
                    aspectRatio: 16 / 9,
                    placeholder: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
              if (!value.isInitialized && !value.hasError)
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2),
                      SizedBox(height: 8),
                      Text(
                        'Connecting RTSP...',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              if (value.hasError)
                ColoredBox(
                  color: Colors.black87,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: VmsColors.danger,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'RTSP connection failed',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          TextButton(
                            onPressed: _connect,
                            child: const Text('RETRY'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 6,
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: value.isPlaying
                            ? VmsColors.success
                            : VmsColors.warning,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.camera.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(blurRadius: 4)],
                        ),
                      ),
                    ),
                    Text(
                      value.isPlaying ? 'LIVE' : 'RTSP',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
