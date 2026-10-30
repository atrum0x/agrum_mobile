import 'dart:typed_data';

import '../../sync/data/sync_status.dart';

/// FSD 2.7 Entry Type: from the scale, or typed in by a permitted user (WE-08).
enum EntryType {
  automatic('AUTOMATIC', 'Automatic'),
  manual('MANUAL', 'Manual');

  const EntryType(this.code, this.label);

  final String code;
  final String label;

  static EntryType fromCode(String code) => values.firstWhere((t) => t.code == code, orElse: () => manual);
}

/// How the worker was picked on the weighing screen.
enum IdentifiedBy {
  face('FACE'),
  search('SEARCH');

  const IdentifiedBy(this.code);

  final String code;

  static IdentifiedBy? fromCode(String? code) => values.where((v) => v.code == code).firstOrNull;
}

/// One weighing saved on the phone; it cannot be changed or deleted there (2.7 step 9).
class WeightRow {
  const WeightRow({
    required this.weightId,
    required this.attendanceId,
    required this.employeeCode,
    required this.fullName,
    required this.estateId,
    required this.cpCode,
    required this.workType,
    required this.weighDate,
    required this.weighedAt,
    required this.weightKg,
    required this.entryType,
    required this.variancePercent,
    required this.provisionalSequence,
    this.finalSequence,
    required this.recordedBy,
    this.status = SyncStatus.waiting,
    this.reason,
    this.identifiedBy,
    this.faceSimilarity,
    this.photo,
  });

  /// UUID v4 made on the phone, so a resend is recognised (WE-09).
  final String weightId;
  final String attendanceId;
  final String employeeCode;
  final String fullName;
  final String estateId;
  final String? cpCode;
  final String? workType;

  /// The attendance date, yyyy-MM-dd.
  final String weighDate;

  /// Phone time at save.
  final DateTime weighedAt;
  final double weightKg;
  final EntryType entryType;

  /// The site's variance the phone knew; the server applies its own (CL-02).
  final double variancePercent;

  /// The phone's guess (last known + 1); replaced by the server's number when sent (WE-10).
  final int provisionalSequence;
  final int? finalSequence;
  final String recordedBy;
  final SyncStatus status;

  /// The server's reason for a Rejected row.
  final String? reason;

  final IdentifiedBy? identifiedBy;

  /// Face match score, 0-1, when picked by face.
  final double? faceSimilarity;

  /// The recognised face as a small JPEG, kept until the server has it.
  final Uint8List? photo;

  int get sequence => finalSequence ?? provisionalSequence;

  factory WeightRow.fromRow(Map<String, Object?> row) => WeightRow(
        weightId: row['weight_id'] as String,
        attendanceId: row['attendance_id'] as String,
        employeeCode: row['employee_code'] as String,
        fullName: row['full_name'] as String,
        estateId: row['estate_id'] as String,
        cpCode: row['cp_code'] as String?,
        workType: row['work_type'] as String?,
        weighDate: row['weigh_date'] as String? ?? '',
        weighedAt: DateTime.parse(row['weighed_at'] as String),
        weightKg: (row['weight_kg'] as num).toDouble(),
        entryType: EntryType.fromCode(row['entry_type'] as String),
        variancePercent: (row['variance_percent'] as num?)?.toDouble() ?? 0,
        provisionalSequence: row['provisional_sequence'] as int,
        finalSequence: row['final_sequence'] as int?,
        recordedBy: row['recorded_by'] as String,
        status: SyncStatus.fromCode(row['sync_status'] as String),
        reason: row['reason'] as String?,
        identifiedBy: IdentifiedBy.fromCode(row['identified_by'] as String?),
        faceSimilarity: (row['face_similarity'] as num?)?.toDouble(),
        photo: row['photo'] as Uint8List?,
      );

  Map<String, Object?> toRow() => {
        'weight_id': weightId,
        'attendance_id': attendanceId,
        'employee_code': employeeCode,
        'full_name': fullName,
        'estate_id': estateId,
        'cp_code': cpCode,
        'work_type': workType,
        'weigh_date': weighDate,
        'weighed_at': weighedAt.toUtc().toIso8601String(),
        'weight_kg': weightKg,
        'entry_type': entryType.code,
        'variance_percent': variancePercent,
        'provisional_sequence': provisionalSequence,
        'final_sequence': finalSequence,
        'recorded_by': recordedBy,
        'sync_status': status.code,
        'reason': reason,
        'identified_by': identifiedBy?.code,
        'face_similarity': faceSimilarity,
        'photo': photo,
      };
}
