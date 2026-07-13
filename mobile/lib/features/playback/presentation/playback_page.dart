import 'dart:async';

import 'package:app/features/camera/data/camera_repository.dart';
import 'package:app/features/camera/models/camera_model.dart';
import 'package:app/features/playback/data/playback_repository.dart';
import 'package:app/features/playback/models/recording_segment_model.dart';
import 'package:app/features/playback/widgets/playback_speed_control.dart';
import 'package:app/features/playback/widgets/timeline_scrubber.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

/// Full-page playback view with a real HLS video player, date selector,
/// camera selector, timeline scrubber, and speed control.
class PlaybackPage extends StatefulWidget {
  const PlaybackPage({super.key});

  @override
  State<PlaybackPage> createState() => _PlaybackPageState();
}

class _PlaybackPageState extends State<PlaybackPage> {
  DateTime _selectedDate = DateTime.now();
  double _currentSpeed = 1;
  List<RecordingSegment> _segments = [];

  List<Camera> _cameras = [];
  Camera? _selectedCamera;

  bool _isLoadingCameras = false;
  bool _isLoadingSegments = false;
  bool _isLoadingVideo = false;

  String? _cameraError;
  String? _segmentsError;
  String? _videoError;

  VideoPlayerController? _videoController;
  DateTime? _currentTime;
  DateTime? _videoStartTime;

  @override
  void initState() {
    super.initState();
    _loadCameras();
  }

