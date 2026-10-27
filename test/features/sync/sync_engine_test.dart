import 'package:agrum_mobile/core/api/api_exception.dart';
import 'package:agrum_mobile/core/db/app_database.dart';
import 'package:agrum_mobile/features/attendance/data/attendance_row.dart';
import 'package:agrum_mobile/features/attendance/data/attendance_store.dart';
import 'package:agrum_mobile/features/attendance/data/attendance_sync_api.dart';
import 'package:agrum_mobile/features/sync/data/sync_engine.dart';
import 'package:agrum_mobile/features/sync/data/sync_status.dart';
import 'package:agrum_mobile/features/weighing/data/weight_row.dart';
import 'package:agrum_mobile/features/weighing/data/weight_store.dart';
import 'package:agrum_mobile/features/weighing/data/weight_sync_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Answers like POST /api/attendance/sync and records what it was sent.
class FakeAttendanceApi implements AttendanceSyncApi {
  final calls = <List<String>>[];

  /// Every id sent, attendance and weighings, in order.
  final order = <String>[];

  /// Ids the server rejects, with the reason.
  final rejections = <String, String>{};

  /// Ids the server leaves out of its reply.
  final unanswered = <String>{};
  ApiException? failWith;

  @override
  Future<List<SyncResult>> send(List<AttendanceRow> rows) async {
    calls.add(rows.map((r) => r.attendanceId).toList());
    order.addAll(rows.map((r) => r.attendanceId));
    if (failWith != null) throw failWith!;
    return [
      for (final r in rows)
        if (!unanswered.contains(r.attendanceId))
          rejections.containsKey(r.attendanceId)
              ? (id: r.attendanceId, status: SyncStatus.rejected, reason: rejections[r.attendanceId])
              : (id: r.attendanceId, status: SyncStatus.sent, reason: null),
    ];
  }
}

/// Answers like POST /api/weights/sync: Sent with the next number per attendance, or Rejected.
class FakeWeightApi implements WeightSyncApi {
  FakeWeightApi(this.log);

  /// Shared with the attendance fake, to check the send order.
  final List<String> log;
  final rejections = <String, String>{};
  final _lastSequence = <String, int>{};

  @override
  Future<List<WeightSyncResult>> send(List<WeightRow> rows) async {
    log.addAll(rows.map((r) => r.weightId));
    return [
      for (final r in rows)
        rejections.containsKey(r.weightId)
            ? (id: r.weightId, status: SyncStatus.rejected, entrySequence: null, reason: rejections[r.weightId])
            : (
                id: r.weightId,
                status: SyncStatus.sent,
                entrySequence: _lastSequence[r.attendanceId] = (_lastSequence[r.attendanceId] ?? 0) + 1,
                reason: null,
              ),
    ];
  }
}

WeightRow weighing(String id, {String attendanceId = 'a1', int provisional = 1}) => WeightRow(
      weightId: id,
      attendanceId: attendanceId,
      employeeCode: 'E-$attendanceId',
      fullName: 'Worker $attendanceId',
      estateId: 'S01',
      cpCode: 'CP9',
      workType: 'PLUCKING',
      weighDate: '2026-10-24',
      weighedAt: DateTime.utc(2026, 10, 24, 3),
      weightKg: 12,
      entryType: EntryType.manual,
      variancePercent: 2,
      provisionalSequence: provisional,
      recordedBy: 'sup01',
    );

AttendanceRow row(String id, {String by = 'sup01'}) => AttendanceRow(
      attendanceId: id,
      employeeCode: 'E-$id',
      fullName: 'Worker $id',
      estateId: 'S01',
      workType: 'PLUCKING',
      cpCode: 'CP9',
      category: AttendanceCategory.regular,
      attendanceDate: '2026-10-24',
      recordedAt: DateTime.utc(2026, 10, 24, 2),
      recordedBy: by,
    );

