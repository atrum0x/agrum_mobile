import 'package:agrum_mobile/features/auth/data/user_profile.dart';
import 'package:agrum_mobile/features/home/ui/app_shell.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile profile(Set<String> permissions, {bool superuser = false}) =>
    UserProfile(username: 'sup01', employeeName: null, superuser: superuser, permissions: permissions);

void main() {
  test('both windows granted: Home, Attendance, Weighing (TC-01)', () {
    final tabs = AppTab.visibleFor(profile({'POST:/api/attendance/sync', 'POST:/api/weights/sync'}));
    expect(tabs, [AppTab.home, AppTab.attendance, AppTab.weighing]);
  });

  test('only attendance granted: no Weighing tab (TC-03)', () {
    expect(AppTab.visibleFor(profile({'POST:/api/attendance/sync'})), [AppTab.home, AppTab.attendance]);
  });

  test('only weighing granted: no Attendance tab', () {
    expect(AppTab.visibleFor(profile({'POST:/api/weights/sync'})), [AppTab.home, AppTab.weighing]);
  });

  test('the superuser sees every tab', () {
    expect(AppTab.visibleFor(profile({}, superuser: true)).length, 3);
  });
}
