import 'package:intl/intl.dart';

import '../../setup/data/setup_cache.dart';
import '../../setup/data/setup_data.dart';
import '../data/attendance_row.dart';

/// FSD 2.6 messages the phone shows itself. The server checks the same rules again.
class AttendanceMessages {
  const AttendanceMessages._();

  static const noWorkers = 'Please select at least one worker.'; // AT-01
  static String alreadyRecorded(String worker) => 'Attendance has already been recorded today for $worker.'; // AT-02
  static const siteNotAllowed = 'Attendance cannot be recorded for an inactive or unassigned site.'; // AT-05
  static String otherSite(String worker) => 'You are not permitted to record $worker at a different site.'; // AT-06
  static const workType = 'Please select a Work Type.'; // AT-07
  static const category = 'Please select the Attendance Category.'; // AT-08
  static const collectionPoint = 'Please select the Collection Point.'; // AT-09
  static const siteSetup = 'Site setup is incomplete. Please contact the administrator.'; // AT-10
  static const todayOnly = 'Attendance can only be recorded for today. Please check the phone date.'; // AT-11

  static const noSiteData = 'Site data is not on this phone yet. Connect to the internet and tap Send Now.';

  static String confirm(int n) => 'Attendance cannot be changed after submission. Submit attendance for $n workers?';
  static String recorded(int n) => 'Attendance recorded for $n workers.';
}

final _isoDate = DateFormat('yyyy-MM-dd');

/// The date an attendance row is recorded for: the phone's date.
String attendanceDateOf(DateTime phoneNow) => _isoDate.format(phoneNow);

String workerLabel(CachedWorker worker) => '${worker.fullName} (${worker.employeeCode})';

/// AT-06: a worker whose default site is not the working site.
bool isOtherSiteWorker(CachedWorker worker, String estateId) =>
    worker.defaultEstateId != null && worker.defaultEstateId != estateId;

/// A worker ticked in the batch, with the category chosen for them.
class BatchWorker {
  const BatchWorker(this.worker, this.category);

  final CachedWorker worker;
  final AttendanceCategory? category;
}

/// The batch's collection point: the one all ticked workers share as their personal default,
/// else the site's default (FSD 2.6).
String? defaultCollectionPoint(List<CachedCollectionPoint> siteCollectionPoints, Iterable<CachedWorker> workers) {
  final shared = workers.map((w) => w.defaultCpCode).toSet();
  if (shared.length == 1 && shared.single != null && siteCollectionPoints.any((cp) => cp.cpCode == shared.single)) {
    return shared.single;
  }
  for (final cp in siteCollectionPoints) {
    if (cp.isDefault) return cp.cpCode;
  }
  return null;
}

/// The phone-side checks before the confirm dialog; returns the first problem, or null.
String? validateBatch({
  required DateTime phoneNow,
  required CacheInfo? cacheInfo,
  required CachedEstate? site,
  required List<CachedWorkType> siteWorkTypes,
  required List<CachedCollectionPoint> siteCollectionPoints,
  required String? workType,
  required String? cpCode,
  required List<BatchWorker> workers,
  required Set<String> markedToday,
  required bool canRecordOtherSite,
}) {
  if (cacheInfo == null) return AttendanceMessages.noSiteData;
  // AT-11 (D-10): the phone's date must be the server's date
  if (attendanceDateOf(phoneNow) != attendanceDateOf(cacheInfo.serverNow(phoneNow))) {
    return AttendanceMessages.todayOnly;
  }
  if (site == null) return AttendanceMessages.siteNotAllowed; // AT-05
  if (siteWorkTypes.isEmpty || siteCollectionPoints.isEmpty) return AttendanceMessages.siteSetup; // AT-10
  if (workType == null || !siteWorkTypes.any((wt) => wt.workType == workType)) return AttendanceMessages.workType; // AT-07
  if (cpCode == null || !siteCollectionPoints.any((cp) => cp.cpCode == cpCode)) {
    return AttendanceMessages.collectionPoint; // AT-09
  }
  if (workers.isEmpty) return AttendanceMessages.noWorkers; // AT-01
  for (final w in workers) {
    if (w.worker.attendedToday || markedToday.contains(w.worker.employeeCode)) {
      return AttendanceMessages.alreadyRecorded(workerLabel(w.worker)); // AT-02
    }
    if (!canRecordOtherSite && isOtherSiteWorker(w.worker, site.id)) {
      return AttendanceMessages.otherSite(workerLabel(w.worker)); // AT-06
    }
    if (w.category == null) return AttendanceMessages.category; // AT-08
  }
  return null;
}
