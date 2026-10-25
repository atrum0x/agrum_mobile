import 'package:agrum_mobile/core/api/api_exception.dart';
import 'package:agrum_mobile/core/api/token_store.dart';
import 'package:agrum_mobile/core/storage/key_value_store.dart';
import 'package:agrum_mobile/features/auth/data/auth_api.dart';
import 'package:agrum_mobile/features/auth/data/auth_repository.dart';
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

  AuthRepository repo() => AuthRepository(
        api: api,
        tokens: tokens,
        store: store,
        isOnline: () async => online,
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
    online = true;
    now = DateTime.utc(2026, 10, 25, 6);
    when(() => api.login(any(), any())).thenAnswer((_) async => (accessToken: 'a1', refreshToken: 'r1'));
    when(() => api.me()).thenAnswer((_) async => supervisor);
    when(() => api.logout(any())).thenAnswer((_) async {});
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
      verify(() => api.logout('office1')).called(1);
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

  group('session', () {
    test('logout keeps the offline credential and profile', () async {
      await repo().login('sup01', 'pw');
      await repo().logout();

      expect(await tokens.accessToken(), isNull);
      expect(store.values['offline_credential'], isNotNull);
      expect(store.values['profile'], isNotNull);
      verify(() => api.logout('sup01')).called(1);
    });

    test('logout works offline', () async {
      await repo().login('sup01', 'pw');
      online = false;
      await repo().logout();

      expect(await tokens.accessToken(), isNull);
      verifyNever(() => api.logout(any()));
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
}
