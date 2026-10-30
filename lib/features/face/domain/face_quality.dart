import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Result of running ML Kit quality checks on a single detected face.
///
/// This is what gates whether a frame is even eligible to be sent to ArcFace -
/// ArcFace is expensive (relative to ML Kit) and only worth running once we
/// already know we have one well-framed, front-facing, stable face.
class FaceQualityResult {
  final bool isGood;
  final String message;
  final Rect boundingBox;
  final Face? face; // Attached ML Kit Face reference
  final double? headEulerAngleY;
  final double? headEulerAngleZ;

  const FaceQualityResult({
    required this.isGood,
    required this.message,
    required this.boundingBox,
    this.face,
    this.headEulerAngleY,
    this.headEulerAngleZ,
  });
}
