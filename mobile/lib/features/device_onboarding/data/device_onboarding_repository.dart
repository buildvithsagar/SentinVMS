import 'package:dio/dio.dart';

class DeviceOnboardingRepository {
  DeviceOnboardingRepository({required this.dio});

  final Dio dio;

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
    // Detached from backend: Return mock success after 500ms delay
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}

class DeviceOnboardingException implements Exception {
  const DeviceOnboardingException(this.message);

  final String message;

  @override
  String toString() => 'DeviceOnboardingException: $message';
}
