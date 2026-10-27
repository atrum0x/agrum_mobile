import 'package:agrum_mobile/features/attendance/data/attendance_row.dart';
import 'package:agrum_mobile/features/setup/data/setup_cache.dart';
import 'package:agrum_mobile/features/setup/data/setup_data.dart';
import 'package:agrum_mobile/features/sync/data/sync_status.dart';
import 'package:agrum_mobile/features/weighing/data/weight_row.dart';
import 'package:agrum_mobile/features/weighing/domain/weighing_rules.dart';
import 'package:flutter_test/flutter_test.dart';

const today = '2026-10-24';

CacheInfo cacheInfo({String serverToday = today, DateTime? refreshedAt}) => CacheInfo(
      username: 'sup01',
      refreshedAt: refreshedAt ?? DateTime.utc(2026, 10, 24, 3),
      serverToday: serverToday,
      serverOffset: Duration.zero,
    );

const estates = [CachedEstate(id: 'S01', name: 'Site One', variancePercent: 2, maxDailyTransactions: 2)];
const workTypes = [
  CachedWorkType(estateId: 'S01', workType: 'PLUCKING', weighingRequired: true),
  CachedWorkType(estateId: 'S01', workType: 'PRUNING', weighingRequired: false),
];
const collectionPoints = [CachedCollectionPoint(estateId: 'S01', cpCode: 'CP9', name: 'North', isDefault: true)];

const fromServer = CachedWeighable(
  attendanceId: 'srv-1',
  employeeCode: 'E002',
  fullName: 'Sunil Silva',
  estateId: 'S01',
  estateName: 'Site One',
  cpCode: 'CP9',
  cpName: 'North',
  workType: 'PLUCKING',
  variancePercent: 2,
  entriesToday: 1,
  dailyLimit: 2,
  lastSequence: 1,
);

AttendanceRow attendance(String id, {String workType = 'PLUCKING', SyncStatus status = SyncStatus.waiting}) =>
    AttendanceRow(
      attendanceId: id,
      employeeCode: 'E-$id',
      fullName: 'Worker $id',
      estateId: 'S01',
      workType: workType,
      cpCode: 'CP9',
      category: AttendanceCategory.regular,
      attendanceDate: today,
      recordedAt: DateTime.utc(2026, 10, 24, 2),
      recordedBy: 'sup01',
      status: status,
    );

WeightRow weighing(String attendanceId, int sequence,
        {SyncStatus status = SyncStatus.waiting, DateTime? at, int? finalSequence}) =>
    WeightRow(
      weightId: 'w-$attendanceId-$sequence',
      attendanceId: attendanceId,
      employeeCode: 'E',
      fullName: 'W',
      estateId: 'S01',
      cpCode: 'CP9',
      workType: 'PLUCKING',
      weighDate: today,
      weighedAt: at ?? DateTime.utc(2026, 10, 24, 4),
      weightKg: 12,
      entryType: EntryType.manual,
      variancePercent: 2,
      provisionalSequence: sequence,
      finalSequence: finalSequence,
      recordedBy: 'sup01',
      status: status,
    );

List<WeighableWorker> build({
  CacheInfo? info,
  List<CachedWeighable> server = const [fromServer],
  List<AttendanceRow> local = const [],
  List<WeightRow> weighings = const [],
}) =>
    weighableWorkers(
      today: today,
      cacheInfo: info ?? cacheInfo(),
      serverWeighable: server,
      localAttendance: local,
      estates: estates,
      workTypes: workTypes,
      collectionPoints: collectionPoints,
      localWeighings: weighings,
    );

void main() {
  group('weighable workers (WE-02, WE-03, WE-05)', () {
    test('server attendance plus this phone\'s own attendance with a weighing work type', () {
      final workers = build(local: [
        attendance('a1'),
        attendance('a2', workType: 'PRUNING'), // WE-03
        attendance('a3', status: SyncStatus.rejected),
      ]);

      expect(workers.map((w) => w.attendanceId), ['a1', 'srv-1']); // by EMP No
      final a1 = workers.first;
      expect((a1.entriesToday, a1.dailyLimit, a1.nextSequence), (0, 2, 1));
      expect(a1.cpName, 'North');
      expect(a1.variancePercent, 2);
    });

    test('a refresh from an earlier day is not used', () {
      expect(build(info: cacheInfo(serverToday: '2026-10-23')), isEmpty);
    });

    test('a local attendance the server already sent back is listed once', () {
      final workers = build(local: [attendance('srv-1')]);
      expect(workers.single.entriesToday, 1);
    });
  });

  group('Entries Today and the provisional number (WE-04, WE-10)', () {
    test('adds Waiting weighings and those after the refresh; not Rejected ones', () {
      final workers = build(weighings: [
        weighing('srv-1', 2),
        weighing('srv-1', 3, status: SyncStatus.rejected),
      ]);
      final w = workers.single;
      expect(w.entriesToday, 2);
      expect(w.atLimit, isTrue);
      expect(w.nextSequence, 3);
    });

    test('a Sent weighing from before the refresh is already in the server count', () {
      final workers = build(weighings: [
        weighing('srv-1', 1, status: SyncStatus.sent, at: DateTime.utc(2026, 10, 24, 2), finalSequence: 1),
      ]);
      expect(workers.single.entriesToday, 1);
    });

    test('a Sent weighing after the refresh is counted, with the server\'s number', () {
      final workers = build(weighings: [weighing('srv-1', 2, status: SyncStatus.sent, finalSequence: 5)]);
      expect(workers.single.entriesToday, 2);
      expect(workers.single.nextSequence, 6);
    });
  });

  group('Save checks', () {
    final now = DateTime(2026, 10, 24, 9);
    final worker = build().single;

    String? check({
      CacheInfo? info,
      WeighableWorker? w,
      String weight = '13',
      EntryType? type = EntryType.manual,
      bool canManual = true,
    }) =>
        validateWeighing(
          phoneNow: now,
          cacheInfo: info ?? cacheInfo(),
          worker: w,
          weightText: weight,
          entryType: type,
          canEnterManually: canManual,
        );

    test('a valid manual weighing passes', () {
      expect(check(w: worker), isNull);
    });

    test('phone date not the server date (D-10)', () {
      final info = CacheInfo(
        username: 'sup01',
        refreshedAt: DateTime.utc(2026, 10, 24),
        serverToday: today,
        serverOffset: const Duration(days: 1),
      );
      expect(check(info: info, w: worker), WeighingMessages.todayOnly);
    });

    test('WE-01 no worker', () => expect(check(), WeighingMessages.selectWorker));

    test('WE-04 at the daily limit', () {
      final full = build(weighings: [weighing('srv-1', 2)]).single;
      expect(check(w: full), 'Maximum of 2 weighings per day already recorded for this worker.');
    });

    test('no weight captured or typed', () {
      expect(check(w: worker, type: null), WeighingMessages.entryType);
    });

    test('WE-08 manual entry without the grant', () {
      expect(check(w: worker, canManual: false), WeighingMessages.noManual);
    });

    test('WE-06 weight must be > 0 with at most 2 decimals', () {
      for (final bad in ['', '0', '0.00', '12.345', 'abc', '-1']) {
        expect(check(w: worker, weight: bad), WeighingMessages.weight, reason: bad);
      }
      expect(parseWeight('13.5'), 13.5);
      expect(parseWeight(' 12.00 '), 12);
    });
  });

  test('Saved message', () {
    expect(WeighingMessages.saved('E001', 2, 13), 'Saved – E001, weighing 2, 13.00 kg');
  });
}
