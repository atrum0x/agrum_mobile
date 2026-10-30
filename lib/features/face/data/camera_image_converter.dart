import 'dart:io';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'face_preprocessor.dart';
import '../domain/face_quality.dart';

// Everything needed to turn a raw [CameraImage] (YUV420, the cross-platform
// format we request from CameraController) into something usable, both for
// ML Kit (which wants an [InputImage]) and for FaceNet (which wants a JPEG
// file path).
//
// IMPORTANT: a YUV420 CameraImage on Android is NOT directly usable by
// either consumer. It arrives as 3 separate planes (Y, U, V) with their own
// row strides and pixel strides, which can include padding bytes ML Kit and
// JPEG encoders don't expect. Both conversions below account for that
// explicitly instead of assuming a flat byte buffer.

const _deviceOrientations = <DeviceOrientation, int>{
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// Computes how many degrees of rotation compensation are needed so the
/// image content appears upright, taking into account both the physical
/// sensor mounting angle (`camera.sensorOrientation`) and the current
/// device rotation. Front cameras are mirrored on the sensor, so the
/// compensation direction flips relative to the back camera.
int rotationCompensationDegrees(
  CameraDescription camera,
  DeviceOrientation deviceOrientation,
) {
  final baseRotation = _deviceOrientations[deviceOrientation] ?? 0;
  if (camera.lensDirection == CameraLensDirection.front) {
    return (camera.sensorOrientation + baseRotation) % 360;
  }
  return (camera.sensorOrientation - baseRotation + 360) % 360;
}

/// Converts a 3-plane YUV420 [CameraImage] into a single packed NV21 byte
/// buffer, which is the format ML Kit's Android face detector actually
/// expects when constructed via [InputImage.fromBytes]. We can't just hand
/// ML Kit the raw planes - Android's yuv420 planes commonly have row/pixel
/// strides with padding, and U/V come as separate planes rather than
/// interleaved, so a manual, stride-aware copy is required.
Uint8List _yuv420ToNv21(CameraImage image) {
  final width = image.width;
  final height = image.height;

  final yPlane = image.planes[0];
  final uPlane = image.planes[1];
  final vPlane = image.planes[2];

  final ySize = width * height;
  final uvSize = (width * height) ~/ 2;
  final nv21 = Uint8List(ySize + uvSize);

  // --- Y plane: copy row by row, skipping any row padding (bytesPerRow may
  // be wider than `width`) ---
  var outputOffset = 0;
  for (int row = 0; row < height; row++) {
    final rowStart = row * yPlane.bytesPerRow;
    nv21.setRange(outputOffset, outputOffset + width, yPlane.bytes, rowStart);
    outputOffset += width;
  }

  // --- U/V planes: NV21 wants them interleaved as V,U,V,U... at half
  // horizontal and vertical resolution. Respect each plane's own row/pixel
  // stride rather than assuming they're tightly packed. ---
  final uvRowStride = uPlane.bytesPerRow;
  final uvPixelStride = uPlane.bytesPerPixel ?? 1;

  for (int row = 0; row < height ~/ 2; row++) {
    for (int col = 0; col < width ~/ 2; col++) {
      final uvIndex = row * uvRowStride + col * uvPixelStride;
      final vIndex = row * vPlane.bytesPerRow + col * uvPixelStride;
      nv21[outputOffset++] = vPlane.bytes[vIndex]; // V first
      nv21[outputOffset++] = uPlane.bytes[uvIndex]; // then U
    }
  }

  return nv21;
}

/// Builds an ML Kit [InputImage] from a live [CameraImage] frame, with
/// correct rotation metadata for the current device orientation.
///
/// Returns null if rotation/format can't be resolved for this frame - the
/// caller should just skip that frame rather than crash.
InputImage? buildInputImage(
  CameraImage image,
  CameraDescription camera,
  DeviceOrientation deviceOrientation,
) {
  final rotationDegrees = rotationCompensationDegrees(camera, deviceOrientation);
  final rotation = InputImageRotationValue.fromRawValue(rotationDegrees);
  if (rotation == null) return null;

  if (Platform.isAndroid) {
    final nv21Bytes = _yuv420ToNv21(image);
    return InputImage.fromBytes(
      bytes: nv21Bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        // NV21 is a single packed buffer, so its row stride is just the width.
        bytesPerRow: image.width,
      ),
    );
  }

  // iOS delivers a single BGRA8888 plane already - no manual conversion needed.
  final plane = image.planes.first;
  return InputImage.fromBytes(
    bytes: plane.bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: InputImageFormat.bgra8888,
      bytesPerRow: plane.bytesPerRow,
    ),
  );
}

