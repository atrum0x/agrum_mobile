import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../domain/embedding_aggregator.dart';
import 'face_preprocessor.dart';
import 'in_memory_face_processor.dart';

// Ported from face_verification_demo (FaceVerificationService). Known gaps still to fix: no liveness
// check, 1:N search over every registered face, inference on the UI thread, quality checks in the
// wrong image space.

class RegistrationPose {
  final String instruction;
  final String imageId;
  final double minYaw;
  final double maxYaw;

  const RegistrationPose({
    required this.instruction,
    required this.imageId,
    required this.minYaw,
    required this.maxYaw,
  });
}

const List<RegistrationPose> registrationPoses = [
  RegistrationPose(instruction: 'Look straight ahead', imageId: 'front', minYaw: -15, maxYaw: 15),
  RegistrationPose(instruction: 'Turn slightly left', imageId: 'turn_left', minYaw: -35, maxYaw: -12),
  RegistrationPose(instruction: 'Turn slightly right', imageId: 'turn_right', minYaw: 12, maxYaw: 35),
  RegistrationPose(
    instruction: 'Look straight ahead, relax your expression',
    imageId: 'front_relaxed',
    minYaw: -15,
    maxYaw: 15,
  ),
  RegistrationPose(
    instruction: 'Look straight ahead again (try different lighting if possible)',
    imageId: 'front_alt_lighting',
    minYaw: -15,
    maxYaw: 15,
  ),
];

/// Who a face matched, by EMP No.
class FaceMatch {
  final bool success;
  final String? employeeCode;
  final double similarity;
  final String? error;

  const FaceMatch({required this.success, this.employeeCode, this.similarity = 0.0, this.error});
}

/// ArcFace embeddings on the phone: registers several samples per worker and finds the best match.
class FaceRecognizer {
  static const double matchThreshold = 0.45;

  Interpreter? _interpreter;
  FaceDetector? _diskFaceDetector;
  Future<void>? _loading;

  /// Poses captured so far in a registration that isn't finished.
  final Map<String, List<List<double>>> _workerSamples = {};

  /// What [identify] matches against: the faces saved on the phone, by EMP No.
  Map<String, List<double>> _registeredTemplates = const {};

  bool get isInitialized => _interpreter != null;

  void setTemplates(Map<String, List<double>> templates) => _registeredTemplates = Map.unmodifiable(templates);

  /// Drops the poses of an unfinished registration; the worker's saved face stays.
  void clear(String employeeCode) => _workerSamples.remove(employeeCode);

  /// The registration's face: the normalised mean of its poses, and how many there were.
  ({List<double> embedding, int sampleCount}) finishRegistration(String employeeCode) {
    final samples = _workerSamples.remove(employeeCode);
    if (samples == null || samples.isEmpty) throw StateError('No poses captured for $employeeCode');
    return (
      embedding: EmbeddingAggregator.computeNormalizedMeanEmbedding(samples),
      sampleCount: samples.length,
    );
  }

  Future<void> ensureInitialized() => _loading ??= _load();

