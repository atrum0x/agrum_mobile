import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/theme.dart';
import '../../auth/state/auth_controller.dart';
import '../../auth/state/fingerprint_controller.dart';
import '../../auth/ui/fingerprint_ui.dart';
import '../../face/state/face_providers.dart';
import '../../setup/state/setup_controller.dart';
import '../../sync/state/send_controller.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../shared/widgets/language_picker.dart';

final _dateTime = DateFormat('dd/MM/yyyy HH:mm');

/// The More tab: who is logged in, sending in words, site data, fingerprint login, and Logout.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth is! LoggedIn) return const SizedBox.shrink();
    final theme = ShadTheme.of(context);
    final profile = auth.session.profile;
    final send = ref.watch(sendControllerProvider);
    final setup = ref.watch(setupControllerProvider);
    final fingerprint = ref.watch(fingerprintControllerProvider);
    final faces = ref.watch(registeredFacesProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.accent,
                  child: Text(
                    profile.displayName.characters.first.toUpperCase(),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.displayName, style: theme.textTheme.large),
                      Text(profile.username, style: theme.textTheme.muted),
                    ],
                  ),
                ),
              ],
            ),
            if (auth.session.offline) ...[
              const SizedBox(height: 12),
              _Line(
                icon: LucideIcons.wifiOff,
                color: AppColors.pending,
                text: tr.loggedInOfflineNotice,
              ),
            ],
          ],
        ),
        _Section(
          title: tr.sending,
          children: [
            _Line(
              icon: send.waiting > 0 ? LucideIcons.cloudUpload : LucideIcons.cloudCheck,
              color: send.waiting > 0 ? AppColors.pending : AppColors.primary,
              text: send.waiting > 0 ? tr.recordsWaiting(send.waiting) : tr.nothingWaiting,
            ),
            if (send.activity ?? send.result?.message case final message?) ...[
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  fontSize: 16,
                  color: send.result?.isError == true && send.activity == null
                      ? AppColors.destructive
                      : AppColors.mutedForeground,
                ),
              ),
            ],
            const SizedBox(height: 12),
            ShadButton(
              height: 48,
              width: double.infinity,
              enabled: !send.sending,
              leading: const Icon(LucideIcons.send, size: 20),
              onPressed: () => ref.read(sendControllerProvider.notifier).sendNow(),
              child: Text(tr.sendNow, style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
        _Section(
          title: tr.siteData,
          children: [
            _Line(
              icon: LucideIcons.database,
              color: setup.info == null ? AppColors.pending : AppColors.primary,
              text: switch (setup) {
                SetupState(refreshing: true) => tr.updating,
                SetupState(:final info?) => tr.downloadedAt(_dateTime.format(info.refreshedAt.toLocal())),
                _ => tr.notDownloadedYet,
              },
            ),
            if (setup.error case final error?) ...[
              const SizedBox(height: 8),
              Text(tr.lastUpdateFailed(error), style: const TextStyle(fontSize: 16, color: AppColors.destructive)),
            ],
          ],
        ),
        if (profile.canRegisterFaces)
          _Section(
            title: tr.faceRegistration,
            children: [
              _Line(
                icon: LucideIcons.scanFace,
                color: faces.isEmpty ? AppColors.pending : AppColors.primary,
                text: faces.isEmpty ? tr.noFacesOnPhone : tr.facesOnPhone(faces.length),
              ),
              const SizedBox(height: 12),
              ShadButton.outline(
                height: 48,
                width: double.infinity,
                leading: const Icon(LucideIcons.scanFace, size: 20),
                onPressed: () => context.go('/more/faces'),
                child: Text(tr.registerFace, style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
        if (fingerprint.loaded && fingerprint.available)
          _Section(title: tr.loginSection, children: [FingerprintSetting(username: profile.username)]),
        _Section(title: tr.language, children: const [LanguagePicker()]),
        const SizedBox(height: 8),
        ShadButton.outline(
          height: 52,
          width: double.infinity,
          leading: const Icon(LucideIcons.logOut, size: 20),
          onPressed: () => _confirmLogout(context, ref),
          child: Text(tr.logout, style: const TextStyle(fontSize: 16)),
        ),
      ],
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog.alert(
        title: Text(tr.logoutTitle),
        description: Text(tr.logoutBody),
        actions: [
          ShadButton.outline(
            height: 48,
            child: Text(tr.cancel),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ShadButton(height: 48, child: Text(tr.logout), onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );
    if (confirmed == true) await ref.read(authControllerProvider.notifier).logout();
  }
}

class _Section extends StatelessWidget {
  const _Section({this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(title!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
      ],
    );
  }
}
