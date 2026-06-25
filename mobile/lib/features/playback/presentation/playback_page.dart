import 'package:app/features/playback/models/recording_segment_model.dart';
import 'package:app/features/playback/widgets/playback_speed_control.dart';
import 'package:app/features/playback/widgets/timeline_scrubber.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Full-page playback view with a video placeholder, date selector,
/// timeline scrubber, and speed control.
class PlaybackPage extends StatefulWidget {
  const PlaybackPage({super.key});

  @override
  State<PlaybackPage> createState() => _PlaybackPageState();
}

class _PlaybackPageState extends State<PlaybackPage> {
  DateTime _selectedDate = DateTime.now();
  double _currentSpeed = 1;
  List<RecordingSegment> _segments = [];

  @override
  void initState() {
    super.initState();
    _loadMockSegments();
  }

  void _loadMockSegments() {
    final day = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    _segments = [
      RecordingSegment(
        id: 'seg-001',
        siteId: 'site-001',
        cameraId: 'cam-front-gate',
        startTime: day.add(const Duration(hours: 1)),
        endTime: day.add(const Duration(hours: 5, minutes: 30)),
        type: 'CONTINUOUS',
      ),
      RecordingSegment(
        id: 'seg-002',
        siteId: 'site-001',
        cameraId: 'cam-front-gate',
        startTime: day.add(const Duration(hours: 8, minutes: 15)),
        endTime: day.add(const Duration(hours: 9, minutes: 45)),
        type: 'MOTION',
      ),
      RecordingSegment(
        id: 'seg-003',
        siteId: 'site-001',
        cameraId: 'cam-front-gate',
        startTime: day.add(const Duration(hours: 14)),
        endTime: day.add(const Duration(hours: 18)),
        type: 'SCHEDULED',
      ),
    ];
  }

  void _changeDate(int delta) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: delta));
      _loadMockSegments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2D35),
        elevation: 0,
        title: const Text(
          'Playback',
          style: TextStyle(
            color: Color(0xFFE0E0E0),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFE0E0E0)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Video placeholder ──────────────────────────────────────
            const AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: Colors.black,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.videocam,
                      color: Color(0xFF9E9E9E),
                      size: 48,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Front Gate Camera',
                      style: TextStyle(
                        color: Color(0xFFE0E0E0),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Playback video player',
                      style: TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Date selector ─────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2D35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_left,
                      color: Color(0xFFE0E0E0),
                    ),
                    onPressed: () => _changeDate(-1),
                  ),
                  Text(
                    DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
                    style: const TextStyle(
                      color: Color(0xFFE0E0E0),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_right,
                      color: Color(0xFFE0E0E0),
                    ),
                    onPressed: () => _changeDate(1),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Timeline scrubber ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2D35),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TimelineScrubber(
                  segments: _segments,
                  date: _selectedDate,
                  onSeek: (seekTime) {
                    // TODO(dev): Seek the video player to this time.
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Speed control ─────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2D35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Playback Speed',
                    style: TextStyle(
                      color: Color(0xFFE0E0E0),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: PlaybackSpeedControl(
                      currentSpeed: _currentSpeed,
                      onSpeedChanged: (speed) {
                        setState(() {
                          _currentSpeed = speed;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
