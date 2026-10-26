import '../../sync/data/sync_status.dart';

/// FSD 2.6 Attendance Category.
enum AttendanceCategory {
  regular('REGULAR', 'Regular'),
  seasonal('SEASONAL', 'Seasonal'),
  lent('LENT', 'Lent'),
  borrowed('BORROWED', 'Borrowed');

  const AttendanceCategory(this.code, this.label);

  final String code;
  final String label;

  static AttendanceCategory? fromCode(String? code) {
    for (final category in values) {
      if (category.code == code) return category;
    }
    return null;
  }
}

/// One worker's attendance saved on the phone; it cannot be changed after submission (TC-37).
class AttendanceRow {
  const AttendanceRow({
    required this.attendanceId,
    required this.employeeCode,
    required this.fullName,
    required this.estateId,
    required this.workType,
    required this.cpCode,
    required this.category,
    required this.attendanceDate,
    required this.recordedAt,
    required this.recordedBy,
    this.status = SyncStatus.waiting,
    this.reason,
  });

  /// UUID v4 made on the phone, so a resend is recognised (AT-12).
  final String attendanceId;
  final String employeeCode;
  final String fullName;
  final String estateId;
  final String workType;
  final String cpCode;
  final AttendanceCategory category;

  /// yyyy-MM-dd
  final String attendanceDate;
  final DateTime recordedAt;
  final String recordedBy;
  final SyncStatus status;

  /// The server's reason for a Rejected row.
  final String? reason;

  factory AttendanceRow.fromRow(Map<String, Object?> row) => AttendanceRow(
        attendanceId: row['attendance_id'] as String,
        employeeCode: row['employee_code'] as String,
        fullName: row['full_name'] as String,
        estateId: row['estate_id'] as String,
        workType: row['work_type'] as String,
        cpCode: row['cp_code'] as String,
        category: AttendanceCategory.fromCode(row['category'] as String) ?? AttendanceCategory.regular,
        attendanceDate: row['attendance_date'] as String,
        recordedAt: DateTime.parse(row['recorded_at'] as String),
        recordedBy: row['recorded_by'] as String,
        status: SyncStatus.fromCode(row['sync_status'] as String),
        reason: row['reason'] as String?,
      );

  Map<String, Object?> toRow() => {
        'attendance_id': attendanceId,
        'employee_code': employeeCode,
        'full_name': fullName,
        'estate_id': estateId,
        'work_type': workType,
        'cp_code': cpCode,
        'category': category.code,
        'attendance_date': attendanceDate,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
        'recorded_by': recordedBy,
        'sync_status': status.code,
        'reason': reason,
      };
}
