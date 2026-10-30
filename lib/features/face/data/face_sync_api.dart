import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../sync/data/sync_status.dart';
import 'face_store.dart';
import 'face_template_row.dart';

/// GET /api/face-templates and POST /api/face-templates/sync.
class FaceSyncApi {
  FaceSyncApi(this._dio);

  final Dio _dio;

  /// Registered faces of active workers, from every phone.
  Future<List<FaceTemplateRow>> fetch() async {
    try {
      final response = await _dio.get<List<dynamic>>('/api/face-templates');
      return [
        for (final item in response.data!.cast<Map<String, dynamic>>()) ?FaceTemplateRow.fromServer(item),
      ];
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// Each face is Sent or Rejected on its own.
  Future<List<FaceSyncResult>> send(List<FaceTemplateRow> rows) async {
    try {
      final response = await _dio.post<List<dynamic>>('/api/face-templates/sync', data: {
        'records': [for (final r in rows) r.toJson()],
      });
      return [
        for (final item in response.data!.cast<Map<String, dynamic>>())
          (
            id: item['employeeCode'] as String,
            status: SyncStatus.fromCode(item['status'] as String),
            reason: item['reason'] as String?,
          ),
      ];
    } catch (e) {
      final error = ApiException.from(e);
      // A 403 may come with an empty body
      if (error.status == 403) {
        throw const ApiException('You do not have permission to register faces.', status: 403);
      }
      throw error;
    }
  }
}

final faceSyncApiProvider = Provider<FaceSyncApi>((ref) => FaceSyncApi(ref.watch(dioProvider)));
