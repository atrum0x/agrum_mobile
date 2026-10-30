import 'dart:convert';

import 'package:agrum_mobile/core/api/api_exception.dart';
import 'package:agrum_mobile/core/api/token_store.dart';
import 'package:agrum_mobile/core/storage/key_value_store.dart';
import 'package:agrum_mobile/features/auth/data/auth_api.dart';
import 'package:agrum_mobile/features/auth/data/auth_repository.dart';
import 'package:agrum_mobile/features/auth/data/fingerprint_keys.dart';
import 'package:agrum_mobile/features/auth/data/offline_credential.dart';
import 'package:agrum_mobile/features/auth/data/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthApi extends Mock implements AuthApi {}

class MemoryStore implements KeyValueStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

const supervisor = UserProfile(
  username: 'sup01',
  employeeName: 'Nimal Perera',
  superuser: false,
  permissions: {'POST:/api/attendance/sync', 'POST:/api/weights/sync'},
);

void main() {
  late MockAuthApi api;
  late MemoryStore store;
  late TokenStore tokens;
  late bool online;
  late DateTime now;
  late FakeFingerprintKeys keys;

  AuthRepository repo() => AuthRepository(
        api: api,
        tokens: tokens,
        store: store,
        isOnline: () async => online,
        fingerprint: keys,
        clock: () => now,
        // Few iterations so the tests stay fast; same algorithm
        createCredential: (u, p, at) async => OfflineCredential.create(u, p, at, iterations: 10),
        checkCredential: (c, p) async => c.matches(p),
        offlineLoginPeriod: const Duration(days: 3),
      );

  setUp(() {
    api = MockAuthApi();
    store = MemoryStore();
    tokens = TokenStore(store);
    keys = FakeFingerprintKeys();
    online = true;
    now = DateTime.utc(2026, 10, 25, 6);
    when(() => api.login(any(), any())).thenAnswer((_) async => (accessToken: 'a1', refreshToken: 'r1'));
    when(() => api.me()).thenAnswer((_) async => supervisor);
    when(() => api.logout(any(), any())).thenAnswer((_) async {});
  });

  group('field checks', () {
    test('LG-01 username must be entered', () {
      expect(repo().login('  ', 'pw'), throwsA(isA<LoginException>().having((e) => e.message, 'message', LoginMessages.enterUsername)));
    });

    test('LG-02 password must be entered', () {
      expect(repo().login('sup01', ''), throwsA(isA<LoginException>().having((e) => e.message, 'message', LoginMessages.enterPassword)));
    });
  });

  group('online login', () {
    test('TC-01 saves tokens, profile and offline credential', () async {
      final session = await repo().login(' sup01 ', 'pw');

      expect(session.offline, isFalse);
      expect(session.profile.username, 'sup01');
      expect(await tokens.accessToken(), 'a1');
      expect(await tokens.refreshToken(), 'r1');
      expect(store.values['offline_credential'], isNotNull);
      expect(store.values['offline_credential']!.contains('"pw"'), isFalse);
      verify(() => api.login('sup01', 'pw')).called(1);
    });

    test('TC-04 shows the server message for wrong details', () {
      when(() => api.login(any(), any()))
          .thenThrow(const ApiException(LoginMessages.incorrect, status: 401));
      expect(repo().login('sup01', 'bad'), throwsA(isA<LoginException>().having((e) => e.message, 'message', LoginMessages.incorrect)));
    });

    test('LG-05 a user with no phone windows is refused and logged out on the server', () async {
      when(() => api.me()).thenAnswer((_) async => const UserProfile(
          username: 'office1', employeeName: null, superuser: false, permissions: {'GET:/api/weights/history'}));

      await expectLater(repo().login('office1', 'pw'),
          throwsA(isA<LoginException>().having((e) => e.message, 'message', LoginMessages.noAccess)));
      expect(await tokens.accessToken(), isNull);
      verify(() => api.logout('office1', 'r1')).called(1);
    });

    test('falls back to offline login when the server cannot be reached', () async {
      await repo().login('sup01', 'pw');
      when(() => api.login(any(), any()))
          .thenThrow(const ApiException('Cannot reach the server.', isNetwork: true));

      final session = await repo().login('sup01', 'pw');
      expect(session.offline, isTrue);
    });
  });

  group('offline login (LG-07)', () {
    Future<void> loggedInOnlineBefore() async {
      await repo().login('sup01', 'pw');
      await repo().logout();
      online = false;
    }

    test('TC-07 allowed within the period after an online login', () async {
      await loggedInOnlineBefore();
      now = now.add(const Duration(days: 2));

      final session = await repo().login('SUP01', 'pw');
      expect(session.offline, isTrue);
      expect(session.profile.username, 'sup01');
    });

    test('refused when this phone never logged in online', () {
      online = false;
      expect(repo().login('sup01', 'pw'), throwsA(isA<LoginException>().having((e) => e.message, 'message', LoginMessages.connectToLogIn)));
    });

    test('refused after the period', () async {
      await loggedInOnlineBefore();
      now = now.add(const Duration(days: 3));
      expect(repo().login('sup01', 'pw'), throwsA(isA<LoginException>().having((e) => e.message, 'message', LoginMessages.connectToLogIn)));
    });

    test('refused for another user', () async {
      await loggedInOnlineBefore();
      expect(repo().login('sup02', 'pw'), throwsA(isA<LoginException>().having((e) => e.message, 'message', LoginMessages.connectToLogIn)));
    });

    test('wrong password gives LG-03', () async {
      await loggedInOnlineBefore();
      expect(repo().login('sup01', 'nope'), throwsA(isA<LoginException>().having((e) => e.message, 'message', LoginMessages.incorrect)));
    });
  });

  group('reconnecting with the kept refresh token', () {
    // Online login, then the session timed out (LG-06), then the same user logged in again offline
    Future<void> timedOutThenOffline() async {
      await repo().login('sup01', 'pw');
      await repo().expire(keepRefreshToken: true);
      online = false;
      await repo().login('sup01', 'pw');
      online = true;
    }

    test('an idle timeout keeps only the refresh token', () async {
      await repo().login('sup01', 'pw');
      await repo().expire(keepRefreshToken: true);

      expect(await tokens.accessToken(), isNull);
      expect(await tokens.refreshToken(), 'r1');
      expect(store.values['session_mode'], isNull);
    });

    test('a server-refused session drops the refresh token too', () async {
      await repo().login('sup01', 'pw');
      await repo().expire();

      expect(await tokens.refreshToken(), isNull);
    });

    test('gets online without the password, e.g. after the app was closed', () async {
      await timedOutThenOffline();
      when(() => api.refresh('sup01', 'r1')).thenAnswer((_) async => (accessToken: 'a2', refreshToken: 'r2'));

      final session = await repo().resumeWithRefreshToken('SUP01');

      expect(session!.offline, isFalse);
      expect(await tokens.accessToken(), 'a2');
      expect(await tokens.refreshToken(), 'r2');
      expect(store.values['session_mode'], 'online');
      // Only the first, online login of the setup; no password was needed to reconnect
      verify(() => api.login(any(), any())).called(1);
    });

    test('server still unreachable: stays offline and keeps the token', () async {
      await timedOutThenOffline();
      when(() => api.refresh(any(), any()))
          .thenThrow(const ApiException('Cannot reach the server.', isNetwork: true));

      expect(await repo().resumeWithRefreshToken('sup01'), isNull);
      expect(await tokens.refreshToken(), 'r1');
    });

    test('a refused token (expired, revoked, password changed) is dropped', () async {
      await timedOutThenOffline();
      when(() => api.refresh(any(), any())).thenThrow(const ApiException(
          'Refresh token expired, invalid, or revoked. Please log in again.', status: 401));

      expect(await repo().resumeWithRefreshToken('sup01'), isNull);
      expect(await tokens.refreshToken(), isNull);
      expect(store.values['session_mode'], 'offline');
    });

    test('LG-05: no phone windows any more ends the session', () async {
      await timedOutThenOffline();
      when(() => api.refresh(any(), any())).thenAnswer((_) async => (accessToken: 'a2', refreshToken: 'r2'));
      when(() => api.me()).thenAnswer((_) async => const UserProfile(
          username: 'sup01', employeeName: null, superuser: false, permissions: {}));

      expect(repo().resumeWithRefreshToken('sup01'),
          throwsA(isA<LoginException>().having((e) => e.message, 'message', LoginMessages.noAccess)));
    });

    test('no token after Logout, or one for another user: nothing to resume with', () async {
      await repo().login('sup01', 'pw');
      await repo().logout();
      expect(await repo().resumeWithRefreshToken('sup01'), isNull);

      await repo().login('sup01', 'pw');
      await repo().expire(keepRefreshToken: true);
      expect(await repo().resumeWithRefreshToken('sup02'), isNull);
      verifyNever(() => api.refresh(any(), any()));
    });

    test('TC-06 restore after the inactivity timeout keeps the refresh token', () async {
      await repo().login('sup01', 'pw');
      now = now.add(const Duration(minutes: 30));

      expect(await repo().restore(const Duration(minutes: 30)), isNull);
      expect(await tokens.refreshToken(), 'r1');
    });
  });

  group('offline session going online', () {
    Future<void> loggedInOffline() async {
      await repo().login('sup01', 'pw');
      await repo().logout();
      online = false;
      await repo().login('sup01', 'pw');
      online = true;
    }

    test('logs in online with the same password and gets tokens', () async {
      await loggedInOffline();
      when(() => api.login(any(), any())).thenAnswer((_) async => (accessToken: 'a2', refreshToken: 'r2'));

      final session = await repo().goOnline('sup01', 'pw');

      expect(session!.offline, isFalse);
      expect(await tokens.accessToken(), 'a2');
      expect(store.values['session_mode'], 'online');
    });

    test('server still unreachable: stays offline', () async {
      await loggedInOffline();
      when(() => api.login(any(), any()))
          .thenThrow(const ApiException('Cannot reach the server.', isNetwork: true));

      expect(await repo().goOnline('sup01', 'pw'), isNull);
      expect(await tokens.accessToken(), isNull);
      expect(store.values['session_mode'], 'offline');
    });

    test('the server refuses (password changed, LG-03/LG-04): gives its message', () async {
      await loggedInOffline();
      when(() => api.login(any(), any())).thenThrow(const ApiException(LoginMessages.incorrect, status: 401));

      expect(repo().goOnline('sup01', 'pw'),
          throwsA(isA<LoginException>().having((e) => e.message, 'message', LoginMessages.incorrect)));
    });
  });

  group('session', () {
    test('logout keeps the offline credential and profile', () async {
      await repo().login('sup01', 'pw');
      await repo().logout();

      expect(await tokens.accessToken(), isNull);
      expect(store.values['offline_credential'], isNotNull);
      expect(store.values['profile'], isNotNull);
      verify(() => api.logout('sup01', 'r1')).called(1);
    });

    test('logout works offline', () async {
      await repo().login('sup01', 'pw');
      online = false;
      await repo().logout();

      expect(await tokens.accessToken(), isNull);
      verifyNever(() => api.logout(any(), any()));
    });

    test('restore resumes a recent session', () async {
      await repo().login('sup01', 'pw');
      now = now.add(const Duration(minutes: 10));

      final session = await repo().restore(const Duration(minutes: 30));
      expect(session?.profile.username, 'sup01');
    });

    test('TC-06 restore after the inactivity timeout ends the session (LG-06)', () async {
      await repo().login('sup01', 'pw');
      now = now.add(const Duration(minutes: 30));

      expect(await repo().restore(const Duration(minutes: 30)), isNull);
      expect(await tokens.accessToken(), isNull);
      expect(store.values['offline_credential'], isNotNull);
    });

    test('restore after logout gives nothing', () async {
      await repo().login('sup01', 'pw');
      await repo().logout();
      expect(await repo().restore(const Duration(minutes: 30)), isNull);
    });
  });

  group('fingerprint login', () {
    setUp(() {
      when(() => api.registerFingerprint(any(), any(), any())).thenAnswer((_) async => 'k1');
      when(() => api.fingerprintChallenge(any())).thenAnswer((_) async => 'c1');
      when(() => api.loginWithFingerprint(any(), any()))
          .thenAnswer((_) async => (accessToken: 'a2', refreshToken: 'r2'));
      when(() => api.removeFingerprint(any())).thenAnswer((_) async {});
    });

    Future<void> turnedOn() async {
      await repo().login('sup01', 'pw');
      await repo().enableFingerprint('sup01', 'pw');
      await repo().logout();
    }

    test('turning it on makes a Keystore key and registers it with the password', () async {
      await repo().login('sup01', 'pw');
      expect(await repo().shouldOfferFingerprint('sup01'), isTrue);

      await repo().enableFingerprint('sup01', 'pw');

      expect(keys.hasKey, isTrue);
      verify(() => api.registerFingerprint('sup01', 'pw', 'public-1')).called(1);
      expect(await repo().fingerprintLogin(), (username: 'sup01', keyId: 'k1'));
      expect(await repo().shouldOfferFingerprint('sup01'), isFalse);
    });

    test('turning it on needs the internet', () async {
      await repo().login('sup01', 'pw');
      online = false;

      await expectLater(repo().enableFingerprint('sup01', 'pw'),
          throwsA(isA<LoginException>().having((e) => e.message, 'message', LoginMessages.fingerprintNeedsInternet)));
      expect(keys.hasKey, isFalse);
    });

    test('a wrong password leaves it off and drops the new key', () async {
      await repo().login('sup01', 'pw');
      when(() => api.registerFingerprint(any(), any(), any()))
          .thenThrow(const ApiException(LoginMessages.incorrect, status: 401));

      await expectLater(repo().enableFingerprint('sup01', 'bad'),
          throwsA(isA<LoginException>().having((e) => e.message, 'message', LoginMessages.incorrect)));
      expect(keys.hasKey, isFalse);
      expect(await repo().fingerprintLogin(), isNull);
    });

    test('not offered again after "Not now", nor without a fingerprint on the phone', () async {
      await repo().login('sup01', 'pw');
      await repo().declineFingerprint('SUP01');
      expect(await repo().shouldOfferFingerprint('sup01'), isFalse);

      store.values.remove('fingerprint_declined');
      keys.isAvailable = false;
      expect(await repo().shouldOfferFingerprint('sup01'), isFalse);
    });

    test('online: the key signs the server challenge and the session starts', () async {
      await turnedOn();
      now = now.add(const Duration(days: 2));

      final session = await repo().loginWithFingerprint();

      expect(session.offline, isFalse);
      expect(session.profile.username, 'sup01');
      verify(() => api.loginWithFingerprint('k1', 'signed:agrum-login:k1:c1')).called(1);
      expect(await tokens.accessToken(), 'a2');
      expect(await tokens.refreshToken(), 'r2');
      // An online login: the offline period starts again, with the same password hash
      final credential = OfflineCredential.fromJson(jsonDecode(store.values['offline_credential']!) as Map<String, dynamic>);
      expect(credential.lastOnlineLoginAt, now);
      expect(credential.matches('pw'), isTrue);
    });

    test('closing the prompt is not an error and starts nothing', () async {
      await turnedOn();
      keys.nextFailure = FingerprintFailure.canceled;

      await expectLater(repo().loginWithFingerprint(), throwsA(isA<FingerprintCanceled>()));
      verifyNever(() => api.loginWithFingerprint(any(), any()));
      expect(await repo().fingerprintLogin(), isNotNull);
    });

    test('refused by the server (e.g. password changed): turned off, server message shown', () async {
      await turnedOn();
      const message = 'Fingerprint login is not set up on this phone. Please log in with your password.';
      when(() => api.fingerprintChallenge(any())).thenThrow(const ApiException(message, status: 401));

      await expectLater(repo().loginWithFingerprint(),
          throwsA(isA<LoginException>().having((e) => e.message, 'message', message)));
      expect(await repo().fingerprintLogin(), isNull);
      expect(keys.hasKey, isFalse);
    });

    test('fingerprints changed on the phone: turned off here and on the server', () async {
      await turnedOn();
      keys.nextFailure = FingerprintFailure.invalidated;

      await expectLater(repo().loginWithFingerprint(),
          throwsA(isA<LoginException>().having((e) => e.message, 'message', LoginMessages.fingerprintsChanged)));
      expect(await repo().fingerprintLogin(), isNull);
      verify(() => api.removeFingerprint('k1')).called(1);
    });

    test('LG-07 offline: allowed within the period, after the fingerprint', () async {
      await turnedOn();
      online = false;
      now = now.add(const Duration(days: 2));

      final session = await repo().loginWithFingerprint();

      expect(session.offline, isTrue);
      expect(keys.signed.single, startsWith('agrum-offline:'));
      verifyNever(() => api.fingerprintChallenge(any()));
    });

    test('LG-07 offline: refused after the period, without asking for the fingerprint', () async {
      await turnedOn();
      online = false;
      now = now.add(const Duration(days: 3));

      await expectLater(repo().loginWithFingerprint(),
          throwsA(isA<LoginException>().having((e) => e.message, 'message', LoginMessages.connectToLogIn)));
      expect(keys.signed, isEmpty);
    });

    test('server unreachable: falls back to the offline rules', () async {
      await turnedOn();
      when(() => api.fingerprintChallenge(any()))
          .thenThrow(const ApiException('Cannot reach the server.', isNetwork: true));

      final session = await repo().loginWithFingerprint();
      expect(session.offline, isTrue);
    });

    test('Logout keeps it on', () async {
      await turnedOn();
      expect(await repo().fingerprintLogin(), isNotNull);
      expect(keys.hasKey, isTrue);
    });

    test('another user logging in with a password turns it off', () async {
      await turnedOn();
      when(() => api.me()).thenAnswer((_) async => const UserProfile(
          username: 'sup02', employeeName: null, superuser: false, permissions: {'POST:/api/attendance/sync'}));

      await repo().login('sup02', 'pw2');

      expect(await repo().fingerprintLogin(), isNull);
      expect(keys.hasKey, isFalse);
      verify(() => api.removeFingerprint('k1')).called(1);
    });
  });
}

/// Stands in for the Android Keystore: "signs" by prefixing the text.
class FakeFingerprintKeys implements FingerprintKeys {
  bool isAvailable = true;
  bool hasKey = false;
  int created = 0;
  FingerprintFailure? nextFailure;
  final signed = <String>[];

  void _check() {
    final failure = nextFailure;
    nextFailure = null;
    if (failure != null) throw FingerprintException(failure);
  }

  @override
  Future<bool> available() async => isAvailable;

  @override
  Future<String> createKey() async {
    _check();
    hasKey = true;
    return 'public-${++created}';
  }

  @override
  Future<String> sign(String text) async {
    _check();
    if (!hasKey) throw const FingerprintException(FingerprintFailure.invalidated);
    signed.add(text);
    return 'signed:$text';
  }

  @override
  Future<void> deleteKey() async => hasKey = false;
}