  Future<void> _load() async {
    final options = InterpreterOptions()..threads = 4;
    _interpreter = await Interpreter.fromAsset('assets/arcface_512.tflite', options: options);
    _diskFaceDetector = FaceDetector(
      options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate, enableLandmarks: true),
    );
  }

  Future<FaceMatch> identify({
    required CameraImage image,
    required Face face,
    required int sensorOrientation,
    double threshold = matchThreshold,
  }) async {
    if (_interpreter == null) {
      return const FaceMatch(success: false, error: 'Face model not loaded');
    }
    if (_registeredTemplates.isEmpty) {
      return const FaceMatch(success: false, error: 'No faces registered on this phone');
    }

    try {
      final Float32List floatTensor = InMemoryFaceProcessor.processFrameToTensor(
        image: image,
        face: face,
        sensorOrientation: sensorOrientation,
        targetWidth: 112,
        targetHeight: 112,
      );

      final inputData = _buildInputTensor(floatTensor, _interpreter!.getInputTensor(0));
      final normalizedEmbedding = _l2Normalize(_runModel(inputData));

      String? bestMatchCode;
      double maxSimilarity = -1.0;
      _registeredTemplates.forEach((code, templateEmbedding) {
        final similarity = _cosineSimilarity(normalizedEmbedding, templateEmbedding);
        if (similarity > maxSimilarity) {
          maxSimilarity = similarity;
          bestMatchCode = code;
        }
      });

      debugPrint('[Face] best $bestMatchCode ${maxSimilarity.toStringAsFixed(4)} (threshold $threshold)');

      if (bestMatchCode != null && maxSimilarity >= threshold) {
        return FaceMatch(success: true, employeeCode: bestMatchCode, similarity: maxSimilarity);
      }
      return FaceMatch(success: false, similarity: maxSimilarity, error: 'Face not recognised');
    } catch (e) {
      return FaceMatch(success: false, error: 'Face check failed: $e');
    }
  }

  /// Adds one pose sample for [employeeCode] from an upright JPEG.
  Future<void> registerSample({required String employeeCode, required String imagePath}) async {
    if (_interpreter == null || _diskFaceDetector == null) {
      throw StateError('Face model not loaded');
    }

    final faces = await _diskFaceDetector!.processImage(InputImage.fromFilePath(imagePath));
    if (faces.isEmpty) throw Exception('No face found in the photo. Try again.');

    final originalImage = img.decodeImage(await File(imagePath).readAsBytes());
    if (originalImage == null) throw Exception('Could not read the photo. Try again.');

    // Align and crop using FacePreprocessor to ensure pipeline parity
    final croppedFace = FacePreprocessor.alignAndCropFace(originalImage, faces.first, targetSize: 112);
    if (croppedFace == null) throw Exception('Could not crop the face. Try again.');

    final inputData = _buildInputFromCroppedImage(croppedFace, _interpreter!.getInputTensor(0));
    final normalizedEmbedding = _l2Normalize(_runModel(inputData));

    _workerSamples.putIfAbsent(employeeCode, () => []).add(normalizedEmbedding);
    debugPrint('[Face] registered $employeeCode, ${_workerSamples[employeeCode]!.length} samples');
  }

  List<double> _runModel(Object inputData) {
    final outputTensor = _interpreter!.getOutputTensor(0);
    final isOutputUint8 = outputTensor.type.toString().toLowerCase().contains('uint8');
    if (isOutputUint8) {
      final outputBuffer = List.generate(1, (_) => List<int>.filled(512, 0));
      _interpreter!.run(inputData, outputBuffer);
      final scale = outputTensor.params.scale;
      final zeroPoint = outputTensor.params.zeroPoint;
      return outputBuffer.first.map((e) => (e - zeroPoint) * scale).toList();
    }
    final outputBuffer = List.generate(1, (_) => List<double>.filled(512, 0.0));
    _interpreter!.run(inputData, outputBuffer);
    return outputBuffer.first.map((e) => e.toDouble()).toList();
  }

  List<double> _l2Normalize(List<double> embedding) {
    double sum = 0.0;
    for (final val in embedding) {
      sum += val * val;
    }
    final norm = sqrt(sum);
    if (norm == 0) return embedding;
    return embedding.map((e) => e / norm).toList();
  }

  double _cosineSimilarity(List<double> e1, List<double> e2) {
    double dotProduct = 0.0;
    for (int i = 0; i < e1.length; i++) {
      dotProduct += e1[i] * e2[i];
    }
    return dotProduct;
  }

  void dispose() {
    _diskFaceDetector?.close();
    _interpreter?.close();
  }
}

Object _buildInputTensor(Float32List floatTensor, Tensor inputTensor) {
  final bool isUint8 = inputTensor.type.toString().toLowerCase().contains('uint8');

  if (isUint8) {
    return List.generate(
      1,
      (_) => List.generate(
        112,
        (y) => List.generate(
          112,
          (x) => List.generate(3, (c) {
            final floatVal = floatTensor[(y * 112 + x) * 3 + c];
            return ((floatVal * 128.0) + 127.5).round().clamp(0, 255);
          }),
        ),
      ),
    );
  }
  return List.generate(
    1,
    (_) => List.generate(
      112,
      (y) => List.generate(112, (x) => List.generate(3, (c) => floatTensor[(y * 112 + x) * 3 + c].toDouble())),
    ),
  );
}

Object _buildInputFromCroppedImage(img.Image croppedFace, Tensor inputTensor) {
  final bool isUint8 = inputTensor.type.toString().toLowerCase().contains('uint8');

  if (isUint8) {
    return List.generate(
      1,
      (_) => List.generate(
        croppedFace.height,
        (y) => List.generate(croppedFace.width, (x) {
          final pixel = croppedFace.getPixel(x, y);
          return [pixel.r.toInt().clamp(0, 255), pixel.g.toInt().clamp(0, 255), pixel.b.toInt().clamp(0, 255)];
        }),
      ),
    );
  }
  return List.generate(
    1,
    (_) => List.generate(
      croppedFace.height,
      (y) => List.generate(croppedFace.width, (x) {
        final pixel = croppedFace.getPixel(x, y);
        return [(pixel.r - 127.5) / 128.0, (pixel.g - 127.5) / 128.0, (pixel.b - 127.5) / 128.0];
      }),
    ),
  );
}