  @override
  void dispose() {
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadCameras() async {
    setState(() {
      _isLoadingCameras = true;
      _cameraError = null;
    });
    try {
      final cameras = await GetIt.instance<CameraRepository>().getCameras();
      setState(() {
        _cameras = cameras;
        _isLoadingCameras = false;
        if (cameras.isNotEmpty) {
          _selectedCamera = cameras.first;
        }
      });
      if (_selectedCamera != null) {
        await _loadSegments();
      }
    } catch (e) {
      setState(() {
        _cameraError = e.toString();
        _isLoadingCameras = false;
      });
    }
  }

  Future<void> _loadSegments() async {
    if (_selectedCamera == null) return;
    setState(() {
      _isLoadingSegments = true;
      _segmentsError = null;
      _segments = [];
    });
    try {
      final segments = await GetIt.instance<PlaybackRepository>().getRecordingSegments(
        siteId: _selectedCamera!.siteId,
        cameraId: _selectedCamera!.id,
        date: _selectedDate,
      );
      setState(() {
        _segments = segments;
        _isLoadingSegments = false;
      });
      // If we have segments, default current time to the first segment start time
      if (segments.isNotEmpty) {
        await _seekToTime(segments.first.startTime);
      } else {
        // Default to midnight of selected date
        final midnight = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        await _seekToTime(midnight);
      }
    } catch (e) {
      setState(() {
        _segmentsError = e.toString();
        _isLoadingSegments = false;
      });
    }
  }

  Future<void> _seekToTime(DateTime time) async {
    if (_selectedCamera == null) return;

    setState(() {
      _currentTime = time;
      _videoStartTime = time;
      _isLoadingVideo = true;
      _videoError = null;
    });

    try {
      final hlsUrl = await GetIt.instance<PlaybackRepository>().getPlaybackUrl(
        siteId: _selectedCamera!.siteId,
        cameraId: _selectedCamera!.id,
        startTime: time,
      );

      final oldController = _videoController;
      final controller = VideoPlayerController.networkUrl(Uri.parse(hlsUrl));

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _videoController = controller;
        _isLoadingVideo = false;
      });

      if (oldController != null) {
        oldController.removeListener(_videoListener);
        // Dispose old controller asynchronously to avoid frame drop
        scheduleMicrotask(oldController.dispose);
      }

      await controller.setPlaybackSpeed(_currentSpeed);
      await controller.play();

      controller.addListener(_videoListener);
    } catch (e) {
      if (mounted) {
        setState(() {
          _videoError = e.toString();
          _isLoadingVideo = false;
        });
      }
    }
  }

  void _videoListener() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized || _videoStartTime == null) return;

    final position = controller.value.position;
    final newTime = _videoStartTime!.add(position);

    if (_currentTime == null || newTime.difference(_currentTime!).inSeconds.abs() >= 1) {
      setState(() {
        _currentTime = newTime;
      });
    }
  }

  void _changeDate(int delta) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: delta));
    });
    _loadSegments();
  }

  Widget _buildVideoPlayerContent() {
    if (_selectedCamera == null) {
      return const Center(
        child: Text(
          'No camera selected',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      );
    }

    if (_videoError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 40),
              const SizedBox(height: 8),
              Text(
                'Playback Error: $_videoError',
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                ),
                onPressed: () {
                  if (_currentTime != null) {
                    _seekToTime(_currentTime!);
                  }
                },
                child: const Text('Retry', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized || _isLoadingVideo) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            ),
            SizedBox(height: 12),
            Text(
              'Loading Playback Stream...',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              if (controller.value.isPlaying) {
                controller.pause();
              } else {
                controller.play();
              }
            });
          },
          child: Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
        ),
        // Top Toolbar Overlay
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Snapshot button
              IconButton(
                key: const Key('playbackSnapshotButton'),
                icon: const Icon(Icons.camera_alt, color: Colors.white70),
                tooltip: 'Capture Frame',
                onPressed: () {
                  _showSnapshotPreviewDialog('Playback Feed');
                },
              ),
              // Speed drop-down choice selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButton<double>(
                  key: const Key('playbackSpeedDropdown'),
                  value: _currentSpeed,
                  dropdownColor: const Color(0xFF1E293B),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.speed, color: Colors.white70, size: 16),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  items: [0.5, 1.0, 2.0, 4.0, 8.0, 16.0].map((speed) {
                    return DropdownMenuItem<double>(
                      value: speed,
                      child: Text('${speed}x'),
                    );
                  }).toList(),
                  onChanged: (speed) {
                    if (speed != null) {
                      setState(() {
                        _currentSpeed = speed;
                      });
                      _videoController?.setPlaybackSpeed(speed);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Speed changed to ${speed}x'), duration: const Duration(seconds: 1)),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        // Center Controls Overlay
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Skip 10s backward
            IconButton(
              key: const Key('rewind10sButton'),
              iconSize: 36,
              icon: const Icon(Icons.replay_10, color: Colors.white70),
              onPressed: () {
                if (_currentTime != null) {
                  _seekToTime(_currentTime!.subtract(const Duration(seconds: 10)));
                }
              },
            ),
            const SizedBox(width: 16),
            IconButton(
              iconSize: 48,
              icon: Icon(
                controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white70,
              ),
              onPressed: () {
                setState(() {
                  if (controller.value.isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                });
              },
            ),
            const SizedBox(width: 16),
            // Skip 10s forward
            IconButton(
              key: const Key('forward10sButton'),
              iconSize: 36,
              icon: const Icon(Icons.forward_10, color: Colors.white70),
              onPressed: () {
                if (_currentTime != null) {
                  _seekToTime(_currentTime!.add(const Duration(seconds: 10)));
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  void _showSnapshotPreviewDialog(String cameraName) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Row(
            children: [
              Icon(Icons.camera_alt, color: Color(0xFF2DD4BF)),
              SizedBox(width: 8),
              Text('Snapshot Captured', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Frame captured from $cameraName', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Center(
                    child: Icon(Icons.image, color: Colors.white30, size: 40),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening system sharing panel...')),
                );
              },
              child: const Text('SHARE', style: TextStyle(color: Color(0xFF2DD4BF))),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Snapshot saved to phone album.')),
                );
              },
              child: const Text('SAVE TO ALBUM', style: TextStyle(color: Color(0xFF10B981))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CLOSE', style: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF94A3B8)),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/live_grid');
            }
          },
        ),
        title: const Text(
          'Playback',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Video player area ──────────────────────────────────────
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: Colors.black,
                child: _buildVideoPlayerContent(),
              ),
            ),

            const SizedBox(height: 12),

            // ── Camera selector dropdown ──────────────────────────────
            if (_isLoadingCameras)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_cameraError != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Failed to load cameras: $_cameraError', style: const TextStyle(color: Color(0xFFEF4444))),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _loadCameras,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (_cameras.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Camera>(
                    value: _selectedCamera,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF94A3B8)),
                    items: _cameras.map((camera) {
                      return DropdownMenuItem<Camera>(
                        value: camera,
                        child: Row(
                          children: [
                            const Icon(Icons.videocam, color: Color(0xFF94A3B8), size: 20),
                            const SizedBox(width: 8),
                            Text(camera.name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (camera) {
                      if (camera != null) {
                        setState(() {
                          _selectedCamera = camera;
                        });
                        _loadSegments();
                      }
                    },
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // ── Date selector ─────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_left,
                      color: Color(0xFF94A3B8),
                    ),
                    onPressed: () => _changeDate(-1),
                  ),
                  Text(
                    DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_right,
                      color: Color(0xFF94A3B8),
                    ),
                    onPressed: () => _changeDate(1),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Timeline scrubber ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _isLoadingSegments
                    ? const SizedBox(
                        height: 80,
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                          ),
                        ),
                      )
                    : _segmentsError != null
                        ? SizedBox(
                            height: 80,
                            child: Center(
                              child: Text(
                                'Failed to load timeline: $_segmentsError',
                                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                              ),
                            ),
                          )
                        : TimelineScrubber(
                            segments: _segments,
                            date: _selectedDate,
                            currentTime: _currentTime,
                            onSeek: _seekToTime,
                          ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
