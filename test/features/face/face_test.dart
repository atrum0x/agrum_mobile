import 'dart:math';
import 'dart:ui';

import 'package:agrum_mobile/core/db/app_database.dart';
import 'package:agrum_mobile/features/attendance/data/attendance_store.dart';
import 'package:agrum_mobile/features/face/data/face_preprocessor.dart';
import 'package:agrum_mobile/features/face/data/face_store.dart';
import 'package:agrum_mobile/features/face/data/face_sync_api.dart';
import 'package:agrum_mobile/features/face/data/face_template_row.dart';
import 'package:agrum_mobile/features/sync/data/sync_engine.dart';
import 'package:agrum_mobile/features/sync/data/sync_status.dart';
import 'package:agrum_mobile/features/weighing/data/weight_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../sync/sync_engine_test.dart' show FakeAttendanceApi, FakeWeightApi, weighing;

/// Answers like POST /api/face-templates/sync.
class FakeFaceApi implements FaceSyncApi {
  FakeFaceApi(this.log);

  final List<String> log;
  final rejections = <String, String>{};

  @override
  Future<List<FaceTemplateRow>> fetch() async => const [];

  @override
  Future<List<FaceSyncResult>> send(List<FaceTemplateRow> rows) async {
    log.addAll(rows.map((r) => 'face:${r.employeeCode}'));
    return [
      for (final r in rows)
        (
          id: r.employeeCode,
          status: rejections.containsKey(r.employeeCode) ? SyncStatus.rejected : SyncStatus.sent,
          reason: rejections[r.employeeCode],
        ),
    ];
  }
}

FaceTemplateRow face(String code, {SyncStatus status = SyncStatus.waiting, double value = 0.5, String by = 'sup01'}) =>
    FaceTemplateRow(
      employeeCode: code,
      embedding: List.filled(FaceTemplateRow.dimensions, value),
      sampleCount: 5,
      registeredAt: DateTime.utc(2026, 10, 30, 4),
      registeredBy: by,
      status: status,
    );

void main() {
  sqfliteFfiInit();

  group('template encoding', () {
    test('float32 bytes survive the round trip, and base64 is what the server stores', () {
      final values = [for (var i = 0; i < FaceTemplateRow.dimensions; i++) (i - 256) / 1024];
      final bytes = FaceTemplateRow.encode(values);
      expect(bytes.length, FaceTemplateRow.dimensions * 4);
      expect(FaceTemplateRow.decode(bytes), values);

      final json = face('E001').toJson();
      final back = FaceTemplateRow.fromServer({...json, 'registeredBy': 'sup01'})!;
      expect(back.employeeCode, 'E001');
      expect(back.status, SyncStatus.sent);
      expect(back.embedding, face('E001').embedding);
    });

    test('a template from another model is ignored', () {
      expect(FaceTemplateRow.fromServer({...face('E001').toJson(), 'model': 'facenet_128'}), isNull);
    });
  });

  group('FaceStore', () {
    late Database db;
    late FaceStore store;

    setUp(() async {
      db = await AppDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      store = FaceStore(Future.value(db));
    });
    tearDown(() => db.close());

    test('downloaded faces replace Sent ones but never a registration not sent yet', () async {
      await store.save(face('E001', status: SyncStatus.sent, value: 0.1));
      await store.save(face('E002', status: SyncStatus.sent));
      await store.save(face('E003', status: SyncStatus.waiting, value: 0.3));

      await store.replaceSent([
        face('E001', status: SyncStatus.sent, value: 0.9),
        face('E003', status: SyncStatus.sent, value: 0.9),
      ]);

      final rows = {for (final r in await store.all()) r.employeeCode: r};
      // E002 is no longer on the server (e.g. left), so it's gone
      expect(rows.keys, ['E001', 'E003']);
      expect(rows['E001']!.embedding.first, closeTo(0.9, 1e-6));
      expect(rows['E003']!.status, SyncStatus.waiting);
      expect(rows['E003']!.embedding.first, closeTo(0.3, 1e-6));
    });
  });

  group('sending', () {
    test('faces go after attendance and weighings; a rejected face keeps its reason', () async {
      final db = await AppDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      addTearDown(db.close);
      final api = FakeAttendanceApi();
      final weights = WeightStore(Future.value(db));
      final faces = FaceStore(Future.value(db));
      final faceApi = FakeFaceApi(api.order)..rejections['E404'] = 'Employee E404 does not exist.';
      final engine = SyncEngine(
        attendance: AttendanceStore(Future.value(db)),
        attendanceApi: api,
        weights: weights,
        weightApi: FakeWeightApi(api.order),
        faces: faces,
        faceApi: faceApi,
      );
      await faces.save(face('E001'));
      await faces.save(face('E404'));
      await faces.save(face('E999', by: 'someoneElse'));
      await weights.save(weighing('w1'));

      final outcome = await engine.run('sup01');

      expect(api.order, ['w1', 'face:E001', 'face:E404']);
      expect(outcome.sent, 2);
      expect(outcome.rejected, 1);
      final rows = {for (final r in await faces.all()) r.employeeCode: r};
      expect(rows['E001']!.status, SyncStatus.sent);
      expect(rows['E404']!.status, SyncStatus.rejected);
      expect(rows['E404']!.reason, 'Employee E404 does not exist.');
      expect(rows['E999']!.status, SyncStatus.waiting);
    });
  });

  group('eye alignment', () {
    // A 200×200 "face": two eyes on a line tilted ~14° clockwise and a mouth below them
    img.Image drawFace() {
      final image = img.Image(width: 200, height: 200)..clear(img.ColorRgb8(255, 255, 255));
      final black = img.ColorRgb8(0, 0, 0);
      img.fillCircle(image, x: 60, y: 90, radius: 5, color: black);
      img.fillCircle(image, x: 140, y: 110, radius: 5, color: black);
      img.fillCircle(image, x: 100, y: 150, radius: 5, color: black);
      return image;
    }

    Face mlKitFace() => Face(
          boundingBox: const Rect.fromLTWH(40, 40, 120, 120),
          contours: const {},
          // ML Kit names eyes from the person's side: their left eye is on the right of the image
          landmarks: {
            FaceLandmarkType.leftEye: FaceLandmark(type: FaceLandmarkType.leftEye, position: const Point(140, 110)),
            FaceLandmarkType.rightEye: FaceLandmark(type: FaceLandmarkType.rightEye, position: const Point(60, 90)),
          },
        );

    /// Centre of the dark pixels in the region.
    Point<double> centroid(img.Image image, bool Function(int x, int y) inRegion) {
      var sx = 0.0, sy = 0.0, n = 0;
      for (final p in image) {
        if (p.r < 100 && inRegion(p.x, p.y)) {
          sx += p.x;
          sy += p.y;
          n++;
        }
      }
      expect(n, greaterThan(0));
      return Point(sx / n, sy / n);
    }

    test('levels the eyes and keeps the face upright', () {
      final out = FacePreprocessor.alignAndCropFace(drawFace(), mlKitFace(), targetSize: 112)!;
      expect(out.width, 112);
      expect(out.height, 112);

      final leftEye = centroid(out, (x, y) => x < 56 && y < 74);
      final rightEye = centroid(out, (x, y) => x >= 56 && y < 74);
      final mouth = centroid(out, (x, y) => y >= 74);

      expect((leftEye.y - rightEye.y).abs(), lessThan(2), reason: 'eye line should be level');
      expect(mouth.y, greaterThan(leftEye.y + 20), reason: 'mouth should stay below the eyes');
    });
  });
}
