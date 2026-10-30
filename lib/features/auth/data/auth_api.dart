import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import 'user_profile.dart';

typedef LoginTokens = ({String accessToken, String refreshToken});

/// The /mobile auth endpoints: tokens travel in JSON bodies, never cookies.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<LoginTokens> login(String username, String password) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/login/mobile',
        data: {'username': username, 'password': password},
      );
      final body = response.data!;
      return (accessToken: body['accessToken'] as String, refreshToken: body['refreshToken'] as String);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// A new token pair for this phone's session; the refresh token rotates every time.
  Future<LoginTokens> refresh(String username, String refreshToken) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/refresh/mobile',
        data: {'username': username, 'refreshToken': refreshToken},
      );
      final body = response.data!;
      return (accessToken: body['accessToken'] as String, refreshToken: body['refreshToken'] as String);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// Sets up fingerprint login on this phone; the password proves it is the user. Returns the key id.
  Future<String> registerFingerprint(String username, String password, String publicKey) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/biometric/register/mobile',
        data: {'username': username, 'password': password, 'publicKey': publicKey},
      );
      return response.data!['keyId'] as String;
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// A one-time challenge (2 minutes) for the fingerprint key to sign.
  Future<String> fingerprintChallenge(String keyId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/biometric/challenge/mobile',
        data: {'keyId': keyId},
      );
      return response.data!['challenge'] as String;
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<LoginTokens> loginWithFingerprint(String keyId, String signature) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/login/biometric/mobile',
        data: {'keyId': keyId, 'signature': signature},
      );
      final body = response.data!;
      return (accessToken: body['accessToken'] as String, refreshToken: body['refreshToken'] as String);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<void> removeFingerprint(String keyId) async {
    try {
      await _dio.post<void>('/api/auth/biometric/remove/mobile', data: {'keyId': keyId});
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<UserProfile> me() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/auth/me/mobile');
      return UserProfile.fromJson(response.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// Ends this phone's session only; the user's web session and other phones stay logged in.
  Future<void> logout(String username, String refreshToken) async {
    try {
      await _dio.post<void>('/api/auth/logout/mobile', data: {'username': username, 'refreshToken': refreshToken});
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(dioProvider)));
