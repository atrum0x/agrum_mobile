import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../features/sync/data/sync_status.dart';

/// FSD 8: amber for pending, green for sent, red only for errors.
class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key, required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SyncStatus.waiting => AppColors.pending,
      SyncStatus.sent => AppColors.primary,
      SyncStatus.rejected => AppColors.destructive,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(status.label, style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.w500)),
    );
  }
}
