import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/window_app_bar.dart';
import '../../auth/data/user_profile.dart';
import '../../auth/state/auth_controller.dart';
import 'notched_tab_bar.dart';

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
  static const more = AppTab(3, 'More', LucideIcons.ellipsis, '/more');

  /// A window's tab shows only if the user may use that window (FSD 2.1, TC-03).
  static List<AppTab> visibleFor(UserProfile profile) => [
        home,
        if (profile.canRecordAttendance) attendance,
        if (profile.canRecordWeights) weighing,
        more,
      ];
}

/// Every window after login: the header (with send status), the window, and the tab bar (FSD 1.5).
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
      body: shell,
      bottomNavigationBar: NotchedTabBar(
        tabs: tabs,
        selected: selected,
        onSelect: (i) => shell.goBranch(tabs[i].branch),
      ),
    );
  }
}
