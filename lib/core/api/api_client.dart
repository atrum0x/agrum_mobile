import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config.dart';
import 'token_store.dart';

const _authPath = '/api/auth/';

/// Sends the Bearer token, and on a 401 refreshes it once and retries (the refresh token
/// rotates every time). If the refresh fails the session is over: [onSessionExpired].
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({required this.tokens, required this.refreshDio, required this.onSessionExpired});

  final TokenStore tokens;

  /// A Dio without this interceptor, for the refresh call and the retry.
  final Dio refreshDio;
  final VoidCallback onSessionExpired;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!options.path.startsWith(_authPath) || options.path.endsWith('/me/mobile')) {
      final token = await tokens.accessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    final isAuthCall = request.path.startsWith(_authPath) && !request.path.endsWith('/me/mobile');
    if (err.response?.statusCode != 401 || isAuthCall || request.extra['retried'] == true) {
      return handler.next(err);
    }

    final username = await tokens.username();
    final refreshToken = await tokens.refreshToken();
    if (username == null || refreshToken == null) {
      onSessionExpired();
      return handler.next(err);
    }

    try {
      final response = await refreshDio.post<Map<String, dynamic>>(
        '/api/auth/refresh/mobile',
        data: {'username': username, 'refreshToken': refreshToken},
      );
      final body = response.data!;
      await tokens.save(
        username: username,
        accessToken: body['accessToken'] as String,
        refreshToken: body['refreshToken'] as String,
      );
      request.headers['Authorization'] = 'Bearer ${body['accessToken']}';
      request.extra['retried'] = true;
      handler.resolve(await refreshDio.fetch<dynamic>(request));
    } on DioException catch (refreshError) {
      // A rejected refresh means the session is over; a network error is just offline
      if (refreshError.response != null) onSessionExpired();
      handler.next(err);
    }
  }
}

Dio _baseDio() => Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
    ));

/// The auth controller sets [listener] so a failed refresh logs the user out.
class SessionExpiry {
  VoidCallback? listener;

  void fire() => listener?.call();
}

final sessionExpiryProvider = Provider<SessionExpiry>((ref) => SessionExpiry());

final dioProvider = Provider<Dio>((ref) {
  final dio = _baseDio();
  final expiry = ref.watch(sessionExpiryProvider);
  dio.interceptors.add(AuthInterceptor(
    tokens: ref.watch(tokenStoreProvider),
    refreshDio: _baseDio(),
    onSessionExpired: expiry.fire,
  ));
  return dio;
});
