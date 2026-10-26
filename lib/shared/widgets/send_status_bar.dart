import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/theme.dart';
import '../../features/setup/state/setup_controller.dart';
import '../../features/sync/state/send_controller.dart';

final _dateTime = DateFormat('dd/MM/yyyy HH:mm');

/// FSD 8 / 10.5: the waiting-to-send count and Send Now, under the header on every window,
/// with when the site data was last downloaded (5.4).
class SendStatusBar extends ConsumerWidget {
  const SendStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final send = ref.watch(sendControllerProvider);
    final setup = ref.watch(setupControllerProvider);
    final theme = ShadTheme.of(context);

    final waiting = send.waiting;
    final info = setup.info;
    final String dataLine;
    final bool dataMissing = info == null;
    if (setup.refreshing) {
      dataLine = 'Updating site data…';
    } else if (info == null) {
      dataLine = 'Site data not downloaded yet';
    } else {
      dataLine = 'Site data ${_dateTime.format(info.refreshedAt.toLocal())}';
    }

    Future<void> sendNow() async {
      final result = await ref.read(sendControllerProvider.notifier).sendNow();
      if (result == null || !context.mounted) return;
      ShadToaster.of(context).show(result.isError
          ? ShadToast.destructive(description: Text(result.message))
          : ShadToast(description: Text(result.message)));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Icon(
            waiting > 0 ? LucideIcons.cloudUpload : LucideIcons.cloudCheck,
            color: waiting > 0 ? AppColors.pending : AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  waiting > 0 ? '$waiting waiting to send' : 'Nothing waiting to send',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: waiting > 0 ? AppColors.pending : AppColors.foreground,
                  ),
                ),
                Text(
                  dataLine,
                  style: theme.textTheme.muted.copyWith(color: dataMissing ? AppColors.pending : null),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ShadButton(
            height: 48,
            enabled: !send.sending,
            onPressed: sendNow,
            leading: send.sending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(LucideIcons.send, size: 18),
            child: const Text('Send Now', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
