import 'package:intl/intl.dart';

import '../../attendance/data/attendance_row.dart';
import '../../attendance/domain/attendance_rules.dart';
import '../../setup/data/setup_cache.dart';
import '../../setup/data/setup_data.dart';
import '../../sync/data/sync_status.dart';
import '../data/weight_row.dart';

/// FSD 2.7 messages the phone shows itself. The server checks the same rules again.
class WeighingMessages {
  const WeighingMessages._();

  static const selectWorker = 'Please select a worker.'; // WE-01
  static String limitReached(int n) => 'Maximum of $n weighings per day already recorded for this worker.'; // WE-04
  static const weight = 'Please enter a weight greater than 0.'; // WE-06
  static const noScaleReading = 'No valid reading from the scale. Please check the scale connection.'; // WE-07
  static const noManual = 'You are not permitted to enter weight manually.'; // WE-08
  static const noPermission = 'You do not have permission to record weights.'; // WE-11
  static const todayOnly = 'Weights can only be recorded for today. Please check the phone date.';
  static const entryType = 'Please capture the weight from the scale or enter it manually.';

  static const noSiteData = AttendanceMessages.noSiteData;

  static String saved(String employeeCode, int sequence, double kg) =>
      'Saved – $employeeCode, weighing $sequence, ${formatKg(kg)} kg';
}

final _kg = NumberFormat('0.00');

/// FSD 8: kg with 2 decimals.
String formatKg(double kg) => _kg.format(kg);

/// A worker that can be weighed today, with what the screen fills in from the attendance (2.7 step 2).
class WeighableWorker {
  const WeighableWorker({
    required this.attendanceId,
    required this.employeeCode,
    required this.fullName,
    required this.estateId,
    required this.cpCode,
    this.cpName,
    required this.workType,
    required this.variancePercent,
    required this.entriesToday,
    required this.dailyLimit,
    required this.lastSequence,
  });

  final String attendanceId;
  final String employeeCode;
  final String fullName;
  final String estateId;
  final String cpCode;
  final String? cpName;
  final String workType;
  final double variancePercent;
  final int entriesToday;
  final int dailyLimit;
  final int lastSequence;

  /// WE-04
  bool get atLimit => entriesToday >= dailyLimit;

  /// Provisional entry number: highest known + 1; the server gives the final one (WE-10).
  int get nextSequence => lastSequence + 1;

  WeighableWorker withLocal({required int extraEntries, required int lastLocalSequence}) => WeighableWorker(
        attendanceId: attendanceId,
        employeeCode: employeeCode,
        fullName: fullName,
        estateId: estateId,
        cpCode: cpCode,
        cpName: cpName,
        workType: workType,
        variancePercent: variancePercent,
        entriesToday: entriesToday + extraEntries,
        dailyLimit: dailyLimit,
        lastSequence: lastLocalSequence > lastSequence ? lastLocalSequence : lastSequence,
      );
}

/// The workers on the weighing screen (WE-02, WE-03, WE-05), offline:
/// - today's attendance the server knew at the last refresh, if that refresh was today, and
/// - attendance recorded on this phone today and not Rejected, at a cached (Active, visible) site
///   with a weighing-required work type.
///
/// Entries Today and the last number add this phone's weighings the server hadn't counted yet: those
/// still Waiting, and those saved after the last refresh.
List<WeighableWorker> weighableWorkers({
  required String today,
  required CacheInfo? cacheInfo,
  required List<CachedWeighable> serverWeighable,
  required List<AttendanceRow> localAttendance,
  required List<CachedEstate> estates,
  required List<CachedWorkType> workTypes,
  required List<CachedCollectionPoint> collectionPoints,
  required List<WeightRow> localWeighings,
}) {
  final byAttendance = <String, WeighableWorker>{};
  if (cacheInfo != null && cacheInfo.serverToday == today) {
    for (final w in serverWeighable) {
      byAttendance[w.attendanceId] = WeighableWorker(
        attendanceId: w.attendanceId,
        employeeCode: w.employeeCode,
        fullName: w.fullName,
        estateId: w.estateId,
        cpCode: w.cpCode,
        cpName: w.cpName,
        workType: w.workType,
        variancePercent: w.variancePercent,
        entriesToday: w.entriesToday,
        dailyLimit: w.dailyLimit,
        lastSequence: w.lastSequence,
      );
    }
  }

  final estatesById = {for (final e in estates) e.id: e};
  final weighingRequired = {
    for (final wt in workTypes)
      if (wt.weighingRequired) (wt.estateId, wt.workType),
  };
  final cpNames = {for (final cp in collectionPoints) (cp.estateId, cp.cpCode): cp.name};
  for (final a in localAttendance) {
    final estate = estatesById[a.estateId];
    if (a.attendanceDate != today ||
        a.status == SyncStatus.rejected ||
        byAttendance.containsKey(a.attendanceId) ||
        estate == null ||
        !weighingRequired.contains((a.estateId, a.workType))) {
      continue;
    }
    byAttendance[a.attendanceId] = WeighableWorker(
      attendanceId: a.attendanceId,
      employeeCode: a.employeeCode,
      fullName: a.fullName,
      estateId: a.estateId,
      cpCode: a.cpCode,
      cpName: cpNames[(a.estateId, a.cpCode)],
      workType: a.workType,
      variancePercent: estate.variancePercent,
      entriesToday: 0,
      dailyLimit: estate.maxDailyTransactions,
      lastSequence: 0,
    );
  }

  for (final w in localWeighings) {
    final worker = byAttendance[w.attendanceId];
    if (worker == null || w.status == SyncStatus.rejected) continue;
    final uncounted = w.status == SyncStatus.waiting ||
        cacheInfo == null ||
        cacheInfo.serverToday != today ||
        w.weighedAt.isAfter(cacheInfo.refreshedAt);
    byAttendance[w.attendanceId] =
        worker.withLocal(extraEntries: uncounted ? 1 : 0, lastLocalSequence: w.sequence);
  }

  return byAttendance.values.toList()..sort((a, b) => a.employeeCode.compareTo(b.employeeCode));
}

/// WE-06: greater than 0 with at most 2 decimals; null when the text is not such a weight.
double? parseWeight(String text) {
  final t = text.trim();
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(t)) return null;
  final kg = double.parse(t);
  return kg > 0 ? kg : null;
}

/// The phone-side checks on Save; returns the first problem, or null.
String? validateWeighing({
  required DateTime phoneNow,
  required CacheInfo? cacheInfo,
  required WeighableWorker? worker,
  required String weightText,
  required EntryType? entryType,
  required bool canEnterManually,
}) {
  if (cacheInfo == null) return WeighingMessages.noSiteData;
  // D-10: the phone's date must be the server's date
  if (attendanceDateOf(phoneNow) != attendanceDateOf(cacheInfo.serverNow(phoneNow))) {
    return WeighingMessages.todayOnly;
  }
  if (worker == null) return WeighingMessages.selectWorker; // WE-01
  if (worker.atLimit) return WeighingMessages.limitReached(worker.dailyLimit); // WE-04
  if (entryType == null) return WeighingMessages.entryType;
  if (entryType == EntryType.manual && !canEnterManually) return WeighingMessages.noManual; // WE-08
  if (parseWeight(weightText) == null) return WeighingMessages.weight; // WE-06
  return null;
}
