import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:agrum_mobile/core/db/app_database.dart';
import 'package:agrum_mobile/features/attendance/data/attendance_store.dart';
import 'package:agrum_mobile/features/face/data/face_preprocessor.dart';
import 'package:agrum_mobile/features/face/data/face_recognizer.dart';
import 'package:agrum_mobile/features/face/data/face_store.dart';
import 'package:agrum_mobile/features/face/data/face_sync_api.dart';
import 'package:agrum_mobile/features/face/data/face_template_row.dart';
import 'package:agrum_mobile/features/face/data/in_memory_face_processor.dart';
import 'package:agrum_mobile/features/sync/data/sync_engine.dart';
import 'package:agrum_mobile/features/sync/data/sync_status.dart';
import 'package:agrum_mobile/features/weighing/data/weight_row.dart';
import 'package:agrum_mobile/features/weighing/data/weight_store.dart';
import 'package:camera/camera.dart';
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

    test('five-point alignment puts eyes, nose and mouth where ArcFace expects them', () {
      // The template's points, turned 20° and scaled 2.5x into a bigger picture, as a tilted face
      const angle = 20 * pi / 180;
      const s = 2.5;
      (double, double) place((double, double) p) => (
            150 + s * (cos(angle) * p.$1 - sin(angle) * p.$2),
            40 + s * (sin(angle) * p.$1 + cos(angle) * p.$2),
          );
      final image = img.Image(width: 400, height: 400)..clear(img.ColorRgb8(255, 255, 255));
      final placed = [for (final p in FacePreprocessor.arcFaceTemplate) place(p)];
      for (final (x, y) in placed) {
        img.fillCircle(image, x: x.round(), y: y.round(), radius: 6, color: img.ColorRgb8(0, 0, 0));
      }
      Point<int> pt((double, double) p) => Point(p.$1.round(), p.$2.round());
      // ML Kit names eyes and mouth corners from the person's side: their left is on the picture right
      final face = Face(
        boundingBox: const Rect.fromLTWH(0, 0, 400, 400),
        contours: const {},
        landmarks: {
          FaceLandmarkType.leftEye: FaceLandmark(type: FaceLandmarkType.leftEye, position: pt(placed[1])),
          FaceLandmarkType.rightEye: FaceLandmark(type: FaceLandmarkType.rightEye, position: pt(placed[0])),
          FaceLandmarkType.noseBase: FaceLandmark(type: FaceLandmarkType.noseBase, position: pt(placed[2])),
          FaceLandmarkType.leftMouth: FaceLandmark(type: FaceLandmarkType.leftMouth, position: pt(placed[4])),
          FaceLandmarkType.rightMouth: FaceLandmark(type: FaceLandmarkType.rightMouth, position: pt(placed[3])),
        },
      );

      final out = FacePreprocessor.alignFace(image, face)!;
      expect(out.width, 112);
      for (final (tx, ty) in FacePreprocessor.arcFaceTemplate) {
        final c = centroid(out, (x, y) => (x - tx).abs() < 9 && (y - ty).abs() < 9);
        expect(c.x, closeTo(tx, 1.5));
        expect(c.y, closeTo(ty, 1.5));
      }
    });

    test('without all five landmarks it falls back to the box crop', () {
      expect(FacePreprocessor.fiveLandmarks(mlKitFace()), isNull);
      expect(FacePreprocessor.alignFace(drawFace(), mlKitFace())!.width, 112);
    });

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

  group('matching', () {
    // Unit vectors in 2 of the 512 dimensions, at a chosen angle from the probe
    List<double> at(double cosine) {
      final v = List<double>.filled(FaceTemplateRow.dimensions, 0);
      v[0] = cosine;
      v[1] = sqrt(1 - cosine * cosine);
      return v;
    }

    final probe = at(1);

    test('the closest face wins when it is clearly ahead', () {
      final match = bestMatch(probe, {'E001': at(0.80), 'E002': at(0.50)});
      expect(match.success, isTrue);
      expect(match.employeeCode, 'E001');
    });

    test('two faces almost as close: no guess', () {
      final match = bestMatch(probe, {'E001': at(0.80), 'E002': at(0.76)});
      expect(match.success, isFalse);
      expect(match.error, 'Not sure who this is');
    });

    test('below the threshold: not recognised, however far ahead', () {
      final match = bestMatch(probe, {'E001': at(0.40), 'E002': at(0.0)});
      expect(match.success, isFalse);
      expect(match.error, 'Face not recognised');
    });

    test('registration poses of one face agree; a pose of something else does not', () {
      final front = at(1);
      final turned = [at(0.9), at(0.85), at(0.95), at(0.88)];
      expect(posesAgree([front, ...turned]), isTrue);

      // e.g. the first pose was a blurred picture: not like the others
      final other = List<double>.filled(FaceTemplateRow.dimensions, 0)..[2] = 1;
      expect(posesAgree([other, ...turned]), isFalse);
    });

    test('one registered face only needs the threshold', () {
      expect(bestMatch(probe, {'E001': at(0.65)}).employeeCode, 'E001');
    });

    test('two different men at 0.44 (measured on the app model) are not a match', () {
      final match = bestMatch(probe, {'E001': at(0.44)});
      expect(match.success, isFalse);
      expect(match.error, 'Face not recognised');
    });
  });

  group('picture checks', () {
    test('an upright box maps back onto the sensor picture', () {
      // Sensor 640x480 turned 90° clockwise is a 480x640 upright picture
      const box = Rect.fromLTRB(100, 200, 180, 300);
      expect(FacePreprocessor.uprightToSensorRect(box, 0, 640, 480), box);
      expect(FacePreprocessor.uprightToSensorRect(box, 90, 640, 480), const Rect.fromLTRB(200, 300, 300, 380));
      expect(FacePreprocessor.uprightToSensorRect(box, 180, 640, 480), const Rect.fromLTRB(460, 180, 540, 280));
      expect(FacePreprocessor.uprightToSensorRect(box, 270, 640, 480), const Rect.fromLTRB(340, 100, 440, 180));
    });

    // A 200x200 Y plane with 8 bytes of row padding; the face box is 120 px wide
    const w = 200, h = 200, stride = 208;
    const faceBox = Rect.fromLTRB(40, 40, 160, 160);
    String? check(Uint8List bytes) => FacePreprocessor.pictureProblem(bytes, stride, w, h, faceBox);

    Uint8List plane(int Function(int x, int y) luma) {
      final bytes = Uint8List(stride * h);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          bytes[y * stride + x] = luma(x, y).clamp(0, 255);
        }
      }
      return bytes;
    }

    /// Skin with dark brows, eyes and mouth, like a face at arm's length.
    img.Image drawnFace() {
      final face = img.Image(width: w, height: h)..clear(img.ColorRgb8(170, 170, 170));
      final dark = img.ColorRgb8(60, 60, 60);
      img.fillRect(face, x1: 62, y1: 72, x2: 92, y2: 78, color: dark);
      img.fillRect(face, x1: 108, y1: 72, x2: 138, y2: 78, color: dark);
      img.fillCircle(face, x: 77, y: 92, radius: 7, color: dark);
      img.fillCircle(face, x: 123, y: 92, radius: 7, color: dark);
      img.fillRect(face, x1: 96, y1: 100, x2: 104, y2: 120, color: img.ColorRgb8(130, 130, 130));
      img.fillRect(face, x1: 80, y1: 132, x2: 120, y2: 138, color: dark);
      return face;
    }

    Uint8List planeOf(img.Image image, {int noise = 0}) {
      final random = Random(1);
      return plane((x, y) => image.getPixel(x, y).r.toInt() + (noise == 0 ? 0 : random.nextInt(2 * noise + 1) - noise));
    }

    test('a sharp face passes', () {
      expect(check(planeOf(drawnFace())), isNull);
    });

    test('a blurred face is blurred', () {
      final blurred = img.gaussianBlur(drawnFace(), radius: 14);
      expect(check(planeOf(blurred)), 'Picture is blurred. Hold the camera steady');
    });

    test('pixel noise on a blurred face (camera grain, a screen filmed) does not make it sharp', () {
      final blurred = img.gaussianBlur(drawnFace(), radius: 14);
      expect(check(planeOf(blurred, noise: 15)), 'Picture is blurred. Hold the camera steady');
    });

    test('noise does not stop a sharp face passing', () {
      expect(check(planeOf(drawnFace(), noise: 15)), isNull);
    });

    test('dark and bright faces are named as such', () {
      expect(check(plane((x, y) => (x + y).isEven ? 10 : 30)), 'Too dark. Move to better light');
      expect(check(plane((x, y) => (x + y).isEven ? 230 : 250)), 'Too bright. Move out of direct light');
    });
  });

  test('a camera frame and an ML Kit face can go to a background isolate for the crop', () async {
    // A grey 640x480 YUV420 frame laid out like Android's: separate U and V planes, 2 bytes apart
    const w = 640, h = 480;
    // ignore: deprecated_member_use
    final frame = CameraImage.fromPlatformData({
      'format': 35, // ImageFormat.YUV_420_888
      'width': w,
      'height': h,
      'planes': [
        {'bytes': Uint8List(w * h)..fillRange(0, w * h, 128), 'bytesPerRow': w, 'bytesPerPixel': 1},
        for (var i = 0; i < 2; i++)
          {'bytes': Uint8List(w * h ~/ 2)..fillRange(0, w * h ~/ 2, 128), 'bytesPerRow': w, 'bytesPerPixel': 2},
      ],
    });
    final face = Face(
      boundingBox: const Rect.fromLTWH(140, 200, 200, 200),
      contours: const {},
      landmarks: {
        FaceLandmarkType.leftEye: FaceLandmark(type: FaceLandmarkType.leftEye, position: const Point(290, 260)),
        FaceLandmarkType.rightEye: FaceLandmark(type: FaceLandmarkType.rightEye, position: const Point(190, 270)),
      },
    );

    final tensor = await Isolate.run(() => InMemoryFaceProcessor.processFrameToTensor(
          image: frame,
          face: face,
          sensorOrientation: 90,
        ));

    expect(tensor.length, 112 * 112 * 3);
    // Mid grey stays near 0 after the [-1, 1] scaling
    expect(tensor.every((v) => v.abs() < 0.05), isTrue);
  });

  group('photos', () {
    test('the face photo is a small JPEG around the face', () {
      final frame = img.Image(width: 480, height: 640)..clear(img.ColorRgb8(120, 120, 120));
      final jpeg = FacePreprocessor.facePhotoJpeg(frame, const Rect.fromLTWH(140, 200, 200, 220));
      expect(jpeg.sublist(0, 2), [0xFF, 0xD8]);
      final decoded = img.decodeJpg(jpeg)!;
      expect(decoded.width, 240);
      expect(decoded.height, 240);
    });

    test('photos are sent with the record and dropped from the phone once the server has them', () async {
      final db = await AppDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      addTearDown(db.close);
      final api = FakeAttendanceApi();
      final weights = WeightStore(Future.value(db));
      final faces = FaceStore(Future.value(db));
      final engine = SyncEngine(
        attendance: AttendanceStore(Future.value(db)),
        attendanceApi: api,
        weights: weights,
        weightApi: FakeWeightApi(api.order),
        faces: faces,
        faceApi: FakeFaceApi(api.order),
      );
      final photo = Uint8List.fromList([0xFF, 0xD8, 1, 2]);
      final w = weighing('w1');
      await weights.save(WeightRow(
        weightId: w.weightId,
        attendanceId: w.attendanceId,
        employeeCode: w.employeeCode,
        fullName: w.fullName,
        estateId: w.estateId,
        cpCode: w.cpCode,
        workType: w.workType,
        weighDate: w.weighDate,
        weighedAt: w.weighedAt,
        weightKg: w.weightKg,
        entryType: w.entryType,
        variancePercent: w.variancePercent,
        provisionalSequence: w.provisionalSequence,
        recordedBy: w.recordedBy,
        identifiedBy: IdentifiedBy.face,
        faceSimilarity: 0.81,
        photo: photo,
      ));
      final f = face('E001');
      await faces.save(FaceTemplateRow(
        employeeCode: f.employeeCode,
        embedding: f.embedding,
        sampleCount: f.sampleCount,
        registeredAt: f.registeredAt,
        registeredBy: f.registeredBy,
        status: SyncStatus.waiting,
        photo: photo,
      ));
      expect((await weights.forDate('sup01', '2026-10-24')).single.photo, photo);
      expect(f.toJson().containsKey('photo'), isFalse);

      await engine.run('sup01');

      final sent = (await weights.forDate('sup01', '2026-10-24')).single;
      expect(sent.status, SyncStatus.sent);
      expect(sent.identifiedBy, IdentifiedBy.face);
      expect(sent.faceSimilarity, 0.81);
      expect(sent.photo, isNull);
      final sentFace = (await faces.all()).single;
      expect(sentFace.status, SyncStatus.sent);
      expect(sentFace.photo, isNull);
    });
  });
}
