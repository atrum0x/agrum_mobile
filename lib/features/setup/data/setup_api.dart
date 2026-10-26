import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import 'setup_data.dart';

class SetupApi {
  SetupApi(this._dio);

  final Dio _dio;

  Future<SetupData> fetch() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/mobile/setup');
      return SetupData.fromJson(response.data!);
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}

final setupApiProvider = Provider<SetupApi>((ref) => SetupApi(ref.watch(dioProvider)));
