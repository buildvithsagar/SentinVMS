import 'package:app/features/device_onboarding/data/device_onboarding_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHttpClientAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions());
  });

  group('DeviceOnboardingRepository', () {
    late Dio dio;
    late MockHttpClientAdapter mockAdapter;
    late DeviceOnboardingRepository repository;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://api.example.com/api/v5'));
      mockAdapter = MockHttpClientAdapter();
      dio.httpClientAdapter = mockAdapter;
      repository = DeviceOnboardingRepository(dio: dio);
    });

    test(
      'scanSubnetForOnvifDevices returns list of DiscoveredOnvifDevice objects',
      () async {
        final devices = await repository.scanSubnetForOnvifDevices();

        expect(devices.isNotEmpty, true);
        expect(devices.length, 4);
        expect(devices[0].manufacturer, 'Hikvision');
        expect(devices[0].ipAddress, '192.168.1.108');
        expect(devices[1].manufacturer, 'Dahua Technology');
      },
    );

    test('onboardDevice completes successfully', () async {
      await expectLater(
        repository.onboardDevice(
          category: 'wireless_camera',
          serialNumber: 'SN-99887766',
          deviceName: 'Entrance Dome',
          username: 'admin',
          password: 'Password123!',
          mode: 'onvif',
        ),
        completes,
      );
    });
  });
}
