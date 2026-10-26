import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../auth/state/auth_controller.dart';
import 'app_shell.dart';

/// FSD 2.1 Mobile Home: Attendance and Weighing buttons (only those the user is granted).
/// The header, send status and tab bar come from AppShell.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth is! LoggedIn) return const SizedBox.shrink();
    final profile = auth.session.profile;
    final theme = ShadTheme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Hello, ${profile.displayName}', style: theme.textTheme.h3),
        const SizedBox(height: 24),
        if (profile.canRecordAttendance)
          _WindowButton(
            icon: LucideIcons.clipboardCheck,
            label: 'Attendance',
            hint: 'Mark today\'s workers present',
            onPressed: () => context.go(AppTab.attendance.path),
          ),
        if (profile.canRecordAttendance && profile.canRecordWeights) const SizedBox(height: 16),
        if (profile.canRecordWeights)
          _WindowButton(
            icon: LucideIcons.scale,
            label: 'Weighing',
            hint: 'Weigh pluckers\' tea',
            onPressed: () => context.go(AppTab.weighing.path),
          ),
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
