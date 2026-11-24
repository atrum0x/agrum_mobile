import 'package:agrum_mobile/core/i18n/app_language.dart';
import 'package:agrum_mobile/core/i18n/app_strings.dart';
import 'package:agrum_mobile/features/attendance/domain/attendance_rules.dart';
import 'package:agrum_mobile/features/sync/data/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => setCurrentStrings(AppLanguage.en.strings));

  test('the phone-side messages follow the chosen language', () {
    setCurrentStrings(AppLanguage.si.strings);
    expect(AttendanceMessages.division, 'කරුණාකර කොට්ඨාසය තෝරන්න.');
    expect(SyncStatus.sent.label, 'යැවිණි');

    setCurrentStrings(AppLanguage.ta.strings);
    expect(AttendanceMessages.division, 'பிரிவைத் தேர்ந்தெடுக்கவும்.');

    setCurrentStrings(AppLanguage.en.strings);
    expect(AttendanceMessages.division, 'Please select the Division.');
  });

  test('Sinhala and Tamil are not left in English', () {
    const en = AppLanguage.en;
    for (final language in [AppLanguage.si, AppLanguage.ta]) {
      final s = language.strings;
      expect(s.tabAttendance, isNot(en.strings.tabAttendance));
      expect(s.atField, isNot(en.strings.atField));
      expect(s.attendanceConfirm(3), contains('3'));
      expect(s.weSaved('E001', 2, '13.00'), allOf(contains('E001'), contains('13.00')));
    }
  });

  test('every face camera message is translated where it is shown', () {
    const messages = [
      'Only one person at a time',
      'Move closer',
      'Move back a little',
      'Center your face in frame',
      'Straighten your head',
      'Adjust head angle',
      'Good',
      'Too dark. Move to better light',
      'Too bright. Move out of direct light',
      'Picture is blurred. Hold the camera steady',
    ];
    final ta = AppLanguage.ta.strings;
    for (final message in messages) {
      expect(AppLanguage.en.strings.faceGuidance(message), message);
      expect(ta.faceGuidance(message), isNot(message));
    }
    // Anything else is shown as it came
    expect(ta.faceGuidance('Something new'), 'Something new');
  });

  test('a stored language code is read back, and an unknown one falls back to English', () {
    expect(AppLanguage.fromCode('ta'), AppLanguage.ta);
    expect(AppLanguage.fromCode(null), AppLanguage.en);
    expect(AppLanguage.fromCode('fr'), AppLanguage.en);
  });
}
