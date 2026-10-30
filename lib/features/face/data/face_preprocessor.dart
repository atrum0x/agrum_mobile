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
  /// Blur is the variance of the Laplacian, which is low when edges are soft (motion or focus); plain
  /// contrast would also pass a blurred face in strong light.
  static String? pictureProblem(
    Uint8List yPlane,
    int bytesPerRow,
    int width,
    int height,
    Rect sensorBox, {
    double minLuminance = 40.0, // 0-255
    double maxLuminance = 220.0,
    double minSharpness = 15.0, // Laplacian variance; tune on real phones
  }) {
    // One pixel in from the edge, so every sample has all four neighbours
    final left = sensorBox.left.floor().clamp(1, width - 2);
    final top = sensorBox.top.floor().clamp(1, height - 2);
    final right = sensorBox.right.ceil().clamp(1, width - 1);
    final bottom = sensorBox.bottom.ceil().clamp(1, height - 1);
    if (right <= left || bottom <= top) return null;

    var lumaSum = 0.0;
    var lapSum = 0.0;
    var lapSquares = 0.0;
    var n = 0;
    for (var y = top; y < bottom; y += 2) {
      final row = y * bytesPerRow;
      for (var x = left; x < right; x += 2) {
        final i = row + x;
        if (i + bytesPerRow >= yPlane.length) continue;
        final c = yPlane[i];
        final lap = 4 * c - yPlane[i - 1] - yPlane[i + 1] - yPlane[i - bytesPerRow] - yPlane[i + bytesPerRow];
        lumaSum += c;
        lapSum += lap;
        lapSquares += lap * lap;
        n++;
      }
    }
    if (n == 0) return null;

    final luma = lumaSum / n;
    if (luma < minLuminance) return 'Too dark. Move to better light';
    if (luma > maxLuminance) return 'Too bright. Move out of direct light';

    final lapMean = lapSum / n;
    final sharpness = lapSquares / n - lapMean * lapMean;
    if (sharpness < minSharpness) return 'Picture is blurred. Hold the camera steady';
    return null;
  }

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
  /// 2. EYE LANDMARK ALIGNMENT & CROPPING
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