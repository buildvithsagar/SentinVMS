class AppConstants {
  AppConstants._();

  // Target Gateway URLs (Phase 1 Baseline)
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.staging.vms.serviceprovider.com/api/v5',
  );

  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'https://api.staging.vms.serviceprovider.com',
  );

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Secure Storage Keys
  static const String refreshTokenKey = 'vms_refresh_token';
}
