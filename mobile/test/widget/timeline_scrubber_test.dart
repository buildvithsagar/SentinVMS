import 'package:app/features/playback/models/recording_segment_model.dart';
import 'package:app/features/playback/widgets/timeline_scrubber.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimelineScrubber Widget Tests', () {
    final testDate = DateTime(2026, 6, 25);
    final segments = [
      RecordingSegment(
        id: 'seg-1',
        siteId: 'site-1',
        cameraId: 'cam-1',
        startTime: testDate.add(const Duration(hours: 2)),
        endTime: testDate.add(const Duration(hours: 4)),
        type: 'CONTINUOUS',
      ),
      RecordingSegment(
        id: 'seg-2',
        siteId: 'site-1',
        cameraId: 'cam-1',
        startTime: testDate.add(const Duration(hours: 8)),
        endTime: testDate.add(const Duration(hours: 9)),
        type: 'MOTION',
      ),
    ];

    testWidgets('renders TimelineScrubber and CustomPaint widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimelineScrubber(
              segments: segments,
              date: testDate,
              onSeek: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(TimelineScrubber), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TimelineScrubber),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('triggers onSeek when tapped/dragged', (tester) async {
      DateTime? seekedTime;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimelineScrubber(
              segments: segments,
              date: testDate,
              onSeek: (time) {
                seekedTime = time;
              },
            ),
          ),
        ),
      );

      // Find the scrubber widget
      final scrubberFinder = find.byType(TimelineScrubber);
      final size = tester.getSize(scrubberFinder);
      final offset = tester.getCenter(scrubberFinder);

      // Let's tap at 25% from the left (which corresponds to 06:00:00)
      // Since padding is 24 on each side, track starts at 24 and ends at width - 24.
      // Let's compute a local X position of 25% of width.
      final targetX = size.width * 0.25;

      // Tap down
      await tester.tapAt(Offset(targetX, offset.dy));
      await tester.pump();

      expect(seekedTime, isNotNull);
      expect(seekedTime!.day, 25);
      expect(seekedTime!.month, 6);
      expect(seekedTime!.year, 2026);
    });
  });
}
