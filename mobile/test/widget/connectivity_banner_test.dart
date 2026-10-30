import 'dart:async';

import 'package:app/core/core.dart';
import 'package:app/core/widgets/connectivity_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('online state renders no hidden banner at any safe-area height', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _FakeConnectivityService(ConnectivityStatus.online);
    addTearDown(service.dispose);

    await tester.pumpWidget(
      _subject(service: service, size: const Size(360, 800), topPadding: 120),
    );

    expect(find.byKey(const Key('offlineConnectivityBanner')), findsNothing);
    expect(find.textContaining('Control plane offline'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline banner respects a phone notch', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _FakeConnectivityService(ConnectivityStatus.offline);
    addTearDown(service.dispose);

    await tester.pumpWidget(
      _subject(service: service, size: const Size(360, 800), topPadding: 48),
    );

    expect(find.byKey(const Key('offlineConnectivityBanner')), findsOneWidget);
    expect(find.textContaining('Control plane offline'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline banner remains centered without overflow on a tablet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _FakeConnectivityService(ConnectivityStatus.offline);
    addTearDown(service.dispose);

    await tester.pumpWidget(
      _subject(service: service, size: const Size(1280, 800), topPadding: 24),
    );

    final banner = tester.getSize(
      find.byKey(const Key('offlineConnectivityBanner')),
    );
    expect(banner.width, 1280);
    expect(tester.takeException(), isNull);
  });

  testWidgets('banner disappears completely when connectivity returns', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _FakeConnectivityService(ConnectivityStatus.offline);
    addTearDown(service.dispose);

    await tester.pumpWidget(
      _subject(service: service, size: const Size(390, 844)),
    );
    expect(find.byKey(const Key('offlineConnectivityBanner')), findsOneWidget);

    service.emit(ConnectivityStatus.online);
    await tester.pump();

    expect(find.byKey(const Key('offlineConnectivityBanner')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _subject({
  required ConnectivityService service,
  required Size size,
  double topPadding = 0,
}) {
  return MaterialApp(
    theme: VmsTheme.dark,
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        padding: EdgeInsets.only(top: topPadding),
      ),
      child: ConnectivityBanner(
        connectivityService: service,
        child: const Scaffold(body: Center(child: Text('SentinVMS'))),
      ),
    ),
  );
}

class _FakeConnectivityService extends ConnectivityService {
  _FakeConnectivityService(this._status) : super(enabled: false);

  final _controller = StreamController<ConnectivityStatus>.broadcast();
  ConnectivityStatus _status;

  @override
  ConnectivityStatus get currentStatus => _status;

  @override
  Stream<ConnectivityStatus> get statusStream => _controller.stream;

  void emit(ConnectivityStatus status) {
    _status = status;
    _controller.add(status);
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}
