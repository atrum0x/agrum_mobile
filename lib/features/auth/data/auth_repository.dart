import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/token_store.dart';
import '../../../core/connectivity.dart';
import '../../../core/storage/key_value_store.dart';
import 'auth_api.dart';
import 'offline_credential.dart';
import 'user_profile.dart';

/// FSD 2.1 messages that the phone itself shows.
class LoginMessages {
  const LoginMessages._();

  static const enterUsername = 'Please enter your username.'; // LG-01
  static const enterPassword = 'Please enter your password.'; // LG-02
  static const incorrect = 'Username or password is incorrect.'; // LG-03
  static const noAccess = 'You do not have access to this application. Please contact the administrator.'; // LG-05
  static const sessionExpired = 'Your session has expired. Please log in again.'; // LG-06
  static const connectToLogIn = 'Please connect to the internet to log in.'; // LG-07
  static const forgotPassword = 'Contact administrator to change password.';
}

class LoginException implements Exception {
  const LoginException(this.message);

  final String message;

  @override
  String toString() => message;
}

class Session {
  const Session({required this.profile, required this.offline});

  final UserProfile profile;

  /// Logged in without the server (LG-07); there may be no valid token yet.
  final bool offline;
}

typedef CredentialFactory = Future<OfflineCredential> Function(String username, String password, DateTime now);
typedef CredentialCheck = Future<bool> Function(OfflineCredential credential, String password);

// PBKDF2 takes a moment on a phone, so keep it off the UI thread
Future<OfflineCredential> _createInBackground(String username, String password, DateTime now) =>
    Isolate.run(() => OfflineCredential.create(username, password, now));

Future<bool> _checkInBackground(OfflineCredential credential, String password) =>
    Isolate.run(() => credential.matches(password));

class AuthRepository {
  AuthRepository({
    required this._api,
    required this._tokens,
    required this._store,
    required this._isOnline,
    DateTime Function()? clock,
    CredentialFactory? createCredential,
    CredentialCheck? checkCredential,
    this._offlineLoginPeriod = AppConfig.offlineLoginPeriod,
  })  : _clock = clock ?? DateTime.now,
        _createCredential = createCredential ?? _createInBackground,
        _checkCredential = checkCredential ?? _checkInBackground;

  final AuthApi _api;
  final TokenStore _tokens;
  final KeyValueStore _store;
  final Future<bool> Function() _isOnline;
  final DateTime Function() _clock;
  final CredentialFactory _createCredential;
  final CredentialCheck _checkCredential;
  final Duration _offlineLoginPeriod;

  static const _profileKey = 'profile';
  static const _credentialKey = 'offline_credential';
  static const _sessionModeKey = 'session_mode';
  static const _lastActivityKey = 'last_activity_at';

  /// Online when the server can be reached, otherwise an offline login (LG-07).
  Future<Session> login(String username, String password) async {
    final user = username.trim();
    if (user.isEmpty) throw const LoginException(LoginMessages.enterUsername);
    if (password.isEmpty) throw const LoginException(LoginMessages.enterPassword);

    if (await _isOnline()) {
      try {
        return await _loginOnline(user, password);
      } on ApiException catch (e) {
        if (!e.isNetwork) throw LoginException(e.message);
        // The phone has a network but the server can't be reached: same as offline
      }
    }
    return _loginOffline(user, password);
  }

  Future<Session> _loginOnline(String username, String password) async {
    final tokens = await _api.login(username, password); // server checks LG-03, LG-04, LG-05
    await _tokens.save(username: username, accessToken: tokens.accessToken, refreshToken: tokens.refreshToken);

    final UserProfile profile;
    try {
      profile = await _api.me();
    } catch (_) {
      await _tokens.clear();
      rethrow;
    }

    // LG-05: the phone's windows are Attendance and Enter Weight
    if (!profile.hasMobileAccess) {
      await _revokeQuietly(profile.username);
      throw const LoginException(LoginMessages.noAccess);
    }

    final credential = await _createCredential(profile.username, password, _clock());
    await _store.write(_profileKey, jsonEncode(profile.toJson()));
    await _store.write(_credentialKey, jsonEncode(credential.toJson()));
    await _startSession(offline: false);
    return Session(profile: profile, offline: false);
  }

  Future<Session> _loginOffline(String username, String password) async {
    final credential = await _readCredential();
    final profile = await _readProfile();
    // LG-07: only for the user who last logged in online on this phone, within CL-04
    if (credential == null ||
        profile == null ||
        !credential.isFor(username) ||
        !credential.isWithin(_offlineLoginPeriod, _clock())) {
      throw const LoginException(LoginMessages.connectToLogIn);
    }
    if (!await _checkCredential(credential, password)) {
      throw const LoginException(LoginMessages.incorrect); // LG-03
    }
    // Tokens left from another user must not be used for this one
    final tokenUser = await _tokens.username();
    if (tokenUser != null && tokenUser.toLowerCase() != profile.username.toLowerCase()) {
      await _tokens.clear();
    }
    await _startSession(offline: true);
    return Session(profile: profile, offline: true);
  }

