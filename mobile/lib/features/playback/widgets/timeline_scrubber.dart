import 'dart:math' as math;

import 'package:app/features/playback/models/recording_segment_model.dart';
import 'package:flutter/material.dart';

/// A color-coded 24-hour timeline scrubber that visualises recording segments
/// and allows the user to seek by tapping or dragging.
class TimelineScrubber extends StatefulWidget {
  const TimelineScrubber({
    required this.segments,
    required this.date,
    required this.onSeek,
    this.currentTime,
    this.height = 80,
    super.key,
  });

  /// Recording segments to display on the timeline.
  final List<RecordingSegment> segments;

  /// The calendar date this timeline represents (midnight-to-midnight).
  final DateTime date;

  /// Called when the user scrubs or taps to a new position.
  final ValueChanged<DateTime> onSeek;

  /// Current playback position shown as a vertical playhead.
  final DateTime? currentTime;

  /// Total height of the timeline widget.
  final double height;

  @override
  State<TimelineScrubber> createState() => _TimelineScrubberState();
}

class _TimelineScrubberState extends State<TimelineScrubber> {
  /// Horizontal padding reserved for time labels at the edges.
  static const double _horizontalPadding = 24;

  /// Start of the day (00:00:00) for the given date.
  DateTime get _dayStart => DateTime(
        widget.date.year,
        widget.date.month,
        widget.date.day,
      );

  /// End of the day (next midnight).
  DateTime get _dayEnd => _dayStart.add(const Duration(days: 1));

  /// Total number of seconds in the 24-hour span.
  static const int _totalSeconds = 86400; // 24 * 60 * 60

  // ─── Conversion helpers ───────────────────────────────────────────────


  /// Maps an x-offset (in the full widget width) back to a [DateTime].
  DateTime _offsetToTime(double dx, double fullWidth) {
    final trackWidth = fullWidth - _horizontalPadding * 2;
    final ratio = ((dx - _horizontalPadding) / trackWidth).clamp(0.0, 1.0);
    final ms = (ratio * _totalSeconds * 1000).round();
    return _dayStart.add(Duration(milliseconds: ms));
  }

  // ─── Gesture handlers ─────────────────────────────────────────────────

  void _handleSeek(double localDx, double fullWidth) {
    final seekTime = _offsetToTime(localDx, fullWidth);
    widget.onSeek(seekTime);
  }

  // ─── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = constraints.maxWidth;

        return GestureDetector(
          onTapDown: (details) =>
              _handleSeek(details.localPosition.dx, fullWidth),
          onHorizontalDragUpdate: (details) =>
              _handleSeek(details.localPosition.dx, fullWidth),
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size(fullWidth, widget.height),
              painter: _TimelinePainter(
                segments: widget.segments,
                dayStart: _dayStart,
                dayEnd: _dayEnd,
                currentTime: widget.currentTime,
                horizontalPadding: _horizontalPadding,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _TimelinePainter
// ═══════════════════════════════════════════════════════════════════════════

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.segments,
    required this.dayStart,
    required this.dayEnd,
    required this.horizontalPadding,
    this.currentTime,
  });

  final List<RecordingSegment> segments;
  final DateTime dayStart;
  final DateTime dayEnd;
  final DateTime? currentTime;
  final double horizontalPadding;

  // ─── Palette ──────────────────────────────────────────────────────────

  static const Color _bgColor = Color(0xFF1A1D23);
  static const Color _trackColor = Color(0xFF2A2D35);
  static const Color _gridLineColor = Color(0xFF3A3D45);
  static const Color _labelColor = Color(0xFF9E9E9E);
  static const Color _playheadColor = Color(0xFFE0E0E0);

  static const Color _continuousColor = Color(0xFF1565C0);
  static const Color _motionColor = Color(0xFFE65100);
  static const Color _scheduledColor = Color(0xFF02965E);

  // ─── Layout constants ─────────────────────────────────────────────────

  /// Vertical position where the track starts (below time labels).
  static const double _trackTopRatio = 0.35;

  /// Track height as a ratio of total height.
  static const double _trackHeightRatio = 0.40;

  /// Playhead triangle size.
  static const double _triangleSize = 6;

  // ─── Helpers ──────────────────────────────────────────────────────────

  double _timeToX(DateTime time, double trackWidth) {
    final totalMs = dayEnd.difference(dayStart).inMilliseconds;
    if (totalMs == 0) return horizontalPadding;
    final elapsed = time.difference(dayStart).inMilliseconds;
    final ratio = (elapsed / totalMs).clamp(0.0, 1.0);
    return horizontalPadding + ratio * trackWidth;
  }

