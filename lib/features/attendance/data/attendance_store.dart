import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/db/app_database.dart';
import '../../sync/data/sync_status.dart';
import 'attendance_row.dart';

/// Attendance saved on the phone, waiting to be sent or already sent.
class AttendanceStore {
  AttendanceStore(this._db);

  final Future<Database> _db;

  /// Saves a whole batch, or nothing.
  Future<void> saveBatch(List<AttendanceRow> rows) async {
    final db = await _db;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final row in rows) {
        batch.insert('attendance_rows', row.toRow(), conflictAlgorithm: ConflictAlgorithm.abort);
      }
      await batch.commit(noResult: true);
    });
  }

  /// The user's rows for the date, newest first.
  Future<List<AttendanceRow>> forDate(String username, String date) async {
    final rows = await (await _db).query('attendance_rows',
        where: 'recorded_by = ? AND attendance_date = ?', whereArgs: [username, date], orderBy: 'rowid DESC');
    return rows.map(AttendanceRow.fromRow).toList();
  }

  /// Rows from earlier days that are not Sent yet: still waiting, or rejected. Records are for the
  /// date recorded and are accepted when sent later (10.5).
  Future<List<AttendanceRow>> unsentBefore(String username, String date) async {
    final rows = await (await _db).query('attendance_rows',
        where: 'recorded_by = ? AND attendance_date < ? AND sync_status <> ?',
        whereArgs: [username, date, SyncStatus.sent.code],
        orderBy: 'rowid DESC');
    return rows.map(AttendanceRow.fromRow).toList();
  }

  /// The user's rows waiting to be sent, in recorded order.
  Future<List<AttendanceRow>> waiting(String username) async {
    final rows = await (await _db).query('attendance_rows',
        where: 'recorded_by = ? AND sync_status = ?', whereArgs: [username, SyncStatus.waiting.code], orderBy: 'rowid');
    return rows.map(AttendanceRow.fromRow).toList();
  }

  /// Stores the server's answer per record. Only Waiting rows change, so a late reply can't
  /// overwrite a newer one.
  Future<void> applyResults(List<({String id, SyncStatus status, String? reason})> results) async {
    final db = await _db;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final r in results) {
        batch.update(
          'attendance_rows',
          {'sync_status': r.status.code, 'reason': r.status == SyncStatus.rejected ? r.reason : null},
          where: 'attendance_id = ? AND sync_status = ?',
          whereArgs: [r.id, SyncStatus.waiting.code],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Workers already marked on this phone for the date by anyone, so they can't be picked again
  /// before the server knows (AT-02). A Rejected row doesn't count: the worker can be marked again.
  Future<Set<String>> markedOn(String date) async {
    final rows = await (await _db).query('attendance_rows',
        columns: ['employee_code'],
        where: 'attendance_date = ? AND sync_status <> ?',
        whereArgs: [date, SyncStatus.rejected.code]);
    return {for (final r in rows) r['employee_code'] as String};
  }
}

final attendanceStoreProvider = Provider<AttendanceStore>((ref) => AttendanceStore(ref.watch(appDatabaseProvider.future)));
