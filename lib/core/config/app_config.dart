class AppConfig {
  static const String appName = 'F Loafinwatch';

  // Environment configuration via dart-define or defaults
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://loa.jurnalcib.com/api/v1',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
