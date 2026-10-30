import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/db/app_database.dart';

/// Records saved on the phone and their Sync Status (FSD 10.5).
class SendQueue {
  SendQueue(this._db);

  final Future<Database> _db;

  static const waiting = 'WAITING';

  /// Attendance, weighings and faces the user recorded that are not sent yet.
  Future<int> waitingCount(String username) async {
    final rows = await (await _db).rawQuery('''
      SELECT (SELECT COUNT(*) FROM attendance_rows WHERE recorded_by = ?1 AND sync_status = ?2)
           + (SELECT COUNT(*) FROM weight_rows WHERE recorded_by = ?1 AND sync_status = ?2)
           + (SELECT COUNT(*) FROM face_templates WHERE registered_by = ?1 AND sync_status = ?2) AS n
      ''', [username, waiting]);
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}

final sendQueueProvider = Provider<SendQueue>((ref) => SendQueue(ref.watch(appDatabaseProvider.future)));
