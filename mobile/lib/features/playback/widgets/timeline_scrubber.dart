import 'dart:math' as math;

import 'package:app/features/playback/models/recording_segment_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// A color-coded timeline scrubber that visualises recording segments
/// and allows the user to seek by tapping or dragging across custom time spans.
class TimelineScrubber extends StatefulWidget {
  const TimelineScrubber({
    required this.segments,
    required this.date,
    required this.onSeek,
    this.currentTime,
    this.spanDuration = const Duration(hours: 24),
    this.height = 80,
    super.key,
  });

  /// Recording segments to display on the timeline.
  final List<RecordingSegment> segments;

  /// The calendar date this timeline represents.
  final DateTime date;

  /// Called when the user scrubs or taps to a new position.
  final ValueChanged<DateTime> onSeek;

  /// Current playback position shown as a vertical playhead.
  final DateTime? currentTime;

  /// Visible time span duration for zooming (24h, 12h, 6h, 3h, 1h, 30m, 15m, 5m).
  final Duration spanDuration;

  /// Total height of the timeline widget.
  final double height;

  @override
  State<TimelineScrubber> createState() => _TimelineScrubberState();
}

class _TimelineScrubberState extends State<TimelineScrubber> {
  /// Horizontal padding reserved for time labels at the edges.
  static const double _horizontalPadding = 24;

  /// Track if the playhead was in a recording segment during last seek update
  bool _lastInSegment = false;

  /// Calculated visible window start date/time.
  DateTime get _windowStart {
    final span = widget.spanDuration;
    final dayStart = DateTime(widget.date.year, widget.date.month, widget.date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    if (span.inHours >= 24) {
      return dayStart;
    }

    final center = widget.currentTime ?? dayStart.add(const Duration(hours: 12));
    var start = center.subtract(Duration(milliseconds: span.inMilliseconds ~/ 2));
    var end = start.add(span);

    if (start.isBefore(dayStart)) {
      start = dayStart;
      end = start.add(span);
    } else if (end.isAfter(dayEnd)) {
      end = dayEnd;
      start = end.subtract(span);
    }
    return start;
  }

  /// Calculated visible window end date/time.
  DateTime get _windowEnd => _windowStart.add(
        widget.spanDuration.inHours >= 24 ? const Duration(days: 1) : widget.spanDuration,
      );

  /// Maps an x-offset (in the full widget width) back to a [DateTime].
  DateTime _offsetToTime(double dx, double fullWidth) {
    final trackWidth = fullWidth - _horizontalPadding * 2;
    final ratio = ((dx - _horizontalPadding) / trackWidth).clamp(0.0, 1.0);
    final totalMs = _windowEnd.difference(_windowStart).inMilliseconds;
    final ms = (ratio * totalMs).round();
    return _windowStart.add(Duration(milliseconds: ms));
  }

  // ─── Gesture handlers ─────────────────────────────────────────────────

  void _handleSeek(double localDx, double fullWidth) {
    final seekTime = _offsetToTime(localDx, fullWidth);

    // Check if the seek time sits inside any active segment
    var isInSegment = false;
    for (final seg in widget.segments) {
      if (seekTime.isAfter(seg.startTime) && seekTime.isBefore(seg.endTime)) {
        isInSegment = true;
        break;
      }
    }

    if (isInSegment != _lastInSegment) {
      _lastInSegment = isInSegment;
      HapticFeedback.lightImpact(); // Physically buzz the phone on crossover!
    }

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
                windowStart: _windowStart,
                windowEnd: _windowEnd,
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
    required this.windowStart,
    required this.windowEnd,
    required this.horizontalPadding,
    this.currentTime,
  });

  final List<RecordingSegment> segments;
  final DateTime windowStart;
  final DateTime windowEnd;
  final DateTime? currentTime;
  final double horizontalPadding;

  // ─── Palette ──────────────────────────────────────────────────────────

  static const Color _bgColor = Colors.transparent;
  static const Color _trackColor = Color(0x1F000000);
  static const Color _gridLineColor = Colors.white10;
  static const Color _labelColor = Color(0xFF94A3B8);

  static const Color _continuousColor = Color(0xFF3B82F6);
  static const Color _motionColor = Color(0xFFF59E0B);
  static const Color _scheduledColor = Color(0xFF10B981);

  // ─── Layout constants ─────────────────────────────────────────────────

  /// Vertical position where the track starts (below time labels).
  static const double _trackTopRatio = 0.35;

  /// Track height as a ratio of total height.
  static const double _trackHeightRatio = 0.40;

  /// Playhead triangle size.
  static const double _triangleSize = 6;

  // ─── Helpers ──────────────────────────────────────────────────────────

