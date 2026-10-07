class AppEndpoints {
  // Auth
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String refresh = '/auth/refresh';
  static const String verifyPin = '/auth/verify-pin';
  static const String setPin = '/auth/set-pin';

  // Developer Dashboard & Features
  static const String developerDashboard = '/developer/dashboard';
  static const String developerTransactions = '/developer/transactions';
  static const String developerPayouts = '/developer/payouts';
  static String developerConfirmPayout(int id) => '/developer/payouts/$id/confirm';
  static String developerRejectPayout(int id) => '/developer/payouts/$id/reject';
  static const String developerAnalytics = '/developer/analytics';
  static const String developerNotifications = '/developer/notifications';
}
