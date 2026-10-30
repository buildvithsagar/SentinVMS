import 'package:app/core/core.dart';
import 'package:app/features/device_onboarding/device_onboarding.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

void main() {
  final getIt = GetIt.instance;

  setUp(() {
    getIt.registerSingleton<DeviceOnboardingRepository>(
      DeviceOnboardingRepository(dio: Dio()),
    );
  });

  tearDown(getIt.reset);

  testWidgets('scanned payload autofills recognized device fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: VmsTheme.dark,
        home: DeviceDetailsFormPage(
          category: 'wired_camera',
          mode: 'insta_on',
          scanCode: (_) async => '''
            {
              "device": {
                "sn": "CAM-998877",
                "name": "Loading Bay",
                "username": "operator"
              }
            }
          ''',
        ),
      ),
    );

    final scanButton = find.byKey(const Key('scanDeviceCodeButton'));
    await tester.ensureVisible(scanButton);
    await tester.tap(scanButton);
    await tester.pumpAndSettle();

    final serialField = tester.widget<TextFormField>(
      find.byKey(const Key('deviceSerialField')),
    );
    final nameField = tester.widget<TextFormField>(
      find.byKey(const Key('deviceNameField')),
    );
    final usernameField = tester.widget<TextFormField>(
      find.byKey(const Key('deviceUsernameField')),
    );

    expect(serialField.controller?.text, 'CAM-998877');
    expect(nameField.controller?.text, 'Loading Bay');
    expect(usernameField.controller?.text, 'operator');
    expect(find.text('Device code parsed'), findsOneWidget);
  });

  testWidgets('unrecognized payload does not overwrite serial field', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: VmsTheme.dark,
        home: DeviceDetailsFormPage(
          category: 'wired_camera',
          mode: 'insta_on',
          initialSerialNumber: 'KEEP-ME',
          scanCode: (_) async => 'WIFI:T:WPA;S:Camera_Setup;P:secret;;',
        ),
      ),
    );

    final scanButton = find.byKey(const Key('scanDeviceCodeButton'));
    await tester.ensureVisible(scanButton);
    await tester.tap(scanButton);
    await tester.pumpAndSettle();

    final serialField = tester.widget<TextFormField>(
      find.byKey(const Key('deviceSerialField')),
    );
    expect(serialField.controller?.text, 'KEEP-ME');
    expect(find.text('Code needs review'), findsOneWidget);
  });
}
