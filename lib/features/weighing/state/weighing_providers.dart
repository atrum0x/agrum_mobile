import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../attendance/data/attendance_store.dart';
import '../../attendance/domain/attendance_rules.dart';
import '../../auth/state/auth_controller.dart';
import '../../setup/data/setup_cache.dart';
import '../../setup/state/setup_controller.dart';
import '../../sync/state/send_controller.dart';
import '../data/weight_row.dart';
import '../data/weight_store.dart';
import '../domain/weighing_rules.dart';

String? _username(Ref ref) => switch (ref.watch(authControllerProvider)) {
      LoggedIn(:final session) => session.profile.username,
      _ => null,
    };

/// What the weighing screen works from: the cache info and the workers that can be weighed today.
typedef WeighingSource = ({CacheInfo? cacheInfo, List<WeighableWorker> workers});

final weighingSourceProvider = FutureProvider.autoDispose<WeighingSource>((ref) async {
  // Re-read when the cache is refreshed and after each send (Rejected rows free up entries)
  ref.watch(setupControllerProvider.select((s) => s.info?.refreshedAt));
  ref.watch(sendControllerProvider.select((s) => s.revision));
  final username = _username(ref);
  final cache = ref.watch(setupCacheProvider);
  final cacheInfo = await cache.info();
  if (username == null) return (cacheInfo: cacheInfo, workers: const <WeighableWorker>[]);
  final today = attendanceDateOf(DateTime.now());
  return (
    cacheInfo: cacheInfo,
    workers: weighableWorkers(
      today: today,
      cacheInfo: cacheInfo,
      serverWeighable: await cache.weighable(),
      localAttendance: await ref.watch(attendanceStoreProvider).forDate(username, today),
      estates: await cache.estates(),
      workTypes: await cache.allWorkTypes(),
      collectionPoints: await cache.allCollectionPoints(),
      localWeighings: await ref.watch(weightStoreProvider).notRejectedOn(today),
    ),
  );
});

/// Today's weighings by the user on this phone, and earlier days' ones not Sent yet (2.7 item 8).
typedef WeighingList = ({List<WeightRow> today, List<WeightRow> earlier});

final weighingListProvider = FutureProvider.autoDispose<WeighingList>((ref) async {
  ref.watch(sendControllerProvider.select((s) => s.revision));
  final username = _username(ref);
  if (username == null) return (today: const <WeightRow>[], earlier: const <WeightRow>[]);
  final store = ref.watch(weightStoreProvider);
  final today = attendanceDateOf(DateTime.now());
  return (today: await store.forDate(username, today), earlier: await store.unsentBefore(username, today));
});

/// Saves one checked weighing on the phone as Waiting (2.7 step 6) and returns it.
class WeightRecorder {
  WeightRecorder(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  Future<WeightRow?> record({
    required WeighableWorker worker,
    required double weightKg,
    required EntryType entryType,
    IdentifiedBy? identifiedBy,
    double? faceSimilarity,
    Uint8List? photo,
    DateTime? now,
  }) async {
    final auth = _ref.read(authControllerProvider);
    if (auth is! LoggedIn) return null;
    final weighedAt = now ?? DateTime.now();
    final row = WeightRow(
      weightId: _uuid.v4(),
      attendanceId: worker.attendanceId,
      employeeCode: worker.employeeCode,
      fullName: worker.fullName,
      estateId: worker.estateId,
      cpCode: worker.cpCode,
      workType: worker.workType,
      weighDate: attendanceDateOf(weighedAt),
      weighedAt: weighedAt,
      weightKg: weightKg,
      entryType: entryType,
      variancePercent: worker.variancePercent,
      provisionalSequence: worker.nextSequence,
      recordedBy: auth.session.profile.username,
      identifiedBy: identifiedBy,
      faceSimilarity: faceSimilarity,
      photo: photo,
    );
    await _ref.read(weightStoreProvider).save(row);
    _ref.invalidate(weighingSourceProvider);
    _ref.invalidate(weighingListProvider);
    // Saved first; sent straight away when there is a connection (2.7 step 8)
    unawaited(_ref.read(sendControllerProvider.notifier).sendInBackground());
    return row;
  }
}

final weightRecorderProvider = Provider<WeightRecorder>(WeightRecorder.new);