  double _timeToX(DateTime time, double trackWidth) {
    final totalMs = windowEnd.difference(windowStart).inMilliseconds;
    if (totalMs <= 0) return horizontalPadding;
    final elapsed = time.difference(windowStart).inMilliseconds;
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
      final clampedStart = segment.startTime.isBefore(windowStart) ? windowStart : segment.startTime;
      final clampedEnd = segment.endTime.isAfter(windowEnd) ? windowEnd : segment.endTime;

      if (clampedStart.isAfter(clampedEnd) || clampedStart.isAtSameMomentAs(clampedEnd)) {
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

    final totalDuration = windowEnd.difference(windowStart);
    Duration tickStep;
    Duration labelStep;
    DateFormat formatter;

    if (totalDuration >= const Duration(hours: 18)) {
      tickStep = const Duration(hours: 1);
      labelStep = const Duration(hours: 2);
      formatter = DateFormat('HH:mm');
    } else if (totalDuration >= const Duration(hours: 8)) {
      tickStep = const Duration(minutes: 30);
      labelStep = const Duration(hours: 1);
      formatter = DateFormat('HH:mm');
    } else if (totalDuration >= const Duration(hours: 4)) {
      tickStep = const Duration(minutes: 15);
      labelStep = const Duration(minutes: 30);
      formatter = DateFormat('HH:mm');
    } else if (totalDuration >= const Duration(hours: 2)) {
      tickStep = const Duration(minutes: 10);
      labelStep = const Duration(minutes: 15);
      formatter = DateFormat('HH:mm');
    } else if (totalDuration >= const Duration(minutes: 45)) {
      tickStep = const Duration(minutes: 2);
      labelStep = const Duration(minutes: 5);
      formatter = DateFormat('HH:mm');
    } else if (totalDuration >= const Duration(minutes: 20)) {
      tickStep = const Duration(minutes: 1);
      labelStep = const Duration(minutes: 5);
      formatter = DateFormat('HH:mm');
    } else if (totalDuration >= const Duration(minutes: 10)) {
      tickStep = const Duration(seconds: 30);
      labelStep = const Duration(minutes: 2);
      formatter = DateFormat('mm:ss');
    } else {
      tickStep = const Duration(seconds: 10);
      labelStep = const Duration(minutes: 1);
      formatter = DateFormat('mm:ss');
    }

    var curr = windowStart;
    while (curr.isBefore(windowEnd) || curr.isAtSameMomentAs(windowEnd)) {
      final x = _timeToX(curr, trackWidth);

      canvas.drawLine(
        Offset(x, trackTop),
        Offset(x, trackTop + trackHeight),
        gridPaint,
      );

      final elapsedSec = curr.difference(windowStart).inSeconds;
      if (elapsedSec % labelStep.inSeconds == 0) {
        final label = formatter.format(curr);
        final textSpan = TextSpan(text: label, style: labelStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, trackTop - textPainter.height - 4),
        );
      }

      curr = curr.add(tickStep);
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

    // Only draw if playhead falls within the visible window.
    if (time.isBefore(windowStart) || time.isAfter(windowEnd)) return;

    final x = _timeToX(time, trackWidth);

    final playheadRect = Rect.fromLTRB(
      x - 2,
      trackTop - 2,
      x + 2,
      trackTop + trackHeight + 2,
    );

    final blueShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF60A5FA),
        const Color(0xFF2563EB),
        const Color(0xFF2563EB).withValues(alpha: 0.1),
      ],
    ).createShader(playheadRect);

    // Draw a soft glowing aura behind the playhead line
    final glowPaint = Paint()
      ..shader = blueShader
      ..strokeWidth = 4.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawLine(
      Offset(x, trackTop - 2),
      Offset(x, trackTop + trackHeight + 2),
      glowPaint,
    );

    // Precise core playhead line
    final linePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF60A5FA),
          Color(0xFF2563EB),
        ],
      ).createShader(playheadRect)
      ..strokeWidth = 1.5;

    canvas.drawLine(
      Offset(x, trackTop - 2),
      Offset(x, trackTop + trackHeight + 2),
      linePaint,
    );

    // Glow behind the triangle indicator
    final triangleGlow = Paint()
      ..color = const Color(0xFF2563EB).withValues(alpha: 0.2)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawCircle(
      Offset(x, trackTop - _triangleSize - 2),
      _triangleSize + 2,
      triangleGlow,
    );

    // Small downward-pointing triangle at the top of the playhead.
    final trianglePath = Path()
      ..moveTo(x - _triangleSize, trackTop - _triangleSize - 2)
      ..lineTo(x + _triangleSize, trackTop - _triangleSize - 2)
      ..lineTo(x, trackTop - 2)
      ..close();

    final trianglePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.fill;

    canvas.drawPath(trianglePath, trianglePaint);
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return oldDelegate.currentTime != currentTime ||
        oldDelegate.segments != segments ||
        oldDelegate.windowStart != windowStart ||
        oldDelegate.windowEnd != windowEnd;
  }
}