  /// Turns an offline session into an online one once the server can be reached, with the password
  /// typed at the offline login. Returns null while the server can't be reached; throws
  /// [LoginException] when the server refuses (LG-03 password changed, LG-04, LG-05).
  Future<Session?> goOnline(String username, String password) async {
    try {
      return await _loginOnline(username, password);
    } on ApiException catch (e) {
      if (e.isNetwork) return null;
      throw LoginException(e.message);
    }
  }

  /// Reconnects an offline session with the refresh token kept from this user's last online session
  /// on this phone (an idle timeout keeps it; Logout does not). Works after the app was closed, and
  /// needs no password. Null when there is no usable token or the server can't be reached.
  Future<Session?> resumeWithRefreshToken(String username) async {
    final tokenUser = await _tokens.username();
    final refreshToken = await _tokens.refreshToken();
    if (tokenUser == null || refreshToken == null || tokenUser.toLowerCase() != username.toLowerCase()) {
      return null;
    }
    try {
      final tokens = await _api.refresh(tokenUser, refreshToken);
      await _tokens.save(username: tokenUser, accessToken: tokens.accessToken, refreshToken: tokens.refreshToken);
    } on ApiException catch (e) {
      if (e.isNetwork) return null;
      // Expired, revoked (a password change or Logout elsewhere ends every session) or refused:
      // the token is of no use any more
      await _tokens.clear();
      return null;
    }

    final UserProfile profile;
    try {
      profile = await _api.me();
    } on ApiException catch (e) {
      if (e.isNetwork) return null;
      await _tokens.clear();
      return null;
    }
    // LG-05: the phone's windows are Attendance and Enter Weight
    if (!profile.hasMobileAccess) {
      await _revokeQuietly(profile.username);
      throw const LoginException(LoginMessages.noAccess);
    }
    await _store.write(_profileKey, jsonEncode(profile.toJson()));
    await _startSession(offline: false);
    return Session(profile: profile, offline: false);
  }

  /// Resumes the session after the app was closed, unless it has been idle too long (LG-06).
  Future<Session?> restore(Duration timeout) async {
    final mode = await _store.read(_sessionModeKey);
    final profile = await _readProfile();
    final lastActivity = DateTime.tryParse(await _store.read(_lastActivityKey) ?? '');
    if (mode == null || profile == null) return null;
    if (lastActivity == null || _clock().toUtc().difference(lastActivity) >= timeout) {
      await expire(keepRefreshToken: true);
      return null;
    }
    final offline = mode == 'offline';
    if (!offline && await _tokens.accessToken() == null) {
      await expire();
      return null;
    }
    await recordActivity();
    return Session(profile: profile, offline: offline);
  }

  Future<void> recordActivity() => _store.write(_lastActivityKey, _clock().toUtc().toIso8601String());

  /// LG-06. Records saved on the phone are kept and sent after the next login. After inactivity
  /// ([keepRefreshToken]) the refresh token stays, so the same user can reconnect after logging in
  /// again offline; when the server refused the session it is dropped.
  Future<void> expire({bool keepRefreshToken = false}) async {
    await _store.delete(_sessionModeKey);
    if (keepRefreshToken) {
      await _tokens.clearAccessToken();
    } else {
      await _tokens.clear();
    }
  }

  /// Keeps the offline credential, the cached profile and every unsent record.
  Future<void> logout() async {
    final username = await _tokens.username();
    if (username != null && await _isOnline()) {
      await _revokeQuietly(username);
    } else {
      await _tokens.clear();
    }
    await _store.delete(_sessionModeKey);
  }

  Future<void> _revokeQuietly(String username) async {
    try {
      final refreshToken = await _tokens.refreshToken();
      if (refreshToken != null) await _api.logout(username, refreshToken);
    } catch (_) {
      // Logging out must work offline; the refresh token then just expires on the server
    }
    await _tokens.clear();
  }

  Future<void> _startSession({required bool offline}) async {
    await _store.write(_sessionModeKey, offline ? 'offline' : 'online');
    await recordActivity();
  }

  Future<UserProfile?> _readProfile() async {
    final raw = await _store.read(_profileKey);
    return raw == null ? null : UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<OfflineCredential?> _readCredential() async {
    final raw = await _store.read(_credentialKey);
    return raw == null ? null : OfflineCredential.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(
      api: ref.watch(authApiProvider),
      tokens: ref.watch(tokenStoreProvider),
      store: ref.watch(keyValueStoreProvider),
      isOnline: ref.watch(checkOnlineProvider),
    ));
