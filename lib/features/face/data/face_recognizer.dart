import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../domain/embedding_aggregator.dart';
import 'face_preprocessor.dart';
import 'in_memory_face_processor.dart';

// Ported from face_verification_demo (FaceVerificationService). No liveness check, by decision: the
// supervisor is at the scale, and the weighing keeps the face photo as evidence.

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

/// The registration's poses don't look like one face, e.g. one was a blurred picture or someone else.
class PosesDisagreeException implements Exception {
  @override
  String toString() => "The poses don't look like the same face. Start again from the first pose.";
}

/// Who a face matched, by EMP No.
class FaceMatch {
  final bool success;
  final String? employeeCode;
  final double similarity;
  final String? error;

  /// The recognised face as a small JPEG, kept with the weighing.
  final Uint8List? photo;

  const FaceMatch({required this.success, this.employeeCode, this.similarity = 0.0, this.error, this.photo});
}

/// ArcFace embeddings on the phone: registers several samples per worker and finds the best match.
///
/// The picture work and the model run in a background isolate, on the same interpreter, so the
/// camera preview doesn't stutter. One runs at a time; the interpreter isn't safe to share.
class FaceRecognizer {
  /// Tested on the app's model: the same man scored 0.65-0.83 and two different men 0.44, so the
  /// demo's 0.45 let lookalikes through. Below this the supervisor searches instead.
  static const double matchThreshold = 0.60;

  /// How far the best face must be ahead of the next one. Closer than that, two registered workers
  /// look alike to the model and guessing would weigh the wrong person.
  static const double minMargin = 0.08;

  Interpreter? _interpreter;
  FaceDetector? _diskFaceDetector;
  Future<void>? _loading;
  Future<void> _running = Future.value();

  /// Poses captured so far in a registration that isn't finished.
  final Map<String, List<List<double>>> _workerSamples = {};

  /// The photo kept from that registration (see [registerSample]).
  final Map<String, Uint8List> _workerPhotos = {};

  /// What [identify] matches against: the faces saved on the phone, by EMP No.
  Map<String, List<double>> _registeredTemplates = const {};

  bool get isInitialized => _interpreter != null;

  void setTemplates(Map<String, List<double>> templates) => _registeredTemplates = Map.unmodifiable(templates);

  /// Drops the poses of an unfinished registration; the worker's saved face stays.
  void clear(String employeeCode) {
    _workerSamples.remove(employeeCode);
    _workerPhotos.remove(employeeCode);
  }

  /// How alike each pose must be to the others. Turned poses score lower than front ones, so this is
  /// well below a match; it catches a pose that is something else entirely.
  static const double minPoseAgreement = 0.5;

  /// The registration's face: the normalised mean of its poses, how many there were, and the photo.
  /// Throws [PosesDisagreeException] (and drops the poses) when they don't look like one face.
  ({List<double> embedding, int sampleCount, Uint8List? photo}) finishRegistration(String employeeCode) {
    final samples = _workerSamples.remove(employeeCode);
    final photo = _workerPhotos.remove(employeeCode);
    if (samples == null || samples.isEmpty) throw StateError('No poses captured for $employeeCode');
    if (!posesAgree(samples)) throw PosesDisagreeException();
    return (
      embedding: EmbeddingAggregator.computeNormalizedMeanEmbedding(samples),
      sampleCount: samples.length,
      photo: photo,
    );
  }

  Future<void> ensureInitialized() => _loading ??= _load();

  Future<void> _load() async {
    final options = InterpreterOptions()..threads = 4;
    _interpreter = await Interpreter.fromAsset('assets/arcface_512.tflite', options: options)
      ..allocateTensors();
    _diskFaceDetector = FaceDetector(
      options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate, enableLandmarks: true),
    );
  }

  /// Runs [job] after the one before it has finished.
  Future<T> _oneAtATime<T>(Future<T> Function() job) {
    final result = _running.then((_) => job());
    _running = result.then((_) {}, onError: (_) {});
    return result;
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
      final address = _interpreter!.address;
      final frame = await _oneAtATime(() => _embedFrameInBackground(address, image, face, sensorOrientation));
      final match = bestMatch(frame.embedding, _registeredTemplates, threshold: threshold);
      if (!match.success) return match;
      return FaceMatch(
        success: true,
        employeeCode: match.employeeCode,
        similarity: match.similarity,
        photo: frame.photo,
      );
    } catch (e) {
      return FaceMatch(success: false, error: 'Face check failed: $e');
    }
  }

  /// Adds one pose sample for [employeeCode] from an upright JPEG. With [keepPhoto], the face from
  /// this pose becomes the worker's registered photo.
  Future<void> registerSample({
    required String employeeCode,
    required String imagePath,
    bool keepPhoto = false,
  }) async {
    if (_interpreter == null || _diskFaceDetector == null) {
      throw StateError('Face model not loaded');
    }

    final faces = await _diskFaceDetector!.processImage(InputImage.fromFilePath(imagePath));
    if (faces.isEmpty) throw Exception('No face found in the photo. Try again.');

    final address = _interpreter!.address;
    final sample = await _oneAtATime(() => _embedPhotoInBackground(address, imagePath, faces.first, keepPhoto));

    _workerSamples.putIfAbsent(employeeCode, () => []).add(sample.embedding);
    if (sample.photo != null) _workerPhotos[employeeCode] = sample.photo!;
    debugPrint('[Face] registered $employeeCode, ${_workerSamples[employeeCode]!.length} samples');
  }

  void dispose() {
    _diskFaceDetector?.close();
    _interpreter?.close();
  }
}

