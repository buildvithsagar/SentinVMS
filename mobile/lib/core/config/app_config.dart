enum AppEnvironment { dev, staging, prod }

class AppConfig {
  const AppConfig._({
    required this.environment,
    required this.apiBaseUrl,
    required this.wsUrl,
    required this.enableVerboseLogging,
    required this.maxRetryAttempts,
  });

  final AppEnvironment environment;
  final String apiBaseUrl;
  final String wsUrl;
  final bool enableVerboseLogging;
  final int maxRetryAttempts;

  static late final AppConfig instance;

  static void initialize() {
    const envString = String.fromEnvironment('ENV', defaultValue: 'prod');
    final AppEnvironment env;
    switch (envString.toLowerCase()) {
      case 'dev':
        env = AppEnvironment.dev;
      case 'staging':
        env = AppEnvironment.staging;
      case 'prod':
      default:
        env = AppEnvironment.prod;
    }

    final String defaultApiUrl;
    final String defaultWsUrl;

    switch (env) {
      case AppEnvironment.dev:
        defaultApiUrl = 'http://10.0.2.2:8000/api/v5';
        defaultWsUrl = 'http://10.0.2.2:8000';
      case AppEnvironment.staging:
        defaultApiUrl = 'https://api.staging.vms.serviceprovider.com/api/v5';
        defaultWsUrl = 'https://api.staging.vms.serviceprovider.com';
      case AppEnvironment.prod:
        defaultApiUrl = 'https://api.vms.serviceprovider.com/api/v5';
        defaultWsUrl = 'https://api.vms.serviceprovider.com';
    }

    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    const wsUrl = String.fromEnvironment('WS_URL');

    instance = AppConfig._(
      environment: env,
      apiBaseUrl: apiBaseUrl.isNotEmpty ? apiBaseUrl : defaultApiUrl,
      wsUrl: wsUrl.isNotEmpty ? wsUrl : defaultWsUrl,
      enableVerboseLogging: env != AppEnvironment.prod,
      maxRetryAttempts: 3,
    );
  }
}
