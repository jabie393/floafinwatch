class AppConfig {
  static const String appName = 'F Loafinwatch';

  // Environment configuration via dart-define or defaults
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://loa.jurnalcib.com/api/v1',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // Laravel Reverb WebSockets
  static const String reverbAppKey = String.fromEnvironment(
    'REVERB_APP_KEY',
    defaultValue: 'njyvauejgw7ilrwbenrw',
  );

  static const int reverbPort = int.fromEnvironment(
    'REVERB_PORT',
    defaultValue: 8080,
  );

  static const String reverbScheme = String.fromEnvironment(
    'REVERB_SCHEME',
    defaultValue: 'http',
  );

  static String get resolvedReverbHost {
    const configured = String.fromEnvironment('REVERB_HOST', defaultValue: '');
    if (configured.isNotEmpty) return configured;

    final uri = Uri.tryParse(baseUrl);
    if (uri != null && uri.host.isNotEmpty) {
      return uri.host;
    }
    return '127.0.0.1';
  }
}
