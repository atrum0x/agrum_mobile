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
