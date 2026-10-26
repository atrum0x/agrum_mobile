import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../sync/data/sync_status.dart';
import 'attendance_row.dart';

/// The server's answer for one record: Sent, or Rejected with the reason to show.
typedef SyncResult = ({String id, SyncStatus status, String? reason});

class AttendanceMessagesFromServer {
  const AttendanceMessagesFromServer._();

  static const noPermission = 'You do not have permission to record attendance.'; // AT-13
}

/// POST /api/attendance/sync: each record is Sent or Rejected on its own.
class AttendanceSyncApi {
  AttendanceSyncApi(this._dio);

  final Dio _dio;

  Future<List<SyncResult>> send(List<AttendanceRow> rows) async {
    try {
      final response = await _dio.post<List<dynamic>>('/api/attendance/sync', data: {
        'records': [
          for (final r in rows)
            {
              'attendanceId': r.attendanceId,
              'employeeCode': r.employeeCode,
              'estateId': r.estateId,
              'workType': r.workType,
              'cpCode': r.cpCode,
              'attendanceCategory': r.category.code,
              'attendanceDate': r.attendanceDate,
              'recordedAt': r.recordedAt.toUtc().toIso8601String(),
            },
        ],
      });
      return [
        for (final item in response.data!.cast<Map<String, dynamic>>())
          (
            id: item['attendanceId'] as String,
            status: SyncStatus.fromCode(item['status'] as String),
            reason: item['reason'] as String?,
          ),
      ];
    } catch (e) {
      final error = ApiException.from(e);
      // A 403 may come with an empty body
      if (error.status == 403) throw ApiException(AttendanceMessagesFromServer.noPermission, status: 403);
      throw error;
    }
  }
}

final attendanceSyncApiProvider = Provider<AttendanceSyncApi>((ref) => AttendanceSyncApi(ref.watch(dioProvider)));
