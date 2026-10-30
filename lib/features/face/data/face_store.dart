import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/db/app_database.dart';
import '../../sync/data/sync_status.dart';
import 'face_template_row.dart';

/// The server's answer for one face: Sent, or Rejected with the reason.
typedef FaceSyncResult = ({String id, SyncStatus status, String? reason});

/// Registered faces on the phone: downloaded ones and ones registered here, waiting to be sent.
class FaceStore {
  FaceStore(this._db);

  final Future<Database> _db;

  Future<List<FaceTemplateRow>> all() async {
    final rows = await (await _db).query('face_templates', orderBy: 'employee_code');
    return rows.map(FaceTemplateRow.fromRow).toList();
  }

  /// A new registration on this phone; replaces the worker's old face.
  Future<void> save(FaceTemplateRow row) async {
    await (await _db).insert('face_templates', row.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// The user's registrations waiting to be sent, oldest first.
  Future<List<FaceTemplateRow>> waiting(String username) async {
    final rows = await (await _db).query('face_templates',
        where: 'registered_by = ? AND sync_status = ?',
        whereArgs: [username, SyncStatus.waiting.code],
        orderBy: 'registered_at');
    return rows.map(FaceTemplateRow.fromRow).toList();
  }

  Future<void> applyResults(List<FaceSyncResult> results) async {
    final db = await _db;
    final batch = db.batch();
    for (final r in results) {
      batch.update('face_templates', {'sync_status': r.status.code, 'reason': r.reason},
          where: 'employee_code = ? AND sync_status = ?', whereArgs: [r.id, SyncStatus.waiting.code]);
    }
    await batch.commit(noResult: true);
  }

  /// The server's faces replace the Sent ones; faces still waiting or rejected here are kept, so a
  /// registration not sent yet isn't lost.
  Future<void> replaceSent(List<FaceTemplateRow> server) async {
    final db = await _db;
    await db.transaction((txn) async {
      final kept = {
        for (final row in await txn.query('face_templates',
            columns: ['employee_code'], where: 'sync_status <> ?', whereArgs: [SyncStatus.sent.code]))
          row['employee_code']! as String,
      };
      await txn.delete('face_templates', where: 'sync_status = ?', whereArgs: [SyncStatus.sent.code]);
      final batch = txn.batch();
      for (final row in server) {
        if (!kept.contains(row.employeeCode)) batch.insert('face_templates', row.toRow());
      }
      await batch.commit(noResult: true);
    });
  }
}

final faceStoreProvider = Provider<FaceStore>((ref) => FaceStore(ref.watch(appDatabaseProvider.future)));
