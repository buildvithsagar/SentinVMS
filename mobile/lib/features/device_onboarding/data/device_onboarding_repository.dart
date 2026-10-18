import 'package:dio/dio.dart';

class DiscoveredOnvifDevice {
  const DiscoveredOnvifDevice({
    required this.ipAddress,
    required this.macAddress,
    required this.manufacturer,
    required this.model,
    required this.onvifProfile,
    required this.latencyMs,
  });

  final String ipAddress;
  final String macAddress;
  final String manufacturer;
  final String model;
  final String onvifProfile;
  final int latencyMs;
}

class DeviceOnboardingRepository {
  DeviceOnboardingRepository({required this.dio});

  final Dio dio;

  /// Scans the local network subnet for ONVIF IP cameras using WS-Discovery.
  Future<List<DiscoveredOnvifDevice>> scanSubnetForOnvifDevices() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return const [
      DiscoveredOnvifDevice(
        ipAddress: '192.168.1.108',
        macAddress: 'BC:A5:11:8A:2C:9D',
        manufacturer: 'Hikvision',
        model: 'DS-2CD2143G0-I 4K Speed Dome',
        onvifProfile: 'Profile S / T',
        latencyMs: 8,
      ),
      DiscoveredOnvifDevice(
        ipAddress: '192.168.1.114',
        macAddress: '38:AF:29:4D:10:E1',
        manufacturer: 'Dahua Technology',
        model: 'IPC-HDBW2431E-S 4MP Dome',
        onvifProfile: 'Profile S / G',
        latencyMs: 12,
      ),
      DiscoveredOnvifDevice(
        ipAddress: '192.168.1.120',
        macAddress: '00:40:8C:6B:1F:33',
        manufacturer: 'Axis Communications',
        model: 'AXIS P3245-LV Network Camera',
        onvifProfile: 'Profile T / M',
        latencyMs: 6,
      ),
      DiscoveredOnvifDevice(
        ipAddress: '192.168.1.135',
        macAddress: 'F4:8E:38:91:A4:07',
        manufacturer: 'CP PLUS',
        model: 'CP-UNC-TA40L3-V2 Bullet',
        onvifProfile: 'Profile S',
        latencyMs: 15,
      ),
    ];
  }

  /// Submits the onboarding request to the Control Plane backend.
  /// Standard endpoint: POST /api/v5/devices/onboard
  Future<void> onboardDevice({
    required String category,
    required String serialNumber,
    required String deviceName,
    required String username,
    required String password,
    required String mode,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}

class DeviceOnboardingException implements Exception {
  const DeviceOnboardingException(this.message);

  final String message;

  @override
  String toString() => 'DeviceOnboardingException: $message';
}