/// True when every pose is at least [minAgreement] alike to the mean of the other poses.
bool posesAgree(List<List<double>> samples, {double minAgreement = FaceRecognizer.minPoseAgreement}) {
  if (samples.length < 2) return true;
  for (var i = 0; i < samples.length; i++) {
    final others = [for (var j = 0; j < samples.length; j++) if (j != i) samples[j]];
    final mean = EmbeddingAggregator.computeNormalizedMeanEmbedding(others);
    if (_dot(samples[i], mean) < minAgreement) return false;
  }
  return true;
}

/// The registered face closest to [embedding]. A match needs [threshold] and must beat the next
/// face by [margin]; the embeddings are L2-normalised, so the dot product is the cosine similarity.
FaceMatch bestMatch(
  List<double> embedding,
  Map<String, List<double>> templates, {
  double threshold = FaceRecognizer.matchThreshold,
  double margin = FaceRecognizer.minMargin,
}) {
  String? bestCode;
  var best = -1.0;
  var second = -1.0;
  templates.forEach((code, template) {
    final similarity = _dot(embedding, template);
    if (similarity > best) {
      second = best;
      best = similarity;
      bestCode = code;
    } else if (similarity > second) {
      second = similarity;
    }
  });

  debugPrint('[Face] best $bestCode ${best.toStringAsFixed(4)}, next ${second.toStringAsFixed(4)}');

  if (bestCode == null || best < threshold) {
    return FaceMatch(success: false, similarity: best, error: 'Face not recognised');
  }
  if (best - second < margin) {
    return FaceMatch(success: false, similarity: best, error: 'Not sure who this is');
  }
  return FaceMatch(success: true, employeeCode: bestCode, similarity: best);
}

double _dot(List<double> a, List<double> b) {
  var sum = 0.0;
  for (var i = 0; i < a.length; i++) {
    sum += a[i] * b[i];
  }
  return sum;
}

// Top-level, so the isolate gets only these arguments and not the recognizer around them

Future<({List<double> embedding, Uint8List photo})> _embedFrameInBackground(
  int address,
  CameraImage image,
  Face face,
  int sensorOrientation,
) =>
    Isolate.run(() {
      final interpreter = Interpreter.fromAddress(address, allocated: true);
      final frame = InMemoryFaceProcessor.processFrame(image: image, face: face, sensorOrientation: sensorOrientation);
      final input = _buildInputTensor(frame.tensor, interpreter.getInputTensor(0));
      return (embedding: _l2Normalize(_runModel(interpreter, input)), photo: frame.photo);
    });

Future<({List<double> embedding, Uint8List? photo})> _embedPhotoInBackground(
  int address,
  String imagePath,
  Face face,
  bool keepPhoto,
) =>
    Isolate.run(() {
      final interpreter = Interpreter.fromAddress(address, allocated: true);
      final originalImage = img.decodeImage(File(imagePath).readAsBytesSync());
      if (originalImage == null) throw Exception('Could not read the photo. Try again.');

      // Same alignment and crop as identify, so registered and live faces compare like for like
      final croppedFace = FacePreprocessor.alignFace(originalImage, face);
      if (croppedFace == null) throw Exception('Could not crop the face. Try again.');

      final input = _buildInputFromCroppedImage(croppedFace, interpreter.getInputTensor(0));
      return (
        embedding: _l2Normalize(_runModel(interpreter, input)),
        photo: keepPhoto ? FacePreprocessor.facePhotoJpeg(originalImage, face.boundingBox) : null,
      );
    });

List<double> _runModel(Interpreter interpreter, Object inputData) {
  final outputTensor = interpreter.getOutputTensor(0);
  final isOutputUint8 = outputTensor.type.toString().toLowerCase().contains('uint8');
  if (isOutputUint8) {
    final outputBuffer = List.generate(1, (_) => List<int>.filled(512, 0));
    interpreter.run(inputData, outputBuffer);
    final scale = outputTensor.params.scale;
    final zeroPoint = outputTensor.params.zeroPoint;
    return outputBuffer.first.map((e) => (e - zeroPoint) * scale).toList();
  }
  final outputBuffer = List.generate(1, (_) => List<double>.filled(512, 0.0));
  interpreter.run(inputData, outputBuffer);
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
