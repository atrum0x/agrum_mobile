/// Build-time settings, passed with --dart-define.
class AppConfig {
  const AppConfig._();

  /// The Android emulator reaches the PC's localhost as 10.0.2.2; agrum_be runs on 8080.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// CL-04 (open): how long after the last online login an offline login is allowed.
  static const offlineLoginDays = int.fromEnvironment('OFFLINE_LOGIN_DAYS', defaultValue: 3);

  /// CL-07 (open): the session ends after this much inactivity (LG-06).
  static const sessionTimeoutMinutes = int.fromEnvironment('SESSION_TIMEOUT_MINUTES', defaultValue: 30);

  static const offlineLoginPeriod = Duration(days: offlineLoginDays);
  static const sessionTimeout = Duration(minutes: sessionTimeoutMinutes);
}
