import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/token_store.dart';
import '../../../core/connectivity.dart';
import '../../../core/storage/key_value_store.dart';
import 'auth_api.dart';
import 'fingerprint_keys.dart';
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

  // Fingerprint login (not in the FSD; an addition on the phone)
  static const fingerprintFailed = 'Fingerprint login failed. Please log in with your password.';
  static const fingerprintsChanged =
      'The fingerprints on this phone have changed. Log in with your password, then turn fingerprint login on again.';
  static const fingerprintLockedOut = 'Too many fingerprint attempts. Please log in with your password.';
  static const fingerprintUnavailable = 'Set up a fingerprint in the phone settings first.';
  static const fingerprintNeedsInternet = 'Please connect to the internet to turn on fingerprint login.';
}

/// The user closed the fingerprint prompt; nothing to show.
class FingerprintCanceled implements Exception {
  const FingerprintCanceled();
}

/// Fingerprint login set up on this phone: whose it is and the server's id for the key.
typedef FingerprintLogin = ({String username, String keyId});

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
    required this._fingerprint,
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
  final FingerprintKeys _fingerprint;
  final DateTime Function() _clock;
  final CredentialFactory _createCredential;
  final CredentialCheck _checkCredential;
  final Duration _offlineLoginPeriod;

  static const _profileKey = 'profile';
  static const _credentialKey = 'offline_credential';
  static const _sessionModeKey = 'session_mode';
  static const _lastActivityKey = 'last_activity_at';
  static const _fingerprintKey = 'fingerprint_login';
  static const _fingerprintDeclinedKey = 'fingerprint_declined';

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

    // The phone now belongs to this user; another user's fingerprint must not log in to it
    final fingerprint = await fingerprintLogin();
    if (fingerprint != null && !_sameUser(fingerprint.username, profile.username)) await disableFingerprint();

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

  /// Fingerprint login on this phone, or null when it is not set up.
  Future<FingerprintLogin?> fingerprintLogin() async {
    final raw = await _store.read(_fingerprintKey);
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return (username: json['username'] as String, keyId: json['keyId'] as String);
  }

  Future<bool> fingerprintAvailable() => _fingerprint.available();

  /// Whether to offer fingerprint login to [username] after a password login: the phone has a
  /// fingerprint, it is not on yet for them, and they haven't said no.
  Future<bool> shouldOfferFingerprint(String username) async {
    final current = await fingerprintLogin();
    if (current != null && _sameUser(current.username, username)) return false;
    final declined = await _store.read(_fingerprintDeclinedKey);
    if (declined != null && _sameUser(declined, username)) return false;
    return _fingerprint.available();
  }

  Future<void> declineFingerprint(String username) => _store.write(_fingerprintDeclinedKey, username);

  /// Turns on fingerprint login for [username]: a new Keystore key (after a fingerprint check), its
  /// public key registered with the server, which checks the password again. Needs the internet.
  /// Throws [LoginException] or [FingerprintCanceled].
  Future<void> enableFingerprint(String username, String password) async {
    if (!await _isOnline()) throw const LoginException(LoginMessages.fingerprintNeedsInternet);
    final previous = await fingerprintLogin();
    final publicKey = await _guardFingerprint(_fingerprint.createKey);
    // The new key replaced the old one in the Keystore, so the old set-up can't sign any more
    if (previous != null) await _store.delete(_fingerprintKey);
    final String keyId;
    try {
      keyId = await _api.registerFingerprint(username, password, publicKey);
    } on ApiException catch (e) {
      await _fingerprint.deleteKey();
      if (previous != null) await _removeOnServerQuietly(previous.keyId);
      throw LoginException(e.isNetwork ? LoginMessages.fingerprintNeedsInternet : e.message);
    }
    if (previous != null) await _removeOnServerQuietly(previous.keyId);
    await _store.write(_fingerprintKey, jsonEncode({'username': username, 'keyId': keyId}));
    await _store.delete(_fingerprintDeclinedKey);
  }

  /// Turns fingerprint login off on this phone and, when it can, on the server.
  Future<void> disableFingerprint() async {
    final current = await fingerprintLogin();
    if (current == null) return;
    await _forgetFingerprint();
    await _removeOnServerQuietly(current.keyId);
  }

  /// Logs in with the fingerprint instead of the password. Online: the key signs the server's one-time
  /// challenge. Offline: the same rules as an offline password login (LG-07), and the key must still
  /// sign, which Android allows only right after a matching fingerprint. Throws [LoginException] or
  /// [FingerprintCanceled].
  Future<Session> loginWithFingerprint() async {
    final fingerprint = await fingerprintLogin();
    if (fingerprint == null) throw const LoginException(LoginMessages.fingerprintFailed);

    if (await _isOnline()) {
      try {
        return await _fingerprintOnline(fingerprint);
      } on ApiException catch (e) {
        if (!e.isNetwork) {
          // Refused: the key was removed (password changed, made Inactive) or the signature didn't match
          if (e.isUnauthorized) await _forgetFingerprint();
          throw LoginException(e.message);
        }
        // The phone has a network but the server can't be reached: same as offline
      }
    }
    return _fingerprintOffline(fingerprint);
  }

  Future<Session> _fingerprintOnline(FingerprintLogin fingerprint) async {
    final challenge = await _api.fingerprintChallenge(fingerprint.keyId);
    final signature = await _guardFingerprint(
      () => _fingerprint.sign('agrum-login:${fingerprint.keyId}:$challenge'),
      fingerprint: fingerprint,
    );
    final tokens = await _api.loginWithFingerprint(fingerprint.keyId, signature); // server checks LG-04, LG-05
    await _tokens.save(username: fingerprint.username, accessToken: tokens.accessToken, refreshToken: tokens.refreshToken);

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
    await _store.write(_profileKey, jsonEncode(profile.toJson()));
    // An online login, so the offline login period (CL-04) starts again; the password hash stays
    final credential = await _readCredential();
    if (credential != null && credential.isFor(profile.username)) {
      await _store.write(_credentialKey, jsonEncode(credential.renewedAt(_clock()).toJson()));
    }
    await _startSession(offline: false);
    return Session(profile: profile, offline: false);
  }

  Future<Session> _fingerprintOffline(FingerprintLogin fingerprint) async {
    final credential = await _readCredential();
    final profile = await _readProfile();
    // LG-07: only for the user who last logged in online on this phone, within CL-04
    if (credential == null ||
        profile == null ||
        !credential.isFor(fingerprint.username) ||
        !_sameUser(profile.username, fingerprint.username) ||
        !credential.isWithin(_offlineLoginPeriod, _clock())) {
      throw const LoginException(LoginMessages.connectToLogIn);
    }
    final random = Random.secure();
    final nonce = base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
    await _guardFingerprint(() => _fingerprint.sign('agrum-offline:$nonce'), fingerprint: fingerprint);

    // Tokens left from another user must not be used for this one
    final tokenUser = await _tokens.username();
    if (tokenUser != null && !_sameUser(tokenUser, profile.username)) await _tokens.clear();
    await _startSession(offline: true);
    return Session(profile: profile, offline: true);
  }

  /// Runs a Keystore call and turns its failures into what the Login screen shows. A destroyed key
  /// (the phone's fingerprints changed) also turns fingerprint login off.
  Future<T> _guardFingerprint<T>(Future<T> Function() call, {FingerprintLogin? fingerprint}) async {
    try {
      return await call();
    } on FingerprintException catch (e) {
      switch (e.failure) {
        case FingerprintFailure.canceled:
          throw const FingerprintCanceled();
        case FingerprintFailure.invalidated:
          if (fingerprint != null) {
            await _forgetFingerprint();
            await _removeOnServerQuietly(fingerprint.keyId);
          }
          throw const LoginException(LoginMessages.fingerprintsChanged);
        case FingerprintFailure.lockedOut:
          throw const LoginException(LoginMessages.fingerprintLockedOut);
        case FingerprintFailure.unavailable:
          throw const LoginException(LoginMessages.fingerprintUnavailable);
        case FingerprintFailure.failed:
          throw const LoginException(LoginMessages.fingerprintFailed);
      }
    }
  }

  Future<void> _forgetFingerprint() async {
    await _store.delete(_fingerprintKey);
    await _fingerprint.deleteKey();
  }

  Future<void> _removeOnServerQuietly(String keyId) async {
    try {
      if (await _isOnline()) await _api.removeFingerprint(keyId);
    } catch (_) {
      // Harmless if it stays: the key that could sign for it is gone from the phone
    }
  }

  static bool _sameUser(String a, String b) => a.toLowerCase() == b.toLowerCase();

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
      fingerprint: ref.watch(fingerprintKeysProvider),
    ));
