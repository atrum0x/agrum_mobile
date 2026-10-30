import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../attendance/data/attendance_row.dart';
import '../../attendance/data/attendance_store.dart';
import '../../attendance/data/attendance_sync_api.dart';
import '../../face/data/face_store.dart';
import '../../face/data/face_sync_api.dart';
import '../../face/data/face_template_row.dart';
import '../../weighing/data/weight_row.dart';
import '../../weighing/data/weight_store.dart';
import '../../weighing/data/weight_sync_api.dart';
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
/// order, then registered faces. Every record gets its own Sent / Rejected answer; a failed call leaves rows Waiting.
class SyncEngine {
  SyncEngine({
    required this.attendance,
    required this.attendanceApi,
    required this.weights,
    required this.weightApi,
    this.faces,
    this.faceApi,
    this.batchSize = 100,
  });

  final AttendanceStore attendance;
  final AttendanceSyncApi attendanceApi;
  final WeightStore weights;
  final WeightSyncApi weightApi;

  /// Faces are sent only when both are given.
  final FaceStore? faces;
  final FaceSyncApi? faceApi;
  final int batchSize;

  /// [onProgress] gets what is being sent and how far it got, for the status line.
  Future<SyncOutcome> run(String username, {void Function(String what, int done, int total)? onProgress}) async {
    var sent = 0;
    var rejected = 0;
    void count(List<SyncStatus> statuses) {
      sent += statuses.where((s) => s == SyncStatus.sent).length;
      rejected += statuses.where((s) => s == SyncStatus.rejected).length;
    }

    // Rows saved while this run is going are sent too; rows the server didn't answer are not
    // sent again in the same run.
    final attempted = <String>{};
    try {
      // Attendance first: a weighing refers to its attendance (2.7 step 8)
      await _sendAll<AttendanceRow>(
        what: 'attendance',
        waiting: () => attendance.waiting(username),
        id: (r) => r.attendanceId,
        send: (chunk) async {
          final results = await attendanceApi.send(chunk);
          await attendance.applyResults(results);
          return results.map((r) => r.status).toList();
        },
        attempted: attempted,
        onProgress: onProgress,
        count: count,
      );
      await _sendAll<WeightRow>(
        what: 'weighings',
        waiting: () => weights.waiting(username),
        id: (r) => r.weightId,
        send: (chunk) async {
          final results = await weightApi.send(chunk);
          await weights.applyResults(results);
          return results.map((r) => r.status).toList();
        },
        attempted: attempted,
        onProgress: onProgress,
        count: count,
      );
      if (faces case final faces?) {
        if (faceApi case final faceApi?) {
          await _sendAll<FaceTemplateRow>(
            what: 'faces',
            waiting: () => faces.waiting(username),
            // A face is replaced by registering again, so its id is the worker plus when
            id: (r) => 'face:${r.employeeCode}@${r.registeredAt.toIso8601String()}',
            send: (chunk) async {
              final results = await faceApi.send(chunk);
              await faces.applyResults(results);
              return results.map((r) => r.status).toList();
            },
            attempted: attempted,
            onProgress: onProgress,
            count: count,
          );
        }
      }
    } on ApiException catch (e) {
      return SyncOutcome(sent: sent, rejected: rejected, error: e.message, networkError: e.isNetwork);
    }
    return SyncOutcome(sent: sent, rejected: rejected);
  }

  /// Sends one kind of record in recorded order and in batches, until none is left Waiting.
  Future<void> _sendAll<T>({
    required String what,
    required Future<List<T>> Function() waiting,
    required String Function(T) id,
    required Future<List<SyncStatus>> Function(List<T>) send,
    required Set<String> attempted,
    required void Function(List<SyncStatus>) count,
    void Function(String what, int done, int total)? onProgress,
  }) async {
    while (true) {
      final rows = (await waiting()).where((r) => !attempted.contains(id(r))).toList();
      if (rows.isEmpty) return;
      for (var from = 0; from < rows.length; from += batchSize) {
        final chunk = rows.sublist(from, (from + batchSize).clamp(0, rows.length));
        onProgress?.call(what, from + chunk.length, rows.length);
        attempted.addAll(chunk.map(id));
        count(await send(chunk));
      }
    }
  }
}

final syncEngineProvider = Provider<SyncEngine>((ref) => SyncEngine(
      attendance: ref.watch(attendanceStoreProvider),
      attendanceApi: ref.watch(attendanceSyncApiProvider),
      weights: ref.watch(weightStoreProvider),
      weightApi: ref.watch(weightSyncApiProvider),
      faces: ref.watch(faceStoreProvider),
      faceApi: ref.watch(faceSyncApiProvider),
    ));
