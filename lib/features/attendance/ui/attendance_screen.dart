import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/sync_status_badge.dart';
import '../../sync/data/sync_status.dart';
import '../data/attendance_row.dart';
import '../state/attendance_providers.dart';

final _date = DateFormat('dd/MM/yyyy');
final _time = DateFormat('HH:mm');

/// FSD 2.6 step 1: today's attendance on this phone with its Sync Status, and Add Attendance.
/// Saved rows have no change option (TC-37).
class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final rows = ref.watch(todayAttendanceProvider);
    final earlier = ref.watch(earlierUnsentAttendanceProvider).value ?? const <AttendanceRow>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Expanded(child: Text('Today, ${_date.format(DateTime.now())}', style: theme.textTheme.h4)),
              if (rows.value case final list? when list.isNotEmpty)
                Text('${list.length} workers', style: theme.textTheme.muted),
            ],
          ),
        ),
        Expanded(
          child: switch (rows) {
            AsyncData(:final value) when value.isEmpty && earlier.isEmpty => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No attendance recorded today on this phone.',
                    style: theme.textTheme.muted,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            AsyncData(:final value) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  for (final row in value) _AttendanceTile(row: row),
                  if (earlier.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                      child: Text('Earlier days, not sent', style: theme.textTheme.large),
                    ),
                    for (final row in earlier) _AttendanceTile(row: row, showDate: true),
                  ],
                ],
              ),
            AsyncError(:final error) => Center(child: Text('$error', style: theme.textTheme.muted)),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ShadButton(
            height: 52,
            width: double.infinity,
            gradient: AppColors.headerGradient,
            shadows: AppColors.buttonShadows,
            leading: const Icon(LucideIcons.userPlus, size: 22),
            onPressed: () => context.go('/attendance/add'),
            child: const Text('Add Attendance', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }
}

class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile({required this.row, this.showDate = false});

  final AttendanceRow row;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final recorded = row.recordedAt.toLocal();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: row.status == SyncStatus.rejected ? AppColors.destructive : AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${row.fullName} (${row.employeeCode})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              SyncStatusBadge(status: row.status),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${row.estateId} · ${row.workType} · ${row.cpCode} · ${row.category.label} · '
            '${showDate ? '${_date.format(recorded)} ' : ''}${_time.format(recorded)}',
            style: theme.textTheme.muted,
          ),
          if (row.status == SyncStatus.rejected && row.reason != null) ...[
            const SizedBox(height: 4),
            Text(row.reason!, style: const TextStyle(fontSize: 16, color: AppColors.destructive)),
          ],
        ],
      ),
    );
  }
}
