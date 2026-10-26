import 'package:agrum_mobile/features/attendance/data/attendance_row.dart';
import 'package:agrum_mobile/features/attendance/domain/attendance_rules.dart';
import 'package:agrum_mobile/features/setup/data/setup_cache.dart';
import 'package:agrum_mobile/features/setup/data/setup_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// FSD section 11 test data: site S01, Plucking, collection points CP9 (site default) and CP2.
const s01 = CachedEstate(id: 'S01', name: 'Site One', variancePercent: 2, maxDailyTransactions: 2);
const plucking = CachedWorkType(estateId: 'S01', workType: 'PLUCKING', weighingRequired: true);
const cp9 = CachedCollectionPoint(estateId: 'S01', cpCode: 'CP9', isDefault: true);
const cp2 = CachedCollectionPoint(estateId: 'S01', cpCode: 'CP2', isDefault: false);

CachedWorker worker(String code, {String? site = 'S01', String? cp, bool attended = false}) => CachedWorker(
      employeeCode: code,
      fullName: 'Worker $code',
      defaultEstateId: site,
      defaultCpCode: cp,
      defaultCategory: 'REGULAR',
      attendedToday: attended,
    );

void main() {
  final now = DateTime(2026, 10, 24, 7, 30);
  final info = CacheInfo(
    username: 'sup01',
    refreshedAt: now,
    serverToday: '2026-10-24',
    serverOffset: Duration.zero,
  );

  String? validate({
    DateTime? phoneNow,
    CacheInfo? cacheInfo,
    bool noCache = false,
    CachedEstate? site = s01,
    List<CachedWorkType> workTypes = const [plucking],
    List<CachedCollectionPoint> cps = const [cp9, cp2],
    String? workType = 'PLUCKING',
    String? cpCode = 'CP9',
    List<BatchWorker>? workers,
    Set<String> marked = const {},
    bool otherSite = false,
  }) =>
      validateBatch(
        phoneNow: phoneNow ?? now,
        cacheInfo: noCache ? null : (cacheInfo ?? info),
        site: site,
        siteWorkTypes: workTypes,
        siteCollectionPoints: cps,
        workType: workType,
        cpCode: cpCode,
        workers: workers ?? [BatchWorker(worker('E001'), AttendanceCategory.regular)],
        markedToday: marked,
        canRecordOtherSite: otherSite,
      );

  test('a complete batch passes', () => expect(validate(), isNull));

  test('no site data on the phone yet', () => expect(validate(noCache: true), AttendanceMessages.noSiteData));

  test('TC-36: phone date is yesterday (AT-11)', () {
    // The phone shows 23/10 23:50 while the server is already at 24/10 07:30
    final phone = DateTime(2026, 10, 23, 23, 50);
    final skewed = CacheInfo(
      username: 'sup01',
      refreshedAt: now,
      serverToday: '2026-10-24',
      serverOffset: now.difference(phone),
    );
    expect(validate(phoneNow: phone, cacheInfo: skewed), AttendanceMessages.todayOnly);
  });

  test('AT-05 / AT-10 / AT-07 / AT-09', () {
    expect(validate(site: null), AttendanceMessages.siteNotAllowed);
    expect(validate(workTypes: const []), AttendanceMessages.siteSetup);
    expect(validate(cps: const []), AttendanceMessages.siteSetup);
    expect(validate(workType: null), AttendanceMessages.workType);
    expect(validate(workType: 'PRUNING'), AttendanceMessages.workType);
    expect(validate(cpCode: null), AttendanceMessages.collectionPoint);
  });

  test('AT-01: at least one worker', () => expect(validate(workers: const []), AttendanceMessages.noWorkers));

  test('AT-02: marked today, on the server or on this phone', () {
    final attended = worker('E002', attended: true);
    expect(validate(workers: [BatchWorker(attended, AttendanceCategory.regular)]),
        AttendanceMessages.alreadyRecorded('Worker E002 (E002)'));
    expect(validate(marked: {'E001'}), AttendanceMessages.alreadyRecorded('Worker E001 (E001)'));
  });

  test('AT-06: another site\'s worker needs the other-site grant', () {
    final lent = [BatchWorker(worker('E003', site: 'S02'), AttendanceCategory.lent)];
    expect(validate(workers: lent), AttendanceMessages.otherSite('Worker E003 (E003)'));
    expect(validate(workers: lent, otherSite: true), isNull);
    // A worker with no default site is not from another site
    expect(validate(workers: [BatchWorker(worker('E004', site: null), AttendanceCategory.regular)]), isNull);
  });

  test('AT-08: every worker needs a category', () {
    expect(validate(workers: [BatchWorker(worker('E001'), null)]), AttendanceMessages.category);
  });

  test('collection point: the workers\' shared default, else the site default', () {
    expect(defaultCollectionPoint([cp9, cp2], [worker('E1', cp: 'CP2'), worker('E2', cp: 'CP2')]), 'CP2');
    expect(defaultCollectionPoint([cp9, cp2], [worker('E1', cp: 'CP2'), worker('E2', cp: 'CP9')]), 'CP9');
    expect(defaultCollectionPoint([cp9, cp2], [worker('E1', cp: 'CP7')]), 'CP9');
    expect(defaultCollectionPoint([cp9, cp2], []), 'CP9');
    expect(defaultCollectionPoint([cp2], []), isNull);
  });

  test('the exact FSD texts', () {
    expect(AttendanceMessages.confirm(3),
        'Attendance cannot be changed after submission. Submit attendance for 3 workers?');
    expect(AttendanceMessages.recorded(3), 'Attendance recorded for 3 workers.');
  });
}
