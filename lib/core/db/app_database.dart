import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// The phone's own database: the 5.4 setup cache and the records waiting to be sent.
class AppDatabase {
  const AppDatabase._();

  static const version = 4;

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
        },
        onUpgrade: (db, from, _) async {
          if (from < 2) await _upgradeToV2(db);
          if (from < 3) await _upgradeToV3(db);
          if (from < 4) await _upgradeToV4(db);
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
}

final appDatabaseProvider = FutureProvider<Database>((ref) => AppDatabase.open());
