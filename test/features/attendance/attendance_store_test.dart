import 'package:agrum_mobile/core/db/app_database.dart';
import 'package:agrum_mobile/features/attendance/data/attendance_row.dart';
import 'package:agrum_mobile/features/attendance/data/attendance_store.dart';
import 'package:agrum_mobile/features/sync/data/send_queue.dart';
import 'package:agrum_mobile/features/sync/data/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

AttendanceRow row(String id, String code, {String by = 'sup01', String date = '2026-10-24', SyncStatus? status}) =>
    AttendanceRow(
      attendanceId: id,
      employeeCode: code,
      fullName: 'Worker $code',
      estateId: 'S01',
      workType: 'PLUCKING',
      cpCode: 'CP9',
      category: AttendanceCategory.regular,
      attendanceDate: date,
      recordedAt: DateTime.utc(2026, 10, 24, 2),
      recordedBy: by,
      status: status ?? SyncStatus.waiting,
    );

void main() {
  sqfliteFfiInit();

  late Database db;
  late AttendanceStore store;

  setUp(() async {
    db = await AppDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    store = AttendanceStore(Future.value(db));
  });

  tearDown(() => db.close());

  test('saves a batch as Waiting and lists the user\'s rows for the day, newest first', () async {
    await store.saveBatch([row('a1', 'E001'), row('a2', 'E002')]);
    await store.saveBatch([row('a3', 'E003', by: 'sup02'), row('a4', 'E004', date: '2026-10-23')]);

    final today = await store.forDate('sup01', '2026-10-24');
    expect(today.map((r) => r.attendanceId), ['a2', 'a1']);
    expect(today.first.status, SyncStatus.waiting);
    expect(today.first.category, AttendanceCategory.regular);
    expect(today.first.recordedAt, DateTime.utc(2026, 10, 24, 2));
    expect(await SendQueue(Future.value(db)).waitingCount('sup01'), 3);
  });

  test('a batch with a duplicate id saves nothing', () async {
    await store.saveBatch([row('a1', 'E001')]);
    await expectLater(store.saveBatch([row('a2', 'E002'), row('a1', 'E003')]), throwsA(isA<DatabaseException>()));
    expect((await store.forDate('sup01', '2026-10-24')).length, 1);
  });

  test('workers marked today by anyone on the phone, except rejected rows (AT-02)', () async {
    await store.saveBatch([
      row('a1', 'E001'),
      row('a2', 'E002', by: 'sup02', status: SyncStatus.sent),
      row('a3', 'E003', status: SyncStatus.rejected),
      row('a4', 'E004', date: '2026-10-23'),
    ]);
    expect(await store.markedOn('2026-10-24'), {'E001', 'E002'});
  });
}
