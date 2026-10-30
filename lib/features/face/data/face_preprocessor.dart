import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class FacePreprocessor {
  /// --------------------------------------------------------------------------
  /// 1. BRIGHTNESS & BLUR GATEKEEPER
  /// --------------------------------------------------------------------------
  /// Validates frame quality BEFORE running expensive ArcFace inference.
  static bool isFrameQualityValid(
    CameraImage cameraImage,
    Face face, {
    double minLuminance = 40.0,  // Lower bound for darkness (0-255 scale)
    double maxLuminance = 220.0, // Upper bound for overexposure (0-255 scale)
    double minBlurVar = 100.0,   // Laplacian variance threshold for blur
  }) {
    final rect = face.boundingBox;

    // Fast bounds safety check against camera dimensions
    final left = rect.left.toInt().clamp(0, cameraImage.width - 1);
    final top = rect.top.toInt().clamp(0, cameraImage.height - 1);
    final right = rect.right.toInt().clamp(0, cameraImage.width);
    final bottom = rect.bottom.toInt().clamp(0, cameraImage.height);

    final width = right - left;
    final height = bottom - top;
    if (width <= 0 || height <= 0) return false;

    // Access Y plane (Luminance) directly from raw YUV420 stream without decoding
    final yPlane = cameraImage.planes[0];
    final rowStride = yPlane.bytesPerRow;
    final bytes = yPlane.bytes;

    double totalLuminance = 0;
    int pixelCount = 0;
    final List<int> ySamples = [];

    for (int y = top; y < bottom; y += 2) { // Step by 2 for speed
      for (int x = left; x < right; x += 2) {
        final index = (y * rowStride) + x;
        if (index < bytes.length) {
          final luma = bytes[index];
          totalLuminance += luma;
          ySamples.add(luma);
          pixelCount++;
        }
      }
    }

    if (pixelCount == 0) return false;

    // A. Check Average Brightness
    final avgLuminance = totalLuminance / pixelCount;
    if (avgLuminance < minLuminance || avgLuminance > maxLuminance) {
      return false; // Frame is too dark or overexposed
    }

    // B. Check Blur via Variance of Laplacian Approximation
    double mean = avgLuminance;
    double sumVariance = 0;
    for (var val in ySamples) {
      sumVariance += (val - mean) * (val - mean);
    }
    double variance = sumVariance / pixelCount;

    if (variance < minBlurVar) {
      return false; // Frame is motion blurred or out of focus
    }

    return true;
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