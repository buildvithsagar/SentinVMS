import 'package:app/features/stream_demo/stream_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject() {
    return MaterialApp(
      home: StreamDemoPage(
        playerBuilder: (context, source) => Text(
          '${source.mode.name}:${source.uri}',
          key: const Key('fakePlayer'),
        ),
      ),
    );
  }

  testWidgets('renders isolated direct RTSP mode by default', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Stream Diagnostics'), findsOneWidget);
    expect(find.text('Direct RTSP'), findsWidgets);
    expect(find.byKey(const Key('fakePlayer')), findsNothing);
  });

  testWidgets('validates and connects a direct RTSP URL', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.enterText(
      find.byKey(const Key('streamUrlField')),
      'rtsp://user:pass@192.168.1.20/live',
    );
    await tester.ensureVisible(find.byKey(const Key('connectStreamButton')));
    await tester.tap(find.byKey(const Key('connectStreamButton')));
    await tester.pump();

    expect(find.byKey(const Key('fakePlayer')), findsOneWidget);
    expect(find.textContaining('directRtsp:rtsp://'), findsOneWidget);
    expect(find.byKey(const Key('disconnectStreamButton')), findsOneWidget);
  });

  testWidgets('switches to HLS mode and enforces playlist validation', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    await tester.ensureVisible(find.text('Server HLS'));
    await tester.tap(find.text('Server HLS'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('streamUrlField')),
      'http://192.168.1.10/live.mp4',
    );
    await tester.ensureVisible(find.byKey(const Key('connectStreamButton')));
    await tester.tap(find.byKey(const Key('connectStreamButton')));
    await tester.pump();

    expect(
      find.text('Enter an HLS playlist URL ending in .m3u8.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('fakePlayer')), findsNothing);
  });

  testWidgets('connects RTSP through the local media gateway', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.ensureVisible(find.text('Smart Gateway'));
    await tester.tap(find.text('Smart Gateway'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('gatewayUrlField')),
      'http://192.168.1.10:8090',
    );
    await tester.enterText(
      find.byKey(const Key('streamUrlField')),
      'rtsp://camera.local/live',
    );
    await tester.ensureVisible(find.byKey(const Key('connectStreamButton')));
    await tester.tap(find.byKey(const Key('connectStreamButton')));
    await tester.pump();

    expect(find.byKey(const Key('fakePlayer')), findsOneWidget);
    expect(find.textContaining('localGateway:rtsp://'), findsOneWidget);
  });

  testWidgets('disconnect removes the player', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.enterText(
      find.byKey(const Key('streamUrlField')),
      'rtsp://192.168.1.20/live',
    );
    await tester.ensureVisible(find.byKey(const Key('connectStreamButton')));
    await tester.tap(find.byKey(const Key('connectStreamButton')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('disconnectStreamButton')));
    await tester.tap(find.byKey(const Key('disconnectStreamButton')));
    await tester.pump();

    expect(find.byKey(const Key('fakePlayer')), findsNothing);
  });
}
