import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/db/app_database.dart';
import '../../sync/data/sync_status.dart';
import 'weight_row.dart';

/// The server's answer for one weighing: Sent with its final entry number, or Rejected with the reason.
typedef WeightSyncResult = ({String id, SyncStatus status, int? entrySequence, String? reason});

/// Weighings saved on the phone, waiting to be sent or already sent.
class WeightStore {
  WeightStore(this._db);

  final Future<Database> _db;

  Future<void> save(WeightRow row) async {
    await (await _db).insert('weight_rows', row.toRow(), conflictAlgorithm: ConflictAlgorithm.abort);
  }

  /// The user's weighings for the date, newest first.
  Future<List<WeightRow>> forDate(String username, String date) async {
    final rows = await (await _db).query('weight_rows',
        where: 'recorded_by = ? AND weigh_date = ?', whereArgs: [username, date], orderBy: 'rowid DESC');
    return rows.map(WeightRow.fromRow).toList();
  }

  /// Earlier days' weighings that are not Sent yet; they are accepted when sent later (10.5).
  Future<List<WeightRow>> unsentBefore(String username, String date) async {
    final rows = await (await _db).query('weight_rows',
        where: 'recorded_by = ? AND weigh_date < ? AND sync_status <> ?',
        whereArgs: [username, date, SyncStatus.sent.code],
        orderBy: 'rowid DESC');
    return rows.map(WeightRow.fromRow).toList();
  }

  /// The user's weighings waiting to be sent, in recorded order.
  Future<List<WeightRow>> waiting(String username) async {
    final rows = await (await _db).query('weight_rows',
        where: 'recorded_by = ? AND sync_status = ?', whereArgs: [username, SyncStatus.waiting.code], orderBy: 'rowid');
    return rows.map(WeightRow.fromRow).toList();
  }

  /// Every weighing on this phone for the date that is not Rejected, by anyone, for the entry
  /// counts and numbers (WE-04, WE-10).
  Future<List<WeightRow>> notRejectedOn(String date) async {
    final rows = await (await _db).query('weight_rows',
        where: 'weigh_date = ? AND sync_status <> ?', whereArgs: [date, SyncStatus.rejected.code]);
    return rows.map(WeightRow.fromRow).toList();
  }

  /// Stores the server's answer per record; a Sent row takes the server's entry number. Only
  /// Waiting rows change, so a late reply can't overwrite a newer one.
  Future<void> applyResults(List<WeightSyncResult> results) async {
    final db = await _db;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final r in results) {
        batch.update(
          'weight_rows',
          {
            'sync_status': r.status.code,
            'reason': r.status == SyncStatus.rejected ? r.reason : null,
            if (r.entrySequence != null) 'final_sequence': r.entrySequence,
          },
          where: 'weight_id = ? AND sync_status = ?',
          whereArgs: [r.id, SyncStatus.waiting.code],
        );
      }
      await batch.commit(noResult: true);
    });
  }
}

final weightStoreProvider = Provider<WeightStore>((ref) => WeightStore(ref.watch(appDatabaseProvider.future)));
