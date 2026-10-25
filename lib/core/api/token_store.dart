import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/key_value_store.dart';

/// The mobile login tokens. They come in the JSON body of /api/auth/login/mobile.
class TokenStore {
  TokenStore(this._store);

  final KeyValueStore _store;

  static const _access = 'access_token';
  static const _refresh = 'refresh_token';
  static const _username = 'token_username';

  Future<String?> accessToken() => _store.read(_access);
  Future<String?> refreshToken() => _store.read(_refresh);
  Future<String?> username() => _store.read(_username);

  Future<void> save({required String username, required String accessToken, required String refreshToken}) async {
    await _store.write(_username, username);
    await _store.write(_access, accessToken);
    await _store.write(_refresh, refreshToken);
  }

  Future<void> clear() async {
    await _store.delete(_access);
    await _store.delete(_refresh);
    await _store.delete(_username);
  }
}

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore(ref.watch(keyValueStoreProvider)));
