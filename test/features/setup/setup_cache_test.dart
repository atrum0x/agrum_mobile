import 'dart:io';

import 'package:agrum_mobile/core/db/app_database.dart';
import 'package:agrum_mobile/features/setup/data/setup_cache.dart';
import 'package:agrum_mobile/features/setup/data/setup_data.dart';
import 'package:agrum_mobile/features/sync/data/send_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The /api/mobile/setup reply for FSD section 11's test data: site S01, worker E001 from S02.
Map<String, dynamic> setupJson({List<String> attendedToday = const ['E002']}) => {
      'today': '2026-10-24',
      'serverTime': '2026-10-24T04:30:00Z',
      'defaultEstateId': 'S01',
      'estates': [
        {
          'id': 'S01',
          'name': 'Site One',
          'variancePercent': 2.00,
          'maxDailyTransactions': 2,
          'fullDayQtyKg': 23.00,
          'halfDayQtyKg': 12,
        },
      ],
      'workTypes': [
        {'estateId': 'S01', 'workTypeCode': 'PRUNING', 'name': 'Pruning', 'weighingRequired': false},
        {'estateId': 'S01', 'workTypeCode': 'PLUCKING', 'name': 'Plucking', 'weighingRequired': true},
      ],
      'divisions': [
        {'estateId': 'S01', 'divisionCode': 'D2', 'description': 'South'},
        {'estateId': 'S01', 'divisionCode': 'D1', 'description': 'North'},
      ],
      'fields': [
        {'estateId': 'S01', 'fieldCode': 'CP2', 'divisionCode': 'D1', 'description': 'Hill', 'isDefault': false},
        {'estateId': 'S01', 'fieldCode': 'CP9', 'divisionCode': 'D1', 'description': 'North', 'isDefault': true},
        {'estateId': 'S01', 'fieldCode': 'CP5', 'divisionCode': 'D2', 'description': 'River', 'isDefault': true},
      ],
      'workers': [
        {
          'employeeCode': 'E001',
          'fullName': 'Kamala Perera',
          'defaultEstateId': 'S02',
          'homeEstateId': 'S02',
          'defaultDivisionCode': 'D1',
          'defaultFieldCode': 'CP2',
          'defaultCategory': 'REGULAR',
        },
        {'employeeCode': 'E002', 'fullName': 'Sunil Silva', 'defaultEstateId': 'S01'},
      ],
      'attendedToday': attendedToday,
      'weighableToday': [
        {
          'employeeCode': 'E002',
          'fullName': 'Sunil Silva',
          'attendanceId': '6f1c2a3e-0000-4000-8000-000000000001',
          'estateId': 'S01',
          'estateName': 'Site One',
          'divisionCode': 'D1',
          'divisionDescription': 'North',
          'fieldCode': 'CP9',
          'fieldDescription': 'North',
          'workType': 'PLUCKING',
          'workTypeName': 'Plucking',
          'variancePercent': 2.00,
          'entriesToday': 1,
          'dailyLimit': 2,
          'lastSequence': 1,
        },
      ],
    };