void main() {
  sqfliteFfiInit();

  late Database db;
  late AttendanceStore store;
  late FakeAttendanceApi api;
  late SyncEngine engine;
  late WeightStore weights;
  late FakeWeightApi weightApi;

  setUp(() async {
    db = await AppDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    store = AttendanceStore(Future.value(db));
    api = FakeAttendanceApi();
    weights = WeightStore(Future.value(db));
    weightApi = FakeWeightApi(api.order);
    engine = SyncEngine(attendance: store, attendanceApi: api, weights: weights, weightApi: weightApi, batchSize: 2);
  });

  tearDown(() => db.close());

  Future<Map<String, (SyncStatus, String?)>> statuses() async => {
        for (final r in await store.forDate('sup01', '2026-10-24')) r.attendanceId: (r.status, r.reason),
      };

  test('sends the user\'s waiting rows in recorded order, in batches', () async {
    await store.saveBatch([row('a1'), row('a2'), row('a3'), row('b1', by: 'sup02')]);

    final outcome = await engine.run('sup01');

    expect(api.calls, [
      ['a1', 'a2'],
      ['a3'],
    ]);
    expect(outcome.ok, isTrue);
    expect(outcome.sent, 3);
    expect((await statuses()).values.map((s) => s.$1), everyElement(SyncStatus.sent));
    // Another supervisor's rows wait for their own login
    expect((await store.waiting('sup02')).single.attendanceId, 'b1');
  });

  test('TC-38: a rejected row keeps the server\'s reason; the others are still sent', () async {
    await store.saveBatch([row('a1'), row('a2')]);
    api.rejections['a1'] = 'Attendance has already been recorded today for Worker a1 (E-a1).';

    final outcome = await engine.run('sup01');

    expect(outcome.sent, 1);
    expect(outcome.rejected, 1);
    final s = await statuses();
    expect(s['a1'], (SyncStatus.rejected, 'Attendance has already been recorded today for Worker a1 (E-a1).'));
    expect(s['a2'], (SyncStatus.sent, null));
    // Rejected rows are not sent again
    api.calls.clear();
    await engine.run('sup01');
    expect(api.calls, isEmpty);
  });

  test('no connection: everything stays Waiting', () async {
    await store.saveBatch([row('a1')]);
    api.failWith = const ApiException('Cannot reach the server.', isNetwork: true);

    final outcome = await engine.run('sup01');

    expect(outcome.ok, isFalse);
    expect(outcome.networkError, isTrue);
    expect((await store.waiting('sup01')).length, 1);
  });

  test('a row the server did not answer stays Waiting and is not resent in the same run', () async {
    await store.saveBatch([row('a1'), row('a2')]);
    api.unanswered.add('a2');

    final outcome = await engine.run('sup01');

    expect(api.calls, [
      ['a1', 'a2'],
    ]);
    expect(outcome.sent, 1);
    expect((await store.waiting('sup01')).single.attendanceId, 'a2');
  });

  test('TC-58 / AT-12: a resend of a Sent row does not change it', () async {
    await store.saveBatch([row('a1')]);
    await engine.run('sup01');
    // A late reply for the same id must not turn a Sent row into Rejected
    await store.applyResults([(id: 'a1', status: SyncStatus.rejected, reason: 'late')]);
    expect((await statuses())['a1'], (SyncStatus.sent, null));
  });

  test('earlier days\' rows that are not Sent', () async {
    final old = AttendanceRow(
      attendanceId: 'old',
      employeeCode: 'E9',
      fullName: 'Worker 9',
      estateId: 'S01',
      workType: 'PLUCKING',
      cpCode: 'CP9',
      category: AttendanceCategory.regular,
      attendanceDate: '2026-10-23',
      recordedAt: DateTime.utc(2026, 10, 23, 2),
      recordedBy: 'sup01',
    );
    await store.saveBatch([old, row('a1')]);
    expect((await store.unsentBefore('sup01', '2026-10-24')).single.attendanceId, 'old');
    await engine.run('sup01');
    expect(await store.unsentBefore('sup01', '2026-10-24'), isEmpty);
  });

  test('weighings go after all attendance and take the server\'s entry number (WE-10)', () async {
    await store.saveBatch([row('a1')]);
    // Two phones guessed number 1; the server numbers them 1 and 2
    await weights.save(weighing('w1'));
    await weights.save(weighing('w2'));
    await store.saveBatch([row('a2')]);

    final outcome = await engine.run('sup01');

    expect(api.order, ['a1', 'a2', 'w1', 'w2']);
    expect(outcome.sent, 4);
    final saved = {for (final w in await weights.forDate('sup01', '2026-10-24')) w.weightId: w};
    expect(saved['w1']!.sequence, 1);
    expect(saved['w2']!.sequence, 2);
    expect(saved.values.map((w) => w.status), everyElement(SyncStatus.sent));
  });

  test('TC-54: a weighing over the limit is Rejected with the reason and not sent again', () async {
    await weights.save(weighing('w3', provisional: 3));
    weightApi.rejections['w3'] = 'Maximum of 2 weighings per day already recorded for this worker.';

    final outcome = await engine.run('sup01');

    expect(outcome.rejected, 1);
    final w3 = (await weights.forDate('sup01', '2026-10-24')).single;
    expect(w3.status, SyncStatus.rejected);
    expect(w3.reason, 'Maximum of 2 weighings per day already recorded for this worker.');
    expect(w3.sequence, 3);
    api.order.clear();
    await engine.run('sup01');
    expect(api.order, isEmpty);
  });

  test('weighings are not sent when the attendance send fails', () async {
    await store.saveBatch([row('a1')]);
    await weights.save(weighing('w1'));
    api.failWith = const ApiException('Cannot reach the server.', isNetwork: true);

    await engine.run('sup01');

    expect(api.order, ['a1']);
    expect((await weights.waiting('sup01')).single.weightId, 'w1');
  });
}
