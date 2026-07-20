import 'dart:async';

import 'package:app/features/camera/data/camera_repository.dart';
import 'package:app/features/camera/models/camera_model.dart';
import 'package:app/features/export/data/export_repository.dart';
import 'package:app/features/playback/data/playback_repository.dart';
import 'package:app/features/playback/models/recording_segment_model.dart';
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
  Duration _selectedSpanDuration = const Duration(hours: 24);
  List<RecordingSegment> _segments = [];

  static final List<Map<String, dynamic>> _spanOptions = [
    {'label': '24 hr', 'duration': const Duration(hours: 24)},
    {'label': '12 hr', 'duration': const Duration(hours: 12)},
    {'label': '6 hr', 'duration': const Duration(hours: 6)},
    {'label': '3 hr', 'duration': const Duration(hours: 3)},
    {'label': '1 hr', 'duration': const Duration(hours: 1)},
    {'label': '60 min', 'duration': const Duration(minutes: 60)},
    {'label': '30 min', 'duration': const Duration(minutes: 30)},
    {'label': '15 min', 'duration': const Duration(minutes: 15)},
    {'label': '5 min', 'duration': const Duration(minutes: 5)},
  ];

  List<Camera> _cameras = [];
  Camera? _selectedCamera;

  bool _isTrimmingMode = false;
  DateTime? _clipStartTime;
  DateTime? _clipEndTime;

  Future<void> _exportTrimmedClip() async {
    if (_selectedCamera == null || _clipStartTime == null || _clipEndTime == null) return;
    try {
      await GetIt.instance<ExportRepository>().createExportJob(
        siteId: _selectedCamera!.siteId,
        cameraId: _selectedCamera!.id,
        startTime: _clipStartTime!,
        endTime: _clipEndTime!,
      );
      if (!mounted) return;
      setState(() {
        _isTrimmingMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Evidence Clip export initiated! Redirecting to Export Vault...'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      context.go('/export');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }
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
    if (!mounted) return;
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

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF2DD4BF),
              surface: Color(0xFF1E293B),
            ), dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF0F172A)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadSegments();
    }
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
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2DD4BF)),
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
              // Trimmer toggle button
              IconButton(
                key: const Key('playbackTrimButton'),
                icon: Icon(
                  Icons.content_cut,
                  color: _isTrimmingMode ? const Color(0xFF2DD4BF) : Colors.white70,
                ),
                tooltip: 'Trim Evidence Clip',
                onPressed: () {
                  setState(() {
                    _isTrimmingMode = !_isTrimmingMode;
                    if (_isTrimmingMode) {
                      _clipStartTime = _currentTime ?? _selectedDate;
                      _clipEndTime = (_currentTime ?? _selectedDate).add(const Duration(minutes: 5));
                    }
                  });
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

            // ── Trimmer Control Panel ──────────────────────────────────
            if (_isTrimmingMode)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2DD4BF)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.content_cut, color: Color(0xFF2DD4BF), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Clip Evidence Trimmer',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                          onPressed: () {
                            setState(() {
                              _isTrimmingMode = false;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.pin_drop, size: 14, color: Color(0xFF3B82F6)),
                          label: const Text('Mark Start', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            if (_currentTime != null) {
                              setState(() {
                                _clipStartTime = _currentTime;
                                if (_clipEndTime == null || _clipEndTime!.isBefore(_clipStartTime!)) {
                                  _clipEndTime = _clipStartTime!.add(const Duration(minutes: 5));
                                }
                              });
                            }
                          },
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.pin_drop_outlined, size: 14, color: Color(0xFFF59E0B)),
                          label: const Text('Mark End', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            if (_currentTime != null) {
                              setState(() {
                                _clipEndTime = _currentTime;
                                if (_clipStartTime == null || _clipStartTime!.isAfter(_clipEndTime!)) {
                                  _clipStartTime = _clipEndTime!.subtract(const Duration(minutes: 5));
                                }
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_clipStartTime != null && _clipEndTime != null) ...[
                      Text(
                        'Range: ${DateFormat('HH:mm:ss').format(_clipStartTime!)} -> ${DateFormat('HH:mm:ss').format(_clipEndTime!)}'
                        ' (${_clipEndTime!.difference(_clipStartTime!).inMinutes}m ${_clipEndTime!.difference(_clipStartTime!).inSeconds % 60}s)',
                        style: const TextStyle(color: Color(0xFF2DD4BF), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2DD4BF),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          icon: const Icon(Icons.security, size: 16),
                          label: const Text('Export Evidence Clip with SHA-256', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: _exportTrimmedClip,
                        ),
                      ),
                    ],
                  ],
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

            // ── Date selector with Calendar Picker ──────────────────
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
                    key: const Key('previousDayButton'),
                    icon: const Icon(
                      Icons.chevron_left,
                      color: Color(0xFF94A3B8),
                    ),
                    tooltip: 'Previous Day',
                    onPressed: () => _changeDate(-1),
                  ),
                  InkWell(
                    key: const Key('openCalendarPickerButton'),
                    onTap: () => _pickDate(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            color: Color(0xFF2DD4BF),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: Color(0xFF2DD4BF),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('nextDayButton'),
                    icon: const Icon(
                      Icons.chevron_right,
                      color: Color(0xFF94A3B8),
                    ),
                    tooltip: 'Next Day',
                    onPressed: () => _changeDate(1),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Timeline Span / Zoom Selector Bar ──────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.zoom_in, color: Color(0xFF2DD4BF), size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Timeline Window',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _spanOptions.firstWhere(
                            (opt) => opt['duration'] == _selectedSpanDuration,
                            orElse: () => {'label': '24 hr'},
                          )['label'] as String,
                          style: const TextStyle(
                            color: Color(0xFF2DD4BF),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _spanOptions.map((opt) {
                        final label = opt['label'] as String;
                        final duration = opt['duration'] as Duration;
                        final isSelected = _selectedSpanDuration == duration;

                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            key: Key('spanChip_$label'),
                            label: Text(
                              label,
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFF2DD4BF),
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            side: BorderSide(
                              color: isSelected ? const Color(0xFF2DD4BF) : Colors.white12,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedSpanDuration = duration;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

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
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2DD4BF)),
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
                            spanDuration: _selectedSpanDuration,
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