  Color _colorForType(String type) {
    switch (type.toUpperCase()) {
      case 'MOTION':
        return _motionColor;
      case 'SCHEDULED':
        return _scheduledColor;
      case 'CONTINUOUS':
      default:
        return _continuousColor;
    }
  }

  // ─── Paint ────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final trackWidth = size.width - horizontalPadding * 2;
    final trackTop = size.height * _trackTopRatio;
    final trackHeight = size.height * _trackHeightRatio;

    _drawBackground(canvas, size);
    _drawTrack(canvas, size, trackTop, trackHeight, trackWidth);
    _drawSegments(canvas, trackTop, trackHeight, trackWidth);
    _drawGridLines(canvas, size, trackTop, trackHeight, trackWidth);
    _drawPlayhead(canvas, size, trackTop, trackHeight, trackWidth);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = _bgColor;
    canvas.drawRect(Offset.zero & size, bgPaint);
  }

  void _drawTrack(
    Canvas canvas,
    Size size,
    double trackTop,
    double trackHeight,
    double trackWidth,
  ) {
    final trackPaint = Paint()..color = _trackColor;
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(horizontalPadding, trackTop, trackWidth, trackHeight),
      const Radius.circular(3),
    );
    canvas.drawRRect(trackRect, trackPaint);
  }

  void _drawSegments(
    Canvas canvas,
    double trackTop,
    double trackHeight,
    double trackWidth,
  ) {
    final segmentPaint = Paint()..style = PaintingStyle.fill;

    for (final segment in segments) {
      // Clamp segment times to the visible day range.
      final clampedStart =
          segment.startTime.isBefore(dayStart) ? dayStart : segment.startTime;
      final clampedEnd =
          segment.endTime.isAfter(dayEnd) ? dayEnd : segment.endTime;

      if (clampedStart.isAfter(clampedEnd) ||
          clampedStart.isAtSameMomentAs(clampedEnd)) {
        continue;
      }

      final x1 = _timeToX(clampedStart, trackWidth);
      final x2 = _timeToX(clampedEnd, trackWidth);

      // Enforce minimum visual width of 1 px so tiny segments stay visible.
      final rectWidth = math.max(x2 - x1, 1).toDouble();

      segmentPaint.color = _colorForType(segment.type);

      final segmentRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x1, trackTop, rectWidth, trackHeight),
        const Radius.circular(2),
      );
      canvas.drawRRect(segmentRect, segmentPaint);
    }
  }

  void _drawGridLines(
    Canvas canvas,
    Size size,
    double trackTop,
    double trackHeight,
    double trackWidth,
  ) {
    final gridPaint = Paint()
      ..color = _gridLineColor
      ..strokeWidth = 0.5;

    const labelStyle = TextStyle(
      color: _labelColor,
      fontSize: 9,
      fontFamily: 'monospace',
    );

    for (var hour = 0; hour < 24; hour++) {
      final hourTime = dayStart.add(Duration(hours: hour));
      final x = _timeToX(hourTime, trackWidth);

      // Vertical grid line through the track area.
      canvas.drawLine(
        Offset(x, trackTop),
        Offset(x, trackTop + trackHeight),
        gridPaint,
      );

      // Hour label above the track.
      final label = '${hour.toString().padLeft(2, '0')}:00';
      final textSpan = TextSpan(text: label, style: labelStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      // Only paint every other label when space is tight to avoid overlap.
      if (hour.isEven || trackWidth > 600) {
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, trackTop - textPainter.height - 4),
        );
      }
    }
  }

  void _drawPlayhead(
    Canvas canvas,
    Size size,
    double trackTop,
    double trackHeight,
    double trackWidth,
  ) {
    final time = currentTime;
    if (time == null) return;

    // Only draw if playhead falls within the visible day.
    if (time.isBefore(dayStart) || time.isAfter(dayEnd)) return;

    final x = _timeToX(time, trackWidth);

    final linePaint = Paint()
      ..color = _playheadColor
      ..strokeWidth = 1.5;

    // Vertical line from top of track to bottom.
    canvas.drawLine(
      Offset(x, trackTop - 2),
      Offset(x, trackTop + trackHeight + 2),
      linePaint,
    );

    // Small downward-pointing triangle at the top of the playhead.
    final trianglePath = Path()
      ..moveTo(x - _triangleSize, trackTop - _triangleSize - 2)
      ..lineTo(x + _triangleSize, trackTop - _triangleSize - 2)
      ..lineTo(x, trackTop - 2)
      ..close();

    final trianglePaint = Paint()
      ..color = _playheadColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(trianglePath, trianglePaint);
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return oldDelegate.currentTime != currentTime ||
        oldDelegate.segments != segments ||
        oldDelegate.dayStart != dayStart;
  }
}
