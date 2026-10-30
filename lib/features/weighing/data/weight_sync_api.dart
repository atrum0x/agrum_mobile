import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../sync/data/sync_status.dart';
import '../domain/weighing_rules.dart';
import 'weight_row.dart';
import 'weight_store.dart';

/// POST /api/weights/sync: each weighing is Sent (with its final entry number) or Rejected on its own.
/// The phone sends everything through here, online or not, so both share one path.
class WeightSyncApi {
  WeightSyncApi(this._dio);

  final Dio _dio;

  Future<List<WeightSyncResult>> send(List<WeightRow> rows) async {
    try {
      final response = await _dio.post<List<dynamic>>('/api/weights/sync', data: {
        'records': [
          for (final r in rows)
            {
              'weightId': r.weightId,
              'attendanceId': r.attendanceId,
              'employeeCode': r.employeeCode,
              'weighedAt': r.weighedAt.toUtc().toIso8601String(),
              'weightKg': r.weightKg,
              'entryType': r.entryType.code,
              'variancePercent': r.variancePercent,
              'provisionalSequence': r.provisionalSequence,
              if (r.identifiedBy != null) 'identifiedBy': r.identifiedBy!.code,
              if (r.faceSimilarity != null) 'faceSimilarity': r.faceSimilarity,
              if (r.photo != null) 'photo': base64Encode(r.photo!),
            },
        ],
      });
      return [
        for (final item in response.data!.cast<Map<String, dynamic>>())
          (
            id: item['weightId'] as String,
            status: SyncStatus.fromCode(item['status'] as String),
            entrySequence: item['entrySequence'] as int?,
            reason: item['reason'] as String?,
          ),
      ];
    } catch (e) {
      final error = ApiException.from(e);
      // A 403 may come with an empty body
      if (error.status == 403) throw ApiException(WeighingMessages.noPermission, status: 403);
      throw error;
    }
  }
}

final weightSyncApiProvider = Provider<WeightSyncApi>((ref) => WeightSyncApi(ref.watch(dioProvider)));