void main() {
  sqfliteFfiInit();

  late Database db;
  late SetupCache cache;

  setUp(() async {
    db = await AppDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    cache = SetupCache(Future.value(db));
  });

  tearDown(() => db.close());

  test('parses the server reply', () {
    final data = SetupData.fromJson(setupJson());

    expect(data.serverTime, DateTime.utc(2026, 10, 24, 4, 30));
    expect(data.estates.single.halfDayQtyKg, 12.0);
    expect(data.workers.firstWhere((w) => w.employeeCode == 'E001').attendedToday, isFalse);
    expect(data.workers.firstWhere((w) => w.employeeCode == 'E002').attendedToday, isTrue);
  });

  test('has no info before the first download', () async {
    expect(await cache.info(), isNull);
  });

  test('saves and reads back the 5.4 data', () async {
    // The phone clock is 90 seconds behind the server
    final receivedAt = DateTime.utc(2026, 10, 24, 4, 28, 30);
    await cache.save(SetupData.fromJson(setupJson()), username: 'sup01', receivedAt: receivedAt);

    final info = (await cache.info())!;
    expect(info.username, 'sup01');
    expect(info.refreshedAt, receivedAt);
    expect(info.serverToday, '2026-10-24');
    expect(info.defaultEstateId, 'S01');
    expect(info.serverOffset, const Duration(seconds: 90));
    expect(info.serverNow(receivedAt), DateTime.utc(2026, 10, 24, 4, 30));

    final estate = (await cache.estates()).single;
    expect(estate.variancePercent, 2.0);
    expect(estate.maxDailyTransactions, 2);

    expect((await cache.workTypes('S01')).map((w) => (w.workTypeCode, w.name, w.weighingRequired)),
        [('PLUCKING', 'Plucking', true), ('PRUNING', 'Pruning', false)]);
    expect((await cache.divisions('S01')).map((d) => d.label), ['D1 – North', 'D2 – South']);
    // By division, each division's default first
    expect((await cache.fields('S01')).map((f) => (f.divisionCode, f.fieldCode)),
        [('D1', 'CP9'), ('D1', 'CP2'), ('D2', 'CP5')]);
    expect(await cache.fields('S02'), isEmpty);

    // Workers from other sites are kept; those already marked today are hidden by default (AT-02)
    final workers = await cache.workers();
    expect(workers.map((w) => w.employeeCode), ['E001']);
    expect(workers.single.defaultEstateId, 'S02');
    expect(workers.single.defaultCategory, 'REGULAR');
    expect((workers.single.defaultDivisionCode, workers.single.defaultFieldCode), ('D1', 'CP2'));
    expect((await cache.workers(includeAttended: true)).length, 2);

    // Today's weighable attendance for the weighing screen (2.7)
    final weighable = (await cache.weighable()).single;
    expect((weighable.employeeCode, weighable.divisionCode, weighable.fieldCode, weighable.workTypeName),
        ('E002', 'D1', 'CP9', 'Plucking'));
    expect((weighable.entriesToday, weighable.lastSequence), (1, 1));
    expect(weighable.variancePercent, 2.0);
    expect((await cache.allWorkTypes()).length, 2);
    expect((await cache.allDivisions()).length, 2);
    expect((await cache.allFields()).length, 3);
  });

  test('a refresh replaces the old data', () async {
    final first = DateTime.utc(2026, 10, 24, 4, 30);
    await cache.save(SetupData.fromJson(setupJson()), username: 'sup01', receivedAt: first);
    final json = setupJson(attendedToday: const ['E001', 'E002'])
      ..['estates'] = <Map<String, dynamic>>[]
      ..['defaultEstateId'] = null;
    await cache.save(SetupData.fromJson(json), username: 'sup02', receivedAt: first.add(const Duration(hours: 1)));

    final info = (await cache.info())!;
    expect(info.username, 'sup02');
    expect(info.defaultEstateId, isNull);
    expect(await cache.estates(), isEmpty);
    expect(await cache.workers(), isEmpty);
  });

  test('a version 1 database is upgraded, keeping its rows', () async {
    final dir = Directory.systemTemp.createTempSync('agrum_db');
    final path = p.join(dir.path, 'agrum.db');
    // The weight_rows table as it was before the weighing screen
    final v1 = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (d, _) async {
            await d.execute('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
            await d.execute('''CREATE TABLE weight_rows (weight_id TEXT PRIMARY KEY, attendance_id TEXT NOT NULL,
                employee_code TEXT NOT NULL, full_name TEXT NOT NULL, estate_id TEXT NOT NULL,
                weighed_at TEXT NOT NULL, weight_kg REAL NOT NULL, entry_type TEXT NOT NULL,
                variance_percent REAL, provisional_sequence INTEGER NOT NULL, final_sequence INTEGER,
                recorded_by TEXT NOT NULL, sync_status TEXT NOT NULL, reason TEXT)''');
            await d.execute('''CREATE TABLE attendance_rows (attendance_id TEXT PRIMARY KEY,
                employee_code TEXT NOT NULL, full_name TEXT NOT NULL, estate_id TEXT NOT NULL,
                work_type TEXT NOT NULL, cp_code TEXT NOT NULL, category TEXT NOT NULL,
                attendance_date TEXT NOT NULL, recorded_at TEXT NOT NULL, recorded_by TEXT NOT NULL,
                sync_status TEXT NOT NULL, reason TEXT)''');
            await d.insert('meta', {'key': 'k', 'value': 'v'});
            for (final (id, status) in [('a1', 'SENT'), ('a2', 'WAITING')]) {
              await d.insert('attendance_rows', {
                'attendance_id': id,
                'employee_code': 'E001',
                'full_name': 'Kamala Perera',
                'estate_id': 'S01',
                'work_type': 'PLUCKING',
                'cp_code': 'CP9',
                'category': 'REGULAR',
                'attendance_date': '2026-10-24',
                'recorded_at': '2026-10-24T02:00:00Z',
                'recorded_by': 'sup01',
                'sync_status': status,
              });
            }
          },
        ));
    await v1.close();

    final upgraded = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    final columns = (await upgraded.rawQuery('PRAGMA table_info(weight_rows)')).map((c) => c['name']);
    expect(columns, containsAll(['weigh_date', 'division_code', 'field_code', 'work_type', 'sent_at']));
    expect(columns, isNot(contains('cp_code')));
    expect(await upgraded.query('cache_weighable'), isEmpty);
    expect(await upgraded.query('cache_fields'), isEmpty);
    final attendanceColumns = (await upgraded.rawQuery('PRAGMA table_info(attendance_rows)')).map((c) => c['name']);
    expect(attendanceColumns, containsAll(['sent_at', 'division_code', 'field_code']));
    expect(attendanceColumns, isNot(contains('cp_code')));
    expect((await upgraded.query('meta')).single['value'], 'v');

    // FSD v2.7: the field code is kept; unsent attendance has no division (AT-19), so it is Rejected
    final rows = await upgraded.query('attendance_rows', orderBy: 'rowid');
    expect(rows.map((r) => (r['attendance_id'], r['field_code'], r['sync_status'])),
        [('a1', 'CP9', 'SENT'), ('a2', 'CP9', 'REJECTED')]);
    expect(rows.last['reason'], AppDatabase.recordAgainReason);
    expect(rows.first['reason'], isNull);
    await upgraded.close();
    dir.deleteSync(recursive: true);
  });

  test('counts only the user\'s waiting records', () async {
    final queue = SendQueue(Future.value(db));
    Future<void> attendance(String id, String by, String status) => db.insert('attendance_rows', {
          'attendance_id': id,
          'employee_code': 'E001',
          'full_name': 'Kamala Perera',
          'estate_id': 'S01',
          'work_type': 'PLUCKING',
          'division_code': 'D1',
          'field_code': 'CP9',
          'category': 'REGULAR',
          'attendance_date': '2026-10-24',
          'recorded_at': '2026-10-24T02:00:00Z',
          'recorded_by': by,
          'sync_status': status,
        });
    await attendance('a1', 'sup01', 'WAITING');
    await attendance('a2', 'sup01', 'SENT');
    await attendance('a3', 'sup02', 'WAITING');
    await db.insert('weight_rows', {
      'weight_id': 'w1',
      'attendance_id': 'a1',
      'employee_code': 'E001',
      'full_name': 'Kamala Perera',
      'estate_id': 'S01',
      'weighed_at': '2026-10-24T05:00:00Z',
      'weight_kg': 13.0,
      'entry_type': 'AUTOMATIC',
      'provisional_sequence': 1,
      'recorded_by': 'sup01',
      'sync_status': 'WAITING',
    });

    expect(await queue.waitingCount('sup01'), 2);
    expect(await queue.waitingCount('sup02'), 1);
    expect(await queue.waitingCount('sup03'), 0);
  });
}
