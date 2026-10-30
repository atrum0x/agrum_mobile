import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../domain/face_quality.dart';
import 'camera_image_converter.dart';

/// Tracks whether the *same* face has stayed in good, roughly-still
/// framing for enough consecutive analyzed frames to be worth sending to
/// FaceNet. This is what prevents us from firing verification on every
/// single good-looking frame - we want one confident capture, not a burst.
class _FaceStabilityTracker {
  static const int requiredConsecutiveGoodFrames = 3;
  static const double maxCenterDriftPx = 30;

  int _goodStreak = 0;
  Offset? _lastCenter;

  /// Returns true once the streak requirement is met.
  bool update(FaceQualityResult? quality) {
    if (quality == null || !quality.isGood) {
      reset();
      return false;
    }

    final center = quality.boundingBox.center;
    if (_lastCenter != null && (center - _lastCenter!).distance > maxCenterDriftPx) {
      _goodStreak = 0;
    }
    _lastCenter = center;
    _goodStreak++;

    return _goodStreak >= requiredConsecutiveGoodFrames;
  }

  void reset() {
    _goodStreak = 0;
    _lastCenter = null;
  }
}

/// Owns the [CameraController] and the ML Kit [FaceDetector], and runs
/// continuous stream-based face quality analysis.
///
/// Design notes (see requirements 1, 3, 6, 7):
/// - Uses `startImageStream` instead of periodic `takePicture()` calls, so
///   the preview never freezes waiting on a still-image capture round trip.
/// - ML Kit runs on a throttled subset of frames (every Nth frame, and only
///   when the previous analysis has finished) so it never falls behind the
///   camera's frame rate and never queues up backlogged frames.
/// - FaceNet/JPEG conversion is NOT done here - this service only reports
///   *when* a good, stable frame occurred via [onFrameAnalyzed]; the caller
///   decides whether to actually capture it.
/// - Implements WidgetsBindingObserver to pause the stream when the app is
///   backgrounded and resume it in the foreground, avoiding camera crashes
///   and wasted battery/CPU.
class FaceCameraService with WidgetsBindingObserver {
  CameraController? _controller;
  FaceDetector? _faceDetector;
  CameraDescription? _camera;
  List<CameraDescription> _availableCameras = [];

  bool _isStreaming = false;
  bool _isProcessingFrame = false;
  int _frameCounter = 0;

  /// Only 1 in every N frames is sent to ML Kit. At a typical 30fps stream
  /// this still gives ~10 analyses/sec - plenty for smooth quality feedback
  /// without maxing out the CPU alongside camera preview rendering.
  static const int processEveryNthFrame = 2;

  static const analysisTimeout = Duration(seconds: 3);

  final _stability = _FaceStabilityTracker();

  /// Acceptable yaw (left/right turn) range for the CURRENT quality check.
  /// Defaults to a frontal face. The registration screen overrides these
  /// between poses (e.g. -35..-12 for "turn slightly left") so the same
  /// stream analysis pipeline can validate angled poses, not just frontal
  /// ones, without duplicating the ML Kit call.
  double minYaw = -15;
  double maxYaw = 15;
  double maxRoll = 15;

  /// Called after every analyzed frame with the raw frame, the quality
  /// verdict for it, and whether the stability streak requirement was met.
  /// The raw [CameraImage] is only safe to read synchronously during this
  /// callback - do not store it for later use.
  void Function(CameraImage rawImage, FaceQualityResult? quality, bool isStable)? onFrameAnalyzed;
  void Function(Object error)? onError;

  CameraController? get controller => _controller;
  CameraDescription? get camera => _camera;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get canSwitchCamera => _availableCameras.length > 1;

  Future<void> initialize({CameraLensDirection lensDirection = CameraLensDirection.front}) async {
    WidgetsBinding.instance.addObserver(this);

    _availableCameras = await availableCameras();
    if (_availableCameras.isEmpty) {
      throw Exception('No camera available on this device');
    }

    _camera = _availableCameras.firstWhere(
      (c) => c.lensDirection == lensDirection,
      orElse: () => _availableCameras.first,
    );

    _faceDetector ??= FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableTracking: true,
        // Eyes, nose and mouth, to line the face up the same way registration does
        enableLandmarks: true,
      ),
    );

    await _initController(_camera!);
  }

  Future<void> _initController(CameraDescription camera) async {
    final oldController = _controller;
    if (oldController != null) {
      _controller = null;
      await oldController.dispose();
    }

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      // yuv420 is the one format group guaranteed to be supported on both
      // platforms; we convert it manually (see camera_image_converter.dart)
      // rather than relying on an implicit/assumed conversion.
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
  }

  /// Switches to the next available camera (e.g. front -> back)[cite: 5].
  Future<void> switchCamera() async {
    if (_availableCameras.length < 2 || _camera == null) return;

    final wasStreaming = _isStreaming;
    if (wasStreaming) {
      await stopStream();
    }

    final currentIndex = _availableCameras.indexOf(_camera!);
    final nextIndex = (currentIndex + 1) % _availableCameras.length;
    _camera = _availableCameras[nextIndex];

    await _initController(_camera!);
    resetStability();

    if (wasStreaming) {
      await startStream();
    }
  }

  Future<void> startStream() async {
    if (_controller == null || !_controller!.value.isInitialized || _isStreaming) return;
    _isStreaming = true;
    _frameCounter = 0;
    await _controller!.startImageStream(_handleFrame);
  }

  Future<void> stopStream() async {
    if (_controller == null || !_isStreaming) return;
    _isStreaming = false;
    if (_controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
  }

  void resetStability() => _stability.reset();

  void _handleFrame(CameraImage image) {
    _frameCounter++;
    if (_frameCounter % processEveryNthFrame != 0) return;

    // If ML Kit is still processing the previous sampled frame, drop this
    // one entirely rather than queueing it - queueing is what causes the
    // camera stream to stall on slower Android devices.
    if (_isProcessingFrame) return;
    _isProcessingFrame = true;

    _analyzeFrame(image).whenComplete(() => _isProcessingFrame = false);
  }

  Future<void> _analyzeFrame(CameraImage image) async {
    try {
      if (_controller == null || _camera == null) return;
      final deviceOrientation = _controller!.value.deviceOrientation;

      final inputImage = buildInputImage(image, _camera!, deviceOrientation);
      if (inputImage == null) return;
      final rotationDegrees = rotationCompensationDegrees(_camera!, deviceOrientation);

      // A call that never returns would block every later frame (_isProcessingFrame), so give up on it
      final faces = await _faceDetector!.processImage(inputImage).timeout(analysisTimeout);
      final quality = evaluateFaceQuality(
        image,
        faces,
        rotationDegrees: rotationDegrees,
        minYaw: minYaw,
        maxYaw: maxYaw,
        maxRoll: maxRoll,
      );
      final isStable = _stability.update(quality);

      onFrameAnalyzed?.call(image, quality, isStable);
    } catch (e) {
      onError?.call(e);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // Release the camera hardware while backgrounded - required on
      // Android or the app can crash/deadlock when another app also wants
      // the camera, and it avoids burning battery in the background.
      stopStream();
    } else if (state == AppLifecycleState.resumed) {
      resetStability();
      startStream();
    }
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await stopStream();
    await _faceDetector?.close();
    await _controller?.dispose();
    _controller = null;
    _faceDetector = null;
    _camera = null;
  }
}
