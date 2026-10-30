import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'face_preprocessor.dart';

class InMemoryFaceProcessor {
  /// The model input for a frame, plus the face as a small JPEG for the weighing record.
  static ({Float32List tensor, Uint8List photo}) processFrame({
    required CameraImage image,
    required Face face,
    required int sensorOrientation,
  }) {
    final upright = _uprightFrame(image, sensorOrientation);
    return (
      tensor: _toTensor(upright, face, 112, 112),
      photo: FacePreprocessor.facePhotoJpeg(upright, face.boundingBox),
    );
  }

  /// Converts a [CameraImage] frame directly to a normalized FaceNet Float32 tensor.
  static Float32List processFrameToTensor({
    required CameraImage image,
    required Face face,
    required int sensorOrientation,
    int targetWidth = 112,
    int targetHeight = 112,
  }) =>
      _toTensor(_uprightFrame(image, sensorOrientation), face, targetWidth, targetHeight);

  static img.Image _uprightFrame(CameraImage image, int sensorOrientation) {
    final rgbImage = _convertCameraImageToRgb(image);
    if (rgbImage == null) {
      throw Exception('Unsupported camera image format: ${image.format.group}');
    }

    // 1. Rotate raw camera frame to match portrait sensor orientation
    return sensorOrientation == 0 ? rgbImage : img.copyRotate(rgbImage, angle: sensorOrientation.toDouble());
  }

  static Float32List _toTensor(img.Image rgbImage, Face face, int targetWidth, int targetHeight) {

    // No mirroring for the front camera: ML Kit's face box and landmarks are for the unmirrored
    // frame, and registration photos aren't mirrored either.

    // 2. Align eye landmarks horizontally and crop 112x112 tensor directly
    final img.Image? alignedFace = FacePreprocessor.alignAndCropFace(
      rgbImage,
      face,
      targetSize: targetWidth,
    );

    if (alignedFace == null) {
      throw Exception('Failed to align and crop face region');
    }

    // 3. Normalize pixel values to [-1.0, 1.0] for ArcFace
    final Float32List tensor = Float32List(1 * targetWidth * targetHeight * 3);
    int bufferIndex = 0;

    for (int h = 0; h < targetHeight; h++) {
      for (int w = 0; w < targetWidth; w++) {
        final pixel = alignedFace.getPixel(w, h);
        tensor[bufferIndex++] = (pixel.r - 127.5) / 128.0;
        tensor[bufferIndex++] = (pixel.g - 127.5) / 128.0;
        tensor[bufferIndex++] = (pixel.b - 127.5) / 128.0;
      }
    }

    return tensor;
  }

  static img.Image? _convertCameraImageToRgb(CameraImage image) {
    if (image.format.group == ImageFormatGroup.yuv420) {
      return _convertYUV420ToRgb(image);
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      return _convertBGRA8888ToRgb(image);
    }
    return null;
  }

  static img.Image _convertBGRA8888ToRgb(CameraImage image) {
    final plane = image.planes[0];
    return img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: plane.bytes.buffer,
      order: img.ChannelOrder.bgra,
    );
  }

  static img.Image _convertYUV420ToRgb(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    final img.Image rgbImage = img.Image(
      width: width,
      height: height,
    );

    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

    for (int y = 0; y < height; y++) {
      final int yRowOffset = y * yPlane.bytesPerRow;
      final int uvRowOffset = (y >> 1) * uvRowStride;

      for (int x = 0; x < width; x++) {
        final int yIndex = yRowOffset + x;
        final int uvIndex = uvRowOffset + (x >> 1) * uvPixelStride;

        final int yVal = yPlane.bytes[yIndex];
        final int uVal = uPlane.bytes[uvIndex] - 128;
        final int vVal = vPlane.bytes[uvIndex] - 128;

        final int r = (yVal + 1.370705 * vVal).round().clamp(0, 255);
        final int g = (yVal - 0.337633 * uVal - 0.698001 * vVal).round().clamp(0, 255);
        final int b = (yVal + 1.732446 * uVal).round().clamp(0, 255);

        rgbImage.setPixelRgb(x, y, r, g, b);
      }
    }

    return rgbImage;
  }
}