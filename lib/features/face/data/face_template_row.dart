import 'dart:convert';
import 'dart:typed_data';

import '../../sync/data/sync_status.dart';

/// One worker's registered face: the mean ArcFace embedding of the captured poses.
class FaceTemplateRow {
  const FaceTemplateRow({
    required this.employeeCode,
    required this.embedding,
    required this.sampleCount,
    required this.registeredAt,
    required this.registeredBy,
    required this.status,
    this.reason,
  });

  /// The model the phone runs; the server keeps it so templates from another model are never mixed.
  static const model = 'arcface_512';
  static const dimensions = 512;

  final String employeeCode;
  final List<double> embedding;
  final int sampleCount;
  final DateTime registeredAt;
  final String registeredBy;
  final SyncStatus status;
  final String? reason;

  /// 512 float32 values, little-endian: the BLOB on the phone and, as base64, the server's format.
  static Uint8List encode(List<double> embedding) {
    final data = ByteData(embedding.length * 4);
    for (var i = 0; i < embedding.length; i++) {
      data.setFloat32(i * 4, embedding[i], Endian.little);
    }
    return data.buffer.asUint8List();
  }

  static List<double> decode(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    return [for (var i = 0; i < bytes.length ~/ 4; i++) data.getFloat32(i * 4, Endian.little)];
  }

  Map<String, Object?> toRow() => {
        'employee_code': employeeCode,
        'embedding': encode(embedding),
        'sample_count': sampleCount,
        'registered_at': registeredAt.toUtc().toIso8601String(),
        'registered_by': registeredBy,
        'sync_status': status.code,
        'reason': reason,
      };

  factory FaceTemplateRow.fromRow(Map<String, Object?> row) => FaceTemplateRow(
        employeeCode: row['employee_code']! as String,
        embedding: decode(row['embedding']! as Uint8List),
        sampleCount: row['sample_count']! as int,
        registeredAt: DateTime.parse(row['registered_at']! as String),
        registeredBy: row['registered_by']! as String,
        status: SyncStatus.fromCode(row['sync_status']! as String),
        reason: row['reason'] as String?,
      );

  /// What POST /api/face-templates/sync takes.
  Map<String, Object?> toJson() => {
        'employeeCode': employeeCode,
        'model': model,
        'embedding': base64Encode(encode(embedding)),
        'sampleCount': sampleCount,
        'registeredAt': registeredAt.toUtc().toIso8601String(),
      };

  /// From GET /api/face-templates; null when it isn't usable here (another model or size).
  static FaceTemplateRow? fromServer(Map<String, dynamic> json) {
    if (json['model'] != model) return null;
    final embedding = decode(base64Decode(json['embedding'] as String));
    if (embedding.length != dimensions) return null;
    return FaceTemplateRow(
      employeeCode: json['employeeCode'] as String,
      embedding: embedding,
      sampleCount: json['sampleCount'] as int,
      registeredAt: DateTime.parse(json['registeredAt'] as String),
      registeredBy: (json['registeredBy'] as String?) ?? '',
      status: SyncStatus.sent,
    );
  }
}
