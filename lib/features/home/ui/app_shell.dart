import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/theme.dart';
import '../../../app/window_app_bar.dart';
import '../../../shared/widgets/send_status_bar.dart';
import '../../auth/data/user_profile.dart';
import '../../auth/state/auth_controller.dart';

/// A bottom tab; [branch] is its index in the router's StatefulShellRoute.
class AppTab {
  const AppTab(this.branch, this.label, this.icon, this.path);

  final int branch;
  final String label;
  final IconData icon;
  final String path;

  static const home = AppTab(0, 'Home', LucideIcons.house, '/home');
  static const attendance = AppTab(1, 'Attendance', LucideIcons.clipboardCheck, '/attendance');
  static const weighing = AppTab(2, 'Weighing', LucideIcons.scale, '/weighing');

  /// A window's tab shows only if the user may use that window (FSD 2.1, TC-03).
  static List<AppTab> visibleFor(UserProfile profile) => [
        home,
        if (profile.canRecordAttendance) attendance,
        if (profile.canRecordWeights) weighing,
      ];
}

/// Every window after login: the header, the send status, the window, and the tab bar (FSD 1.5).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth is! LoggedIn) return const SizedBox.shrink();
    final tabs = AppTab.visibleFor(auth.session.profile);
    final current = tabs.indexWhere((t) => t.branch == shell.currentIndex);
    final selected = current < 0 ? 0 : current;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: WindowAppBar(title: tabs[selected].label),
      body: Column(
        children: [
          const SendStatusBar(),
          Expanded(child: shell),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: AppColors.accent,
          height: 72,
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
                fontSize: 16,
                fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
                color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.mutedForeground,
              )),
          iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
                size: 24,
                color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.mutedForeground,
              )),
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
          child: NavigationBar(
            selectedIndex: selected,
            surfaceTintColor: Colors.transparent,
            onDestinationSelected: (i) => shell.goBranch(tabs[i].branch),
            destinations: [
              for (final tab in tabs) NavigationDestination(icon: Icon(tab.icon), label: tab.label),
            ],
          ),
        ),
      ),
    );
  }
}
