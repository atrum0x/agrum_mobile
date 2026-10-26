import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/attendance/ui/add_attendance_screen.dart';
import '../features/attendance/ui/attendance_screen.dart';
import '../features/auth/state/auth_controller.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/home/ui/app_shell.dart';
import '../features/home/ui/home_screen.dart';
import '../features/home/ui/more_screen.dart';
import '../features/weighing/ui/weighing_screen.dart';
import 'agrum_logo.dart';

/// Re-runs the router redirect whenever the auth state changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final at = state.matchedLocation;
      return switch (auth) {
        AuthRestoring() => at == '/starting' ? null : '/starting',
        LoggedOut() => at == '/login' ? null : '/login',
        LoggedIn(:final session) => (at == '/login' || at == '/starting') ||
                // A window the user isn't granted, e.g. a stale location after another user logs in
                !AppTab.visibleFor(session.profile).any((tab) => at == tab.path || at.startsWith('${tab.path}/'))
            ? AppTab.home.path
            : null,
      };
    },
    routes: [
      GoRoute(
        path: '/starting',
        builder: (_, _) => const Scaffold(
          backgroundColor: Colors.white,
          body: Center(child: AgrumLogo(size: 160, animated: true)),
        ),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      // Bottom tab bar Home / Attendance / Weighing; each tab keeps its own state (FSD 1.5)
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: AppTab.home.path, builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppTab.attendance.path,
                builder: (_, _) => const AttendanceScreen(),
                routes: [GoRoute(path: 'add', builder: (_, _) => const AddAttendanceScreen())],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppTab.weighing.path, builder: (_, _) => const WeighingScreen())],
          ),
          StatefulShellBranch(routes: [GoRoute(path: AppTab.more.path, builder: (_, _) => const MoreScreen())]),
        ],
      ),
    ],
  );
});
