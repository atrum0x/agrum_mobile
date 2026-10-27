import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../auth/state/auth_controller.dart';
import '../../setup/data/setup_cache.dart';
import '../../setup/data/setup_data.dart';
import '../../setup/state/setup_controller.dart';
import '../../sync/state/send_controller.dart';
import '../../weighing/state/weighing_providers.dart';
import '../data/attendance_row.dart';
import '../data/attendance_store.dart';
import '../domain/attendance_rules.dart';

String? _username(Ref ref) => switch (ref.watch(authControllerProvider)) {
      LoggedIn(:final session) => session.profile.username,
      _ => null,
    };

/// FSD 2.6 step 1: today's attendance recorded by the user on this phone, with Sync Status.
final todayAttendanceProvider = FutureProvider.autoDispose<List<AttendanceRow>>((ref) async {
  ref.watch(sendControllerProvider.select((s) => s.revision));
  final username = _username(ref);
  if (username == null) return const [];
  return ref.watch(attendanceStoreProvider).forDate(username, attendanceDateOf(DateTime.now()));
});

/// Earlier days' rows that are still Waiting or were Rejected, so they don't drop out of sight.
final earlierUnsentAttendanceProvider = FutureProvider.autoDispose<List<AttendanceRow>>((ref) async {
  ref.watch(sendControllerProvider.select((s) => s.revision));
  final username = _username(ref);
  if (username == null) return const [];
  return ref.watch(attendanceStoreProvider).unsentBefore(username, attendanceDateOf(DateTime.now()));
});

/// What the Add Attendance form starts from, read from the 5.4 cache.
class AttendanceFormSource {
  const AttendanceFormSource({
    required this.cacheInfo,
    required this.estates,
    required this.workers,
    required this.markedToday,
  });

  final CacheInfo? cacheInfo;
  final List<CachedEstate> estates;

  /// Not yet marked today, as far as the server knew at the last refresh.
  final List<CachedWorker> workers;

  /// Workers marked on this phone today and not rejected (AT-02 before the server knows).
  final Set<String> markedToday;

  /// Workers that can still be ticked.
  List<CachedWorker> get available => workers.where((w) => !markedToday.contains(w.employeeCode)).toList();
}

final attendanceFormSourceProvider = FutureProvider.autoDispose<AttendanceFormSource>((ref) async {
  // Re-read when the cache is refreshed
  ref.watch(setupControllerProvider.select((s) => s.info?.refreshedAt));
  // A Rejected row frees the worker to be marked again
  ref.watch(sendControllerProvider.select((s) => s.revision));
  final cache = ref.watch(setupCacheProvider);
  return AttendanceFormSource(
    cacheInfo: await cache.info(),
    estates: await cache.estates(),
    workers: await cache.workers(),
    markedToday: await ref.watch(attendanceStoreProvider).markedOn(attendanceDateOf(DateTime.now())),
  );
});

typedef SiteLists = ({List<CachedWorkType> workTypes, List<CachedCollectionPoint> collectionPoints});

final siteListsProvider = FutureProvider.autoDispose.family<SiteLists, String>((ref, estateId) async {
  final cache = ref.watch(setupCacheProvider);
  return (workTypes: await cache.workTypes(estateId), collectionPoints: await cache.collectionPoints(estateId));
});

/// Saves a checked batch on the phone, one Waiting row per worker (FSD 2.6 step 6).
class AttendanceRecorder {
  AttendanceRecorder(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  Future<void> record({
    required String estateId,
    required String workType,
    required String cpCode,
    required List<BatchWorker> workers,
    DateTime? now,
  }) async {
    final auth = _ref.read(authControllerProvider);
    if (auth is! LoggedIn) return;
    final recordedAt = now ?? DateTime.now();
    final rows = [
      for (final w in workers)
        AttendanceRow(
          attendanceId: _uuid.v4(),
          employeeCode: w.worker.employeeCode,
          fullName: w.worker.fullName,
          estateId: estateId,
          workType: workType,
          cpCode: cpCode,
          category: w.category!,
          attendanceDate: attendanceDateOf(recordedAt),
          recordedAt: recordedAt,
          recordedBy: auth.session.profile.username,
        ),
    ];
    await _ref.read(attendanceStoreProvider).saveBatch(rows);
    _ref.invalidate(todayAttendanceProvider);
    _ref.invalidate(earlierUnsentAttendanceProvider);
    _ref.invalidate(attendanceFormSourceProvider);
    // The workers can now be weighed (2.7)
    _ref.invalidate(weighingSourceProvider);
    // Saved first; sent straight away when there is a connection (2.6 step 6)
    unawaited(_ref.read(sendControllerProvider.notifier).sendInBackground());
  }
}

final attendanceRecorderProvider = Provider<AttendanceRecorder>(AttendanceRecorder.new);
