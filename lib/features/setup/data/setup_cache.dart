import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/db/app_database.dart';
import 'setup_data.dart';

/// When the cache was last downloaded, for whom, and the server clock at that moment.
class CacheInfo {
  const CacheInfo({
    required this.username,
    required this.refreshedAt,
    required this.serverToday,
    required this.serverOffset,
    this.defaultEstateId,
  });

  final String username;
  final DateTime refreshedAt;

  /// The server's date at the last refresh, yyyy-MM-dd.
  final String serverToday;

  /// Server clock minus phone clock, so "today" can be checked offline (D-10, AT-11).
  final Duration serverOffset;
  final String? defaultEstateId;

  /// The phone's clock corrected to the server's.
  DateTime serverNow(DateTime phoneNow) => phoneNow.add(serverOffset);
}

/// FSD 5.4: the data the phone keeps, replaced as a whole on each refresh.
class SetupCache {
  SetupCache(this._db);

  final Future<Database> _db;

  static const _username = 'cache_username';
  static const _refreshedAt = 'cache_refreshed_at';
  static const _serverToday = 'server_today';
  static const _serverOffsetMs = 'server_offset_ms';
  static const _defaultEstateId = 'default_estate_id';

  Future<void> save(SetupData data, {required String username, required DateTime receivedAt}) async {
    final db = await _db;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final table in const [
        'cache_estates',
        'cache_work_types',
        'cache_collection_points',
        'cache_workers',
        'cache_weighable',
      ]) {
        batch.delete(table);
      }
      for (final e in data.estates) {
        batch.insert('cache_estates', e.toRow());
      }
      for (final wt in data.workTypes) {
        batch.insert('cache_work_types', wt.toRow());
      }
      for (final cp in data.collectionPoints) {
        batch.insert('cache_collection_points', cp.toRow());
      }
      for (final w in data.workers) {
        batch.insert('cache_workers', w.toRow());
      }
      for (final w in data.weighableToday) {
        batch.insert('cache_weighable', w.toRow());
      }
      void meta(String key, String? value) => value == null
          ? batch.delete('meta', where: 'key = ?', whereArgs: [key])
          : batch.insert('meta', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
      meta(_username, username);
      meta(_refreshedAt, receivedAt.toUtc().toIso8601String());
      meta(_serverToday, data.today);
      meta(_serverOffsetMs, data.serverTime.difference(receivedAt).inMilliseconds.toString());
      meta(_defaultEstateId, data.defaultEstateId);
      await batch.commit(noResult: true);
    });
  }

  /// Null until the first successful download.
  Future<CacheInfo?> info() async {
    final rows = await (await _db).query('meta');
    final values = {for (final r in rows) r['key'] as String: r['value'] as String};
    final refreshedAt = DateTime.tryParse(values[_refreshedAt] ?? '');
    final username = values[_username];
    if (refreshedAt == null || username == null) return null;
    return CacheInfo(
      username: username,
      refreshedAt: refreshedAt,
      serverToday: values[_serverToday] ?? '',
      serverOffset: Duration(milliseconds: int.tryParse(values[_serverOffsetMs] ?? '') ?? 0),
      defaultEstateId: values[_defaultEstateId],
    );
  }

  Future<List<CachedEstate>> estates() async {
    final rows = await (await _db).query('cache_estates', orderBy: 'id');
    return rows.map(CachedEstate.fromRow).toList();
  }

  Future<List<CachedWorkType>> workTypes(String estateId) async {
    final rows = await (await _db)
        .query('cache_work_types', where: 'estate_id = ?', whereArgs: [estateId], orderBy: 'work_type');
    return rows.map(CachedWorkType.fromRow).toList();
  }

  /// The site's default collection point first.
  Future<List<CachedCollectionPoint>> collectionPoints(String estateId) async {
    final rows = await (await _db).query('cache_collection_points',
        where: 'estate_id = ?', whereArgs: [estateId], orderBy: 'is_default DESC, cp_code');
    return rows.map(CachedCollectionPoint.fromRow).toList();
  }

  /// Workers from all sites; those already marked today are left out unless asked for.
  Future<List<CachedWorker>> workers({bool includeAttended = false}) async {
    final rows = await (await _db).query('cache_workers',
        where: includeAttended ? null : 'attended_today = 0', orderBy: 'employee_code');
    return rows.map(CachedWorker.fromRow).toList();
  }

  /// Today's weighable attendance as the server knew it; check [CacheInfo.serverToday] before use.
  Future<List<CachedWeighable>> weighable() async {
    final rows = await (await _db).query('cache_weighable', orderBy: 'employee_code');
    return rows.map(CachedWeighable.fromRow).toList();
  }

  /// Work types of every cached site.
  Future<List<CachedWorkType>> allWorkTypes() async {
    final rows = await (await _db).query('cache_work_types');
    return rows.map(CachedWorkType.fromRow).toList();
  }

  /// Collection points of every cached site.
  Future<List<CachedCollectionPoint>> allCollectionPoints() async {
    final rows = await (await _db).query('cache_collection_points');
    return rows.map(CachedCollectionPoint.fromRow).toList();
  }
}

final setupCacheProvider = Provider<SetupCache>((ref) => SetupCache(ref.watch(appDatabaseProvider.future)));
