import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../attendance/data/attendance_store.dart';
import '../../attendance/data/attendance_sync_api.dart';
import 'sync_status.dart';

/// What one run did. [error] is set when it stopped early; the unsent rows stay Waiting.
class SyncOutcome {
  const SyncOutcome({this.sent = 0, this.rejected = 0, this.error, this.networkError = false});

  final int sent;
  final int rejected;
  final String? error;

  /// The server could not be reached.
  final bool networkError;

  bool get ok => error == null;
}

/// FSD 10.5: sends the user's Waiting records, attendance first, then weighings, each in recorded
/// order. Every record gets its own Sent / Rejected answer; a failed call leaves rows Waiting.
class SyncEngine {
  SyncEngine({required this.attendance, required this.attendanceApi, this.batchSize = 100});

  final AttendanceStore attendance;
  final AttendanceSyncApi attendanceApi;
  final int batchSize;

  /// [onProgress] gets what is being sent and how far it got, for the status line.
  Future<SyncOutcome> run(String username, {void Function(String what, int done, int total)? onProgress}) async {
    var sent = 0;
    var rejected = 0;
    // Rows saved while this run is going are sent too; rows the server didn't answer are not
    // sent again in the same run.
    final attempted = <String>{};
    try {
      while (true) {
        final rows = (await attendance.waiting(username)).where((r) => !attempted.contains(r.attendanceId)).toList();
        if (rows.isEmpty) break;
        for (var from = 0; from < rows.length; from += batchSize) {
          final chunk = rows.sublist(from, (from + batchSize).clamp(0, rows.length));
          onProgress?.call('attendance', from + chunk.length, rows.length);
          attempted.addAll(chunk.map((r) => r.attendanceId));
          final results = await attendanceApi.send(chunk);
          await attendance.applyResults(results);
          sent += results.where((r) => r.status == SyncStatus.sent).length;
          rejected += results.where((r) => r.status == SyncStatus.rejected).length;
        }
      }
      // Weighings (2.7) are sent here, after all attendance, once the weighing screen exists
    } on ApiException catch (e) {
      return SyncOutcome(sent: sent, rejected: rejected, error: e.message, networkError: e.isNetwork);
    }
    return SyncOutcome(sent: sent, rejected: rejected);
  }
}

final syncEngineProvider = Provider<SyncEngine>((ref) => SyncEngine(
      attendance: ref.watch(attendanceStoreProvider),
      attendanceApi: ref.watch(attendanceSyncApiProvider),
    ));
