import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class FacePreprocessor {
  /// --------------------------------------------------------------------------
  /// 1. BRIGHTNESS & BLUR GATEKEEPER
  /// --------------------------------------------------------------------------
  /// Checks the face area of the camera's brightness (Y) plane before running ArcFace. Returns what's
  /// wrong with the picture, or null when it's good enough.
  ///
  /// [sensorBox] is the face in the plane's own (sensor) coordinates: see [uprightToSensorRect].
  ///
  /// Sharpness is measured at the scale of the face, not of single pixels: the face is averaged into a
  /// [sharpnessGrid] x [sharpnessGrid] grid and the Laplacian's variance is taken on that. Averaging
  /// wipes out camera noise and a screen's pixel pattern, which made a blurred face filmed off a
  /// screen look sharp pixel by pixel; a real face keeps strong edges (eyes, brows, mouth) at this
  /// scale. Measured: a blurred face 91, real faces 1000-2000, real faces blurred on purpose 300+.
  static String? pictureProblem(
    Uint8List yPlane,
    int bytesPerRow,
    int width,
    int height,
    Rect sensorBox, {
    double minLuminance = 40.0, // 0-255
    double maxLuminance = 220.0,
    double minSharpness = 200.0,
  }) {
    const grid = sharpnessGrid;
    final left = sensorBox.left.clamp(0, width - 1).toDouble();
    final top = sensorBox.top.clamp(0, height - 1).toDouble();
    final right = sensorBox.right.clamp(0, width).toDouble();
    final bottom = sensorBox.bottom.clamp(0, height).toDouble();
    if (right - left < grid || bottom - top < grid) return null;

    final cellW = (right - left) / grid;
    final cellH = (bottom - top) / grid;
    final cells = List<double>.filled(grid * grid, 0);
    var lumaSum = 0.0;
    for (var j = 0; j < grid; j++) {
      final y0 = (top + j * cellH).floor();
      final y1 = math.max((top + (j + 1) * cellH).floor(), y0 + 1);
      for (var i = 0; i < grid; i++) {
        final x0 = (left + i * cellW).floor();
        final x1 = math.max((left + (i + 1) * cellW).floor(), x0 + 1);
        // Every pixel, so the average cancels out as much noise as it can
        var sum = 0, n = 0;
        for (var y = y0; y < y1; y++) {
          final row = y * bytesPerRow;
          for (var x = x0; x < x1; x++) {
            final k = row + x;
            if (k >= yPlane.length) continue;
            sum += yPlane[k];
            n++;
          }
        }
        final mean = n == 0 ? 0.0 : sum / n;
        cells[j * grid + i] = mean;
        lumaSum += mean;
      }
    }

    final luma = lumaSum / (grid * grid);
    if (luma < minLuminance) return 'Too dark. Move to better light';
    if (luma > maxLuminance) return 'Too bright. Move out of direct light';

    var lapSum = 0.0, lapSquares = 0.0, count = 0;
    for (var j = 1; j < grid - 1; j++) {
      for (var i = 1; i < grid - 1; i++) {
        final c = cells[j * grid + i];
        final lap = 4 * c -
            cells[(j - 1) * grid + i] -
            cells[(j + 1) * grid + i] -
            cells[j * grid + i - 1] -
            cells[j * grid + i + 1];
        lapSum += lap;
        lapSquares += lap * lap;
        count++;
      }
    }
    final lapMean = lapSum / count;
    final sharpness = lapSquares / count - lapMean * lapMean;
    if (sharpness < minSharpness) return 'Picture is blurred. Hold the camera steady';
    return null;
  }

  static const sharpnessGrid = 24;

  /// Maps a box from the upright picture ML Kit reports in, back to the camera sensor's picture,
  /// which is [width]×[height] and turned [rotationDegrees] clockwise to stand upright.
  static Rect uprightToSensorRect(Rect box, int rotationDegrees, int width, int height) {
    Offset toSensor(double u, double v) => switch (rotationDegrees) {
          90 => Offset(v, height - u),
          180 => Offset(width - u, height - v),
          270 => Offset(width - v, u),
          _ => Offset(u, v),
        };
    return Rect.fromPoints(toSensor(box.left, box.top), toSensor(box.right, box.bottom));
  }

  /// The face as a small JPEG for records: the box with some margin, made square, [size] px wide.
  /// Not aligned, so it looks like what the camera saw.
  static Uint8List facePhotoJpeg(img.Image upright, Rect box, {int size = 240, int quality = 80}) {
    final side = math.max(box.width, box.height) * 1.4;
    final x = (box.center.dx - side / 2).clamp(0, upright.width - 1).toInt();
    final y = (box.center.dy - side / 2).clamp(0, upright.height - 1).toInt();
    final w = math.min(side.round(), upright.width - x);
    final h = math.min(side.round(), upright.height - y);
    final crop = img.copyCrop(upright, x: x, y: y, width: w, height: h);
    final small = crop.width > size ? img.copyResize(crop, width: size, interpolation: img.Interpolation.average) : crop;
    return img.encodeJpg(small, quality: quality);
  }

  /// --------------------------------------------------------------------------
  /// 2. FIVE-POINT ALIGNMENT (what ArcFace was trained on)
  /// --------------------------------------------------------------------------
  /// Where the eyes, nose tip and mouth corners sit in ArcFace's 112x112 input, left to right as seen
  /// in the picture (InsightFace's reference points).
  static const arcFaceTemplate = <(double, double)>[
    (38.2946, 51.6963), // eye, picture left
    (73.5318, 51.5014), // eye, picture right
    (56.0252, 71.7366), // nose tip
    (41.5493, 92.3655), // mouth corner, picture left
    (70.7299, 92.2041), // mouth corner, picture right
  ];

  /// The face ready for ArcFace: lined up on its five landmarks when ML Kit found them all, which
  /// gives the model faces in the same place, size and angle every time; otherwise the box crop.
  static img.Image? alignFace(img.Image src, Face face, {int size = 112}) {
    final points = fiveLandmarks(face);
    if (points == null) return alignAndCropFace(src, face, targetSize: size);
    return warpToTemplate(src, points, size: size);
  }

  /// ML Kit's eyes, nose base and mouth corners in [arcFaceTemplate] order. ML Kit names them from
  /// the person's side, so they are ordered by where they are in the picture instead.
  static List<(double, double)>? fiveLandmarks(Face face) {
    (double, double)? at(FaceLandmarkType type) {
      final p = face.landmarks[type]?.position;
      return p == null ? null : (p.x.toDouble(), p.y.toDouble());
    }

    final eyeA = at(FaceLandmarkType.leftEye);
    final eyeB = at(FaceLandmarkType.rightEye);
    final nose = at(FaceLandmarkType.noseBase);
    final mouthA = at(FaceLandmarkType.leftMouth);
    final mouthB = at(FaceLandmarkType.rightMouth);
    if (eyeA == null || eyeB == null || nose == null || mouthA == null || mouthB == null) return null;
    final (eyeL, eyeR) = eyeA.$1 <= eyeB.$1 ? (eyeA, eyeB) : (eyeB, eyeA);
    final (mouthL, mouthR) = mouthA.$1 <= mouthB.$1 ? (mouthA, mouthB) : (mouthB, mouthA);
    return [eyeL, eyeR, nose, mouthL, mouthR];
  }

  /// Rotates, scales and moves [src] so [points] land as close as they can on [arcFaceTemplate]
  /// (least-squares similarity transform: no stretching), sampled into a [size]x[size] image.
  static img.Image warpToTemplate(img.Image src, List<(double, double)> points, {int size = 112}) {
    final scale = size / 112;
    final dst = [for (final (x, y) in arcFaceTemplate) (x * scale, y * scale)];

    // Fit dst = M * src + t with M = [[a, -b], [b, a]], around the centres of both point sets
    var sx = 0.0, sy = 0.0, dx = 0.0, dy = 0.0;
    for (var i = 0; i < points.length; i++) {
      sx += points[i].$1;
      sy += points[i].$2;
      dx += dst[i].$1;
      dy += dst[i].$2;
    }
    final n = points.length;
    sx /= n;
    sy /= n;
    dx /= n;
    dy /= n;
    var num1 = 0.0, num2 = 0.0, den = 0.0;
    for (var i = 0; i < n; i++) {
      final px = points[i].$1 - sx, py = points[i].$2 - sy;
      final qx = dst[i].$1 - dx, qy = dst[i].$2 - dy;
      num1 += px * qx + py * qy;
      num2 += px * qy - py * qx;
      den += px * px + py * py;
    }
    final a = num1 / den, b = num2 / den;

    // Each output pixel comes from the inverse transform: src = M^-1 * (out - centre_dst) + centre_src
    final inv = 1 / (a * a + b * b);
    final out = img.Image(width: size, height: size);
    for (var v = 0; v < size; v++) {
      for (var u = 0; u < size; u++) {
        final ox = u - dx, oy = v - dy;
        final x = (a * ox + b * oy) * inv + sx;
        final y = (-b * ox + a * oy) * inv + sy;
        final (r, g, bl) = _bilinear(src, x, y);
        out.setPixelRgb(u, v, r, g, bl);
      }
    }
    return out;
  }

  // Black outside the picture, as a face near the frame edge would be padded
  static (int, int, int) _bilinear(img.Image src, double x, double y) {
    if (x < 0 || y < 0 || x > src.width - 1 || y > src.height - 1) return (0, 0, 0);
    final x0 = x.floor(), y0 = y.floor();
    final x1 = math.min(x0 + 1, src.width - 1), y1 = math.min(y0 + 1, src.height - 1);
    final fx = x - x0, fy = y - y0;
    final p00 = src.getPixel(x0, y0), p10 = src.getPixel(x1, y0);
    final p01 = src.getPixel(x0, y1), p11 = src.getPixel(x1, y1);
    int mix(num c00, num c10, num c01, num c11) =>
        ((c00 * (1 - fx) + c10 * fx) * (1 - fy) + (c01 * (1 - fx) + c11 * fx) * fy).round().clamp(0, 255);
    return (
      mix(p00.r, p10.r, p01.r, p11.r),
      mix(p00.g, p10.g, p01.g, p11.g),
      mix(p00.b, p10.b, p01.b, p11.b),
    );
  }

  /// --------------------------------------------------------------------------
  /// 3. EYE LANDMARK ALIGNMENT & CROPPING (fallback when landmarks are missing)
  /// --------------------------------------------------------------------------
  /// Aligns eyes horizontally and crops standard 112x112 ArcFace input tensor.
  static img.Image? alignAndCropFace(
    img.Image srcImage,
    Face face, {
    int targetSize = 112,
    double marginRatio = 0.15,
  }) {
    final rect = face.boundingBox;

    // 1. Calculate bounding box crop coordinates with margin
    final double marginX = rect.width * marginRatio;
    final double marginY = rect.height * marginRatio;

    int x = (rect.left - marginX).clamp(0, srcImage.width - 1).toInt();
    int y = (rect.top - marginY).clamp(0, srcImage.height - 1).toInt();
    int w = (rect.width + (marginX * 2)).toInt();
    int h = (rect.height + (marginY * 2)).toInt();

    if (x + w > srcImage.width) w = srcImage.width - x;
    if (y + h > srcImage.height) h = srcImage.height - y;

    if (w <= 0 || h <= 0) return null;

    // 2. Crop face region first (much faster than rotating entire frame)
    img.Image cropped = img.copyCrop(srcImage, x: x, y: y, width: w, height: h);

    // 3. Perform rotational alignment if eyes are detected
    final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;

    if (leftEye != null && rightEye != null) {
      // ML Kit's leftEye is the person's left, which is on the right of an unmirrored image, so
      // measure from whichever eye is further left in the picture instead of trusting the names.
      final (a, b) = leftEye.x <= rightEye.x ? (leftEye, rightEye) : (rightEye, leftEye);

      // Tilt of the eye line in degrees; y points down, so positive means turned clockwise
      final double angle = math.atan2((b.y - a.y).toDouble(), (b.x - a.x).toDouble()) * (180 / math.pi);

      if (angle.abs() > 1.0) {
        // Rotate a larger square from the full frame, so the box cut out afterwards is real picture
        // and not the empty corners a rotation leaves.
        final cx = x + w / 2;
        final cy = y + h / 2;
        final half = math.max(w, h) * 0.75;
        final bx = (cx - half).clamp(0, srcImage.width - 1).toInt();
        final by = (cy - half).clamp(0, srcImage.height - 1).toInt();
        final bw = math.min((cx + half).ceil(), srcImage.width) - bx;
        final bh = math.min((cy + half).ceil(), srcImage.height) - by;
        final big = img.copyCrop(srcImage, x: bx, y: by, width: bw, height: bh);

        // copyRotate turns clockwise for a positive angle, so turn back the other way. It rotates
        // around the image centre and grows the canvas; find where the face centre lands.
        final rotated = img.copyRotate(big, angle: -angle, interpolation: img.Interpolation.linear);
        final rad = -angle * math.pi / 180;
        final sx = cx - bx - bw / 2;
        final sy = cy - by - bh / 2;
        final fx = rotated.width / 2 + sx * math.cos(rad) - sy * math.sin(rad);
        final fy = rotated.height / 2 + sx * math.sin(rad) + sy * math.cos(rad);

        final rx = (fx - w / 2).round().clamp(0, rotated.width - 1);
        final ry = (fy - h / 2).round().clamp(0, rotated.height - 1);
        cropped = img.copyCrop(
          rotated,
          x: rx,
          y: ry,
          width: math.min(w, rotated.width - rx),
          height: math.min(h, rotated.height - ry),
        );
      }
    }

    // 4. Resize to standard 112x112 input dimensions for ArcFace
    return img.copyResize(
      cropped,
      width: targetSize,
      height: targetSize,
      interpolation: img.Interpolation.linear,
    );
  }
}