/// Converts a YUV420 [CameraImage] into an [img.Image] using the standard
/// BT.601 YUV -> RGB formula, honoring each plane's row/pixel stride.
///
/// This only ever runs on the single frame chosen for FaceNet verification
/// or registration - never on every stream frame - because it's noticeably
/// more expensive than the lightweight NV21 copy used for ML Kit.
img.Image _yuv420ToImage(CameraImage image) {
  final width = image.width;
  final height = image.height;

  final yPlane = image.planes[0];
  final uPlane = image.planes[1];
  final vPlane = image.planes[2];

  final yRowStride = yPlane.bytesPerRow;
  final uvRowStride = uPlane.bytesPerRow;
  final uvPixelStride = uPlane.bytesPerPixel ?? 1;

  final out = img.Image(width: width, height: height);

  for (int y = 0; y < height; y++) {
    final uvRow = y >> 1;
    for (int x = 0; x < width; x++) {
      final uvCol = x >> 1;
      final yIndex = y * yRowStride + x;
      final uvIndex = uvRow * uvRowStride + uvCol * uvPixelStride;

      final yVal = yPlane.bytes[yIndex];
      final uVal = uPlane.bytes[uvIndex];
      final vVal = vPlane.bytes[uvIndex];

      // BT.601 conversion.
      final r = (yVal + 1.370705 * (vVal - 128)).round().clamp(0, 255);
      final g = (yVal - 0.337633 * (uVal - 128) - 0.698001 * (vVal - 128))
          .round()
          .clamp(0, 255);
      final b = (yVal + 1.732446 * (uVal - 128)).round().clamp(0, 255);

      out.setPixelRgb(x, y, r, g, b);
    }
  }

  return out;
}

/// Converts one [CameraImage] frame to an upright JPEG file on disk and
/// returns the file path. This is deliberately called only once per
/// verification/registration attempt (see FaceCameraService) - writing a
/// file for every stream frame would be wasteful I/O for no benefit, since
/// ML Kit already tells us which frame is worth keeping.
Future<String> saveCameraImageAsJpeg({
  required CameraImage image,
  required CameraDescription camera,
  required DeviceOrientation deviceOrientation,
  required String outputPath,
  int quality = 90,
}) async {
  final rotationDegrees = rotationCompensationDegrees(camera, deviceOrientation);
  // Converting and encoding a whole frame takes long enough to stall the preview, so do it off the UI thread
  await Isolate.run(() {
    final rgbImage = _yuv420ToImage(image);
    final upright = rotationDegrees == 0 ? rgbImage : img.copyRotate(rgbImage, angle: rotationDegrees);
    File(outputPath).writeAsBytesSync(img.encodeJpg(upright, quality: quality), flush: true);
  });
  return outputPath;
}

/// Runs the face quality checks against ML Kit's detection result for a
/// single frame. Returns null if no face is present at all (caller treats
/// that as WAITING_FOR_FACE, distinct from a *bad* detected face).
///
/// Yaw range (`minYaw`/`maxYaw`) is overridable so the registration screen
/// can reuse this for "turn slightly left/right" pose prompts instead of
/// only accepting a frontal face.
/// ML Kit's boxes are in the upright picture ([rotationDegrees] from [rotationCompensationDegrees]),
/// so size and centring are measured against the upright frame, and the brightness and blur check
/// maps the box back onto the sensor's Y plane.
FaceQualityResult? evaluateFaceQuality(
  CameraImage cameraImage,
  List<Face> faces, {
  required int rotationDegrees,
  double maxRoll = 15,
  double minYaw = -15,
  double maxYaw = 15,
  double minWidthRatio = 0.25,
  double maxWidthRatio = 0.85,
  double maxCenterOffsetRatio = 0.30,
}) {
  if (faces.isEmpty) return null;

  if (faces.length > 1) {
    return FaceQualityResult(
      isGood: false,
      message: 'Only one person at a time',
      boundingBox: faces.first.boundingBox,
    );
  }

  final face = faces.first;

  final sideways = rotationDegrees == 90 || rotationDegrees == 270;
  final imageWidth = sideways ? cameraImage.height : cameraImage.width;
  final imageHeight = sideways ? cameraImage.width : cameraImage.height;

  // 1. Brightness and blur, on the face's pixels
  final yPlane = cameraImage.planes.first;
  final pictureProblem = FacePreprocessor.pictureProblem(
    yPlane.bytes,
    yPlane.bytesPerRow,
    cameraImage.width,
    cameraImage.height,
    FacePreprocessor.uprightToSensorRect(face.boundingBox, rotationDegrees, cameraImage.width, cameraImage.height),
  );
  if (pictureProblem != null) {
    return FaceQualityResult(
      isGood: false,
      message: pictureProblem,
      boundingBox: face.boundingBox,
      face: face,
    );
  }

  final box = face.boundingBox;
  final yaw = face.headEulerAngleY ?? 0;
  final roll = face.headEulerAngleZ ?? 0;

  // Reject faces that are too small (too far away for a detailed embedding)
  // or too large (too close, likely to be partially out of frame/clipped).
  final widthRatio = box.width / imageWidth;
  if (widthRatio < minWidthRatio) {
    return FaceQualityResult(
      isGood: false,
      message: 'Move closer',
      boundingBox: face.boundingBox,
      face: face,
      headEulerAngleY: face.headEulerAngleY,
      headEulerAngleZ: face.headEulerAngleZ,
    );
  }
  if (widthRatio > maxWidthRatio) {
    return FaceQualityResult(
      isGood: false,
      message: 'Move back a little',
      boundingBox: face.boundingBox,
      face: face,
      headEulerAngleY: face.headEulerAngleY,
      headEulerAngleZ: face.headEulerAngleZ,
    );
  }

  // Face should be roughly centered - off-center faces are often mid-motion
  // or partially cropped by the lens.
  final centerX = box.left + box.width / 2;
  final centerY = box.top + box.height / 2;
  final dxRatio = (centerX - imageWidth / 2).abs() / imageWidth;
  final dyRatio = (centerY - imageHeight / 2).abs() / imageHeight;
  if (dxRatio > maxCenterOffsetRatio || dyRatio > maxCenterOffsetRatio) {
    return FaceQualityResult(
      isGood: false,
      message: 'Center your face in frame',
      boundingBox: face.boundingBox,
      face: face,
      headEulerAngleY: face.headEulerAngleY,
      headEulerAngleZ: face.headEulerAngleZ,
    );
  }

  // Reject excessive tilt/turn - FaceNet was trained mostly on frontal
  // faces, so off-angle shots produce weaker embeddings and hurt match
  // accuracy at verify time.
  if (roll.abs() > maxRoll) {
    return FaceQualityResult(
      isGood: false,
      message: 'Straighten your head',
      boundingBox: face.boundingBox,
      face: face,
      headEulerAngleY: face.headEulerAngleY,
      headEulerAngleZ: face.headEulerAngleZ,
    );
  }
  if (yaw < minYaw || yaw > maxYaw) {
    return FaceQualityResult(
      isGood: false,
      message: 'Adjust head angle',
      boundingBox: face.boundingBox,
      face: face,
      headEulerAngleY: face.headEulerAngleY,
      headEulerAngleZ: face.headEulerAngleZ,
    );
  }

  return FaceQualityResult(
    isGood: true,
    message: 'Good',
    boundingBox: face.boundingBox,
    face: face, 
    headEulerAngleY: face.headEulerAngleY,
    headEulerAngleZ: face.headEulerAngleZ,
  );
}
