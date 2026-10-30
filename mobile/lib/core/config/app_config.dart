enum AppEnvironment { demo, dev, staging, prod }

class AppConfig {
  const AppConfig._({
    required this.environment,
    required this.apiBaseUrl,
    required this.wsUrl,
    required this.enableVerboseLogging,
    required this.enableDemoMode,
    required this.maxRetryAttempts,
    required this.connectTimeout,
    required this.receiveTimeout,
    required this.maxVideoDecoders,
  });

  final AppEnvironment environment;
  final String apiBaseUrl;
  final String wsUrl;
  final bool enableVerboseLogging;
  final bool enableDemoMode;
  final int maxRetryAttempts;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final int maxVideoDecoders;

  static AppConfig? _instance;
  static AppConfig get instance {
    if (_instance == null) {
      initialize();
    }
    return _instance!;
  }
  static set instance(AppConfig config) => _instance = config;

  static void initialize() {
    const envString = String.fromEnvironment('ENV', defaultValue: 'demo');
    final AppEnvironment env;
    switch (envString.toLowerCase()) {
      case 'demo':
        env = AppEnvironment.demo;
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
      case AppEnvironment.demo:
        defaultApiUrl = 'http://10.0.2.2:8000/api/v5';
        defaultWsUrl = 'http://10.0.2.2:8000';
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
    const demoModeOverride = String.fromEnvironment('ENABLE_DEMO_MODE');
    final enableDemoMode = demoModeOverride.isEmpty
        ? env == AppEnvironment.demo
        : demoModeOverride.toLowerCase() == 'true';

    instance = AppConfig._(
      environment: env,
      apiBaseUrl: _withTrailingSlash(
        apiBaseUrl.isNotEmpty ? apiBaseUrl : defaultApiUrl,
      ),
      wsUrl: wsUrl.isNotEmpty ? wsUrl : defaultWsUrl,
      enableVerboseLogging: env != AppEnvironment.prod,
      enableDemoMode: enableDemoMode,
      maxRetryAttempts: env == AppEnvironment.demo ? 0 : 1,
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 20),
      maxVideoDecoders: const int.fromEnvironment(
        'MAX_VIDEO_DECODERS',
        defaultValue: 9,
      ),
    );
  }

  static String _withTrailingSlash(String value) =>
      value.endsWith('/') ? value : '$value/';
}
