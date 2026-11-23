import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// The phone's own database: the 5.4 setup cache and the records waiting to be sent.
class AppDatabase {
  const AppDatabase._();

  static const version = 6;

  static Future<Database> open({DatabaseFactory? factory, String? path}) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await dbFactory.getDatabasesPath(), 'agrum.db');
    return dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        onCreate: (db, _) async {
          await _createV1(db);
          await _upgradeToV2(db);
          await _upgradeToV3(db);
          await _upgradeToV4(db);
          await _upgradeToV5(db);
          await _upgradeToV6(db);
        },
        onUpgrade: (db, from, _) async {
          if (from < 2) await _upgradeToV2(db);
          if (from < 3) await _upgradeToV3(db);
          if (from < 4) await _upgradeToV4(db);
          if (from < 5) await _upgradeToV5(db);
          if (from < 6) await _upgradeToV6(db);
        },
      ),
    );
  }

  static Future<void> _createV1(Database db) async {
    final batch = db.batch()
      ..execute('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)')
      // 5.4 setup cache, replaced as a whole on every refresh
      ..execute('''
        CREATE TABLE cache_estates (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          variance_percent REAL NOT NULL,
          max_daily_transactions INTEGER NOT NULL,
          full_day_qty_kg REAL,
          half_day_qty_kg REAL
        )''')
      ..execute('''
        CREATE TABLE cache_work_types (
          estate_id TEXT NOT NULL,
          work_type TEXT NOT NULL,
          weighing_required INTEGER NOT NULL,
          PRIMARY KEY (estate_id, work_type)
        )''')
      ..execute('''
        CREATE TABLE cache_collection_points (
          estate_id TEXT NOT NULL,
          cp_code TEXT NOT NULL,
          name TEXT,
          is_default INTEGER NOT NULL,
          PRIMARY KEY (estate_id, cp_code)
        )''')
      ..execute('''
        CREATE TABLE cache_workers (
          employee_code TEXT PRIMARY KEY,
          full_name TEXT NOT NULL,
          default_estate_id TEXT,
          home_estate_id TEXT,
          default_cp_code TEXT,
          default_category TEXT,
          attended_today INTEGER NOT NULL
        )''')
      // Send queue (10.5): saved first as WAITING, sent in rowid order. recorded_by keeps a
      // second supervisor on the same phone from sending someone else's rows.
      ..execute('''
        CREATE TABLE attendance_rows (
          attendance_id TEXT PRIMARY KEY,
          employee_code TEXT NOT NULL,
          full_name TEXT NOT NULL,
          estate_id TEXT NOT NULL,
          work_type TEXT NOT NULL,
          cp_code TEXT NOT NULL,
          category TEXT NOT NULL,
          attendance_date TEXT NOT NULL,
          recorded_at TEXT NOT NULL,
          recorded_by TEXT NOT NULL,
          sync_status TEXT NOT NULL,
          reason TEXT
        )''')
      ..execute('''
        CREATE TABLE weight_rows (
          weight_id TEXT PRIMARY KEY,
          attendance_id TEXT NOT NULL,
          employee_code TEXT NOT NULL,
          full_name TEXT NOT NULL,
          estate_id TEXT NOT NULL,
          weighed_at TEXT NOT NULL,
          weight_kg REAL NOT NULL,
          entry_type TEXT NOT NULL,
          variance_percent REAL,
          provisional_sequence INTEGER NOT NULL,
          final_sequence INTEGER,
          recorded_by TEXT NOT NULL,
          sync_status TEXT NOT NULL,
          reason TEXT
        )''');
    await batch.commit(noResult: true);
  }

  /// The weighing screen (2.7): today's weighable attendance from the server, and the date each
  /// weighing counts for.
  static Future<void> _upgradeToV2(Database db) async {
    final batch = db.batch()
      ..execute('''
        CREATE TABLE cache_weighable (
          attendance_id TEXT PRIMARY KEY,
          employee_code TEXT NOT NULL,
          full_name TEXT NOT NULL,
          estate_id TEXT NOT NULL,
          estate_name TEXT NOT NULL,
          cp_code TEXT NOT NULL,
          cp_name TEXT,
          work_type TEXT NOT NULL,
          variance_percent REAL NOT NULL,
          entries_today INTEGER NOT NULL,
          daily_limit INTEGER NOT NULL,
          last_sequence INTEGER NOT NULL
        )''')
      // = the attendance date, yyyy-MM-dd
      ..execute('ALTER TABLE weight_rows ADD COLUMN weigh_date TEXT')
      ..execute('ALTER TABLE weight_rows ADD COLUMN cp_code TEXT')
      ..execute('ALTER TABLE weight_rows ADD COLUMN work_type TEXT');
    await batch.commit(noResult: true);
  }

  /// Registered faces for the weighing screen: downloaded from the server (SENT) or registered on
  /// this phone and waiting to be sent. One per worker; registering again replaces it.
  static Future<void> _upgradeToV3(Database db) async {
    await db.execute('''
      CREATE TABLE face_templates (
        employee_code TEXT PRIMARY KEY,
        embedding BLOB NOT NULL,
        sample_count INTEGER NOT NULL,
        registered_at TEXT NOT NULL,
        registered_by TEXT NOT NULL,
        sync_status TEXT NOT NULL,
        reason TEXT
      )''');
  }

  /// Face photos and how the worker was picked. A photo is kept only until the server has it.
  static Future<void> _upgradeToV4(Database db) async {
    final batch = db.batch()
      // FACE or SEARCH; null for weighings saved before this
      ..execute('ALTER TABLE weight_rows ADD COLUMN identified_by TEXT')
      ..execute('ALTER TABLE weight_rows ADD COLUMN face_similarity REAL')
      ..execute('ALTER TABLE weight_rows ADD COLUMN photo BLOB')
      ..execute('ALTER TABLE face_templates ADD COLUMN photo BLOB');
    await batch.commit(noResult: true);
  }

  /// When a row was answered Sent, compared with when the site data was downloaded: an attendance
  /// the later download no longer lists was deleted on the web, and a weighing sent after the
  /// download is not in its Entries Today yet. Null for rows sent before this.
  static Future<void> _upgradeToV5(Database db) async {
    final batch = db.batch()
      ..execute('ALTER TABLE attendance_rows ADD COLUMN sent_at TEXT')
      ..execute('ALTER TABLE weight_rows ADD COLUMN sent_at TEXT');
    await batch.commit(noResult: true);
  }

  /// Message on attendance that was waiting to be sent when the app moved to divisions.
  static const recordAgainReason =
      'Recorded before divisions were added. Please record this attendance again.';

  /// FSD v2.7: Site → Division → Field. Collection Point is renamed Field and work types get a
  /// Work Type ID and a name. The setup cache is rebuilt empty, so the next refresh downloads it
  /// again. Tables are rebuilt rather than altered because Android 7's SQLite can't rename or drop
  /// columns. Attendance still waiting to be sent has no division, which the server now requires
  /// (AT-19), so it is marked Rejected and stays visible for the supervisor to record again.
  static Future<void> _upgradeToV6(Database db) async {
    final batch = db.batch()
      ..execute('DROP TABLE IF EXISTS cache_work_types')
      ..execute('DROP TABLE IF EXISTS cache_collection_points')
      ..execute('DROP TABLE IF EXISTS cache_workers')
      ..execute('DROP TABLE IF EXISTS cache_weighable')
      ..execute('DROP TABLE IF EXISTS cache_estates')
      ..execute("DELETE FROM meta WHERE key = 'cache_refreshed_at'")
      ..execute('''
        CREATE TABLE cache_estates (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          variance_percent REAL NOT NULL,
          max_daily_transactions INTEGER NOT NULL,
          full_day_qty_kg REAL,
          half_day_qty_kg REAL
        )''')
      ..execute('''
        CREATE TABLE cache_work_types (
          estate_id TEXT NOT NULL,
          work_type_code TEXT NOT NULL,
          name TEXT NOT NULL,
          weighing_required INTEGER NOT NULL,
          PRIMARY KEY (estate_id, work_type_code)
        )''')
      ..execute('''
        CREATE TABLE cache_divisions (
          estate_id TEXT NOT NULL,
          division_code TEXT NOT NULL,
          description TEXT NOT NULL,
          PRIMARY KEY (estate_id, division_code)
        )''')
      ..execute('''
        CREATE TABLE cache_fields (
          estate_id TEXT NOT NULL,
          field_code TEXT NOT NULL,
          division_code TEXT NOT NULL,
          description TEXT NOT NULL,
          is_default INTEGER NOT NULL,
          PRIMARY KEY (estate_id, field_code)
        )''')
      ..execute('''
        CREATE TABLE cache_workers (
          employee_code TEXT PRIMARY KEY,
          full_name TEXT NOT NULL,
          default_estate_id TEXT,
          home_estate_id TEXT,
          default_division_code TEXT,
          default_field_code TEXT,
          default_category TEXT,
          attended_today INTEGER NOT NULL
        )''')
      ..execute('''
        CREATE TABLE cache_weighable (
          attendance_id TEXT PRIMARY KEY,
          employee_code TEXT NOT NULL,
          full_name TEXT NOT NULL,
          estate_id TEXT NOT NULL,
          estate_name TEXT NOT NULL,
          division_code TEXT NOT NULL,
          division_description TEXT,
          field_code TEXT NOT NULL,
          field_description TEXT,
          work_type TEXT NOT NULL,
          work_type_name TEXT,
          variance_percent REAL NOT NULL,
          entries_today INTEGER NOT NULL,
          daily_limit INTEGER NOT NULL,
          last_sequence INTEGER NOT NULL
        )''')
      // division_code is null only on rows saved before divisions
      ..execute('''
        CREATE TABLE attendance_rows_v6 (
          attendance_id TEXT PRIMARY KEY,
          employee_code TEXT NOT NULL,
          full_name TEXT NOT NULL,
          estate_id TEXT NOT NULL,
          work_type TEXT NOT NULL,
          division_code TEXT,
          field_code TEXT NOT NULL,
          category TEXT NOT NULL,
          attendance_date TEXT NOT NULL,
          recorded_at TEXT NOT NULL,
          recorded_by TEXT NOT NULL,
          sync_status TEXT NOT NULL,
          reason TEXT,
          sent_at TEXT
        )''')
      // rowid order is the send order, so copy in that order
      ..execute('''
        INSERT INTO attendance_rows_v6 (attendance_id, employee_code, full_name, estate_id, work_type,
            division_code, field_code, category, attendance_date, recorded_at, recorded_by, sync_status,
            reason, sent_at)
        SELECT attendance_id, employee_code, full_name, estate_id, work_type, NULL, cp_code, category,
            attendance_date, recorded_at, recorded_by, sync_status, reason, sent_at
        FROM attendance_rows ORDER BY rowid''')
      ..execute('DROP TABLE attendance_rows')
      ..execute('ALTER TABLE attendance_rows_v6 RENAME TO attendance_rows')
      ..update('attendance_rows', {'sync_status': 'REJECTED', 'reason': recordAgainReason},
          where: "sync_status = 'WAITING' AND division_code IS NULL")
      ..execute('''
        CREATE TABLE weight_rows_v6 (
          weight_id TEXT PRIMARY KEY,
          attendance_id TEXT NOT NULL,
          employee_code TEXT NOT NULL,
          full_name TEXT NOT NULL,
          estate_id TEXT NOT NULL,
          weighed_at TEXT NOT NULL,
          weight_kg REAL NOT NULL,
          entry_type TEXT NOT NULL,
          variance_percent REAL,
          provisional_sequence INTEGER NOT NULL,
          final_sequence INTEGER,
          recorded_by TEXT NOT NULL,
          sync_status TEXT NOT NULL,
          reason TEXT,
          weigh_date TEXT,
          division_code TEXT,
          field_code TEXT,
          work_type TEXT,
          identified_by TEXT,
          face_similarity REAL,
          photo BLOB,
          sent_at TEXT
        )''')
      ..execute('''
        INSERT INTO weight_rows_v6 (weight_id, attendance_id, employee_code, full_name, estate_id, weighed_at,
            weight_kg, entry_type, variance_percent, provisional_sequence, final_sequence, recorded_by,
            sync_status, reason, weigh_date, division_code, field_code, work_type, identified_by,
            face_similarity, photo, sent_at)
        SELECT weight_id, attendance_id, employee_code, full_name, estate_id, weighed_at, weight_kg,
            entry_type, variance_percent, provisional_sequence, final_sequence, recorded_by, sync_status,
            reason, weigh_date, NULL, cp_code, work_type, identified_by, face_similarity, photo, sent_at
        FROM weight_rows ORDER BY rowid''')
      ..execute('DROP TABLE weight_rows')
      ..execute('ALTER TABLE weight_rows_v6 RENAME TO weight_rows');
    await batch.commit(noResult: true);
  }
}

final appDatabaseProvider = FutureProvider<Database>((ref) => AppDatabase.open());
