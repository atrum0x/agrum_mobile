import 'package:agrum_mobile/features/auth/data/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile profile(List<String> permissions, {bool superuser = false}) => UserProfile(
      username: 'sup01',
      employeeName: 'Nimal Perera',
      superuser: superuser,
      permissions: permissions.toSet(),
    );

void main() {
  test('TC-03: attendance grants only show only Attendance', () {
    final p = profile(['POST:/api/attendance/sync', 'GET:/api/attendance/workers']);
    expect(p.canRecordAttendance, isTrue);
    expect(p.canRecordWeights, isFalse);
    expect(p.hasMobileAccess, isTrue);
  });

  test('LG-05: web-only grants give no access to the phone', () {
    expect(profile(['GET:/api/weights/history']).hasMobileAccess, isFalse);
  });

  test('superuser can do everything', () {
    final p = profile(const [], superuser: true);
    expect(p.canRecordAttendance && p.canRecordWeights && p.canEnterWeightManually, isTrue);
  });

  test('CL-03 rights are their own grants', () {
    final p = profile(['POST:/api/weights/sync', 'POST:/api/weights/manual']);
    expect(p.canEnterWeightManually, isTrue);
    expect(p.canRecordOtherSite, isFalse);
  });

  test('reads the /me/mobile reply and round-trips', () {
    final p = UserProfile.fromJson({
      'username': 'sup01',
      'employeeName': null,
      'superuser': false,
      'permissions': ['POST:/api/attendance/sync'],
    });
    expect(p.displayName, 'sup01');
    expect(UserProfile.fromJson(p.toJson()).permissions, p.permissions);
  });
}
