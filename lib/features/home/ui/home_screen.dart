import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/theme.dart';
import '../../../core/connectivity.dart';
import '../../auth/state/auth_controller.dart';

/// FSD 2.1 Mobile Home: Attendance and Weighing buttons (only those the user is granted),
/// the send status and Logout. The windows themselves come in later steps.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth is! LoggedIn) return const SizedBox.shrink();
    final profile = auth.session.profile;
    final theme = ShadTheme.of(context);

    void comingSoon(String window) => ShadToaster.of(context).show(ShadToast(
          title: Text(window),
          description: const Text('This window is not built yet.'),
        ));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Agrum', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: 'Logout',
            iconSize: 24,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(LucideIcons.logOut),
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Hello, ${profile.displayName}', style: theme.textTheme.h3),
            const SizedBox(height: 8),
            _ConnectionStatus(offlineLogin: auth.session.offline),
            const SizedBox(height: 24),
            if (profile.canRecordAttendance)
              _WindowButton(
                icon: LucideIcons.clipboardCheck,
                label: 'Attendance',
                hint: 'Mark today\'s workers present',
                onPressed: () => comingSoon('Attendance'),
              ),
            if (profile.canRecordAttendance && profile.canRecordWeights) const SizedBox(height: 16),
            if (profile.canRecordWeights)
              _WindowButton(
                icon: LucideIcons.scale,
                label: 'Weighing',
                hint: 'Weigh pluckers\' tea',
                onPressed: () => comingSoon('Weighing'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog.alert(
        title: const Text('Log out?'),
        description: const Text('Records saved on this phone are kept and sent after you log in again.'),
        actions: [
          ShadButton.outline(height: 48, child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)),
          ShadButton(height: 48, child: const Text('Logout'), onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );
    if (confirmed == true) await ref.read(authControllerProvider.notifier).logout();
  }
}

class _ConnectionStatus extends ConsumerWidget {
  const _ConnectionStatus({required this.offlineLogin});

  final bool offlineLogin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineProvider).value ?? true;
    final color = online ? AppColors.primary : AppColors.pending;
    final text = online
        ? (offlineLogin ? 'Online · logged in offline' : 'Online')
        : 'Offline · records are saved on this phone';
    return Row(
      children: [
        Icon(online ? LucideIcons.wifi : LucideIcons.wifiOff, color: color, size: 20),
        const SizedBox(width: 8),
        Flexible(child: Text(text, style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.w500))),
      ],
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({required this.icon, required this.label, required this.hint, required this.onPressed});

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ShadButton(
      width: double.infinity,
      height: 112,
      onPressed: onPressed,
      mainAxisAlignment: MainAxisAlignment.start,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon, size: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          Text(hint, style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.85))),
        ],
      ),
    );
  }
}
