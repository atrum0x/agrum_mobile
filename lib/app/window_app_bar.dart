import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../core/connectivity.dart';
import '../features/auth/state/auth_controller.dart';
import 'agrum_logo.dart';
import 'theme.dart';

/// Header for every window: a black-to-green gradient with the logo and the window's name on
/// the left, online/offline and Logout on the right (FSD 8: online status always visible,
/// Logout on every screen).
class WindowAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const WindowAppBar({super.key, required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return AppBar(
      // The gradient is painted by flexibleSpace; keep Material 3 from tinting it on scroll.
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      // flexibleSpace gets loose height constraints, so a bare DecoratedBox would be 0 px tall
      // and the transparent bar would show the white page; expand it to fill the bar.
      flexibleSpace: const SizedBox.expand(
        child: DecoratedBox(decoration: BoxDecoration(gradient: AppColors.headerGradient)),
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false,
      leading: const Padding(padding: EdgeInsets.only(left: 12), child: AgrumLogo(size: 36)),
      leadingWidth: 52,
      titleSpacing: 8,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      actions: [
        _ConnectionStatus(offlineLogin: auth is LoggedIn && auth.session.offline),
        IconButton(
          tooltip: 'Logout',
          iconSize: 24,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(LucideIcons.logOut),
          onPressed: () => _confirmLogout(context, ref),
        ),
      ],
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog.alert(
        title: const Text('Log out?'),
        description: const Text('Records saved on this phone are kept and sent after you log in again.'),
        actions: [
          ShadButton.outline(
            height: 48,
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ShadButton(height: 48, child: const Text('Logout'), onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );
    if (confirmed == true) await ref.read(authControllerProvider.notifier).logout();
  }
}

/// A compact chip that fits in the app bar; the longer explanation is its tooltip.
class _ConnectionStatus extends ConsumerWidget {
  const _ConnectionStatus({required this.offlineLogin});

  final bool offlineLogin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineProvider).value ?? true;
    final color = online ? Colors.white : AppColors.pendingOnDark;
    final tooltip = online
        ? (offlineLogin ? 'Online · logged in offline' : 'Online')
        : 'Offline · records are saved on this phone';
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(online ? LucideIcons.wifi : LucideIcons.wifiOff, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              online ? 'Online' : 'Offline',
              style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
