import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/theme.dart';
import '../data/face_camera_service.dart';
import '../domain/face_quality.dart';
import '../state/face_providers.dart';
import 'face_camera_view.dart';

enum _ScanState { starting, waiting, adjusting, checking, failed, error }

/// If the face check hasn't answered for a single frame by then, say so instead of looking stuck.
const noFramesAfter = Duration(seconds: 5);
const noFramesMessage = 'The camera is not sending pictures to the face check. Close this screen and open it again.';

String faceCheckError(Object error) => 'Face check failed: $error';

/// Identifies a worker by face from the live camera.
///
/// [onRecognised] gets the matched EMP No and returns null to accept it (the parent then removes the
/// scanner), or a message to show before scanning again, e.g. when the worker isn't on today's list.
///
/// The camera runs only while this widget is on screen: an inactive tab or a covered route mutes
/// [TickerMode], which closes the camera.
class FaceScanner extends ConsumerStatefulWidget {
  const FaceScanner({super.key, required this.onRecognised});

  final String? Function(String employeeCode) onRecognised;

  @override
  ConsumerState<FaceScanner> createState() => _FaceScannerState();
}

class _FaceScannerState extends ConsumerState<FaceScanner> {
  static const _cooldown = Duration(seconds: 2);

  FaceCameraService? _camera;
  CameraLensDirection _lens = CameraLensDirection.back;
  bool _active = false;

  /// Bumped on every start/stop so a slow start that finishes after a stop is dropped.
  int _generation = 0;

  _ScanState _state = _ScanState.starting;
  String? _message;
  bool _processingLock = false;
  Timer? _cooldownTimer;
  bool _gotFrame = false;
  Timer? _watchdog;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (active == _active) return;
    _active = active;
    if (active) {
      unawaited(_start());
    } else {
      unawaited(_stop());
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _watchdog?.cancel();
    _generation++;
    unawaited(_camera?.dispose());
    super.dispose();
  }

  Future<void> _start() async {
    final generation = ++_generation;
    _set(_ScanState.starting, null);
    final camera = FaceCameraService();
    try {
      await ref.read(faceRecognizerProvider).ensureInitialized();
      await camera.initialize(lensDirection: _lens);
      if (generation != _generation) {
        await camera.dispose();
        return;
      }
      camera.onFrameAnalyzed = _onFrameAnalyzed;
      camera.onError = (e) {
        debugPrint('Camera/ML Kit error: $e');
        if (!_processingLock) _set(_ScanState.error, faceCheckError(e));
      };
      _camera = camera;
      _processingLock = false;
      _gotFrame = false;
      await camera.startStream();
      _set(_ScanState.waiting, null);
      _watchdog?.cancel();
      _watchdog = Timer(noFramesAfter, () {
        if (!_gotFrame && generation == _generation) _set(_ScanState.error, noFramesMessage);
      });
    } on CameraException catch (e) {
      await camera.dispose();
      if (generation != _generation) return;
      _set(
        _ScanState.error,
        e.code.contains('AccessDenied')
            ? 'Camera permission is needed to identify workers. Allow it in the phone settings.'
            : 'Camera could not start: ${e.description ?? e.code}',
      );
    } catch (e) {
      await camera.dispose();
      if (generation == _generation) _set(_ScanState.error, 'Camera could not start: $e');
    }
  }

  Future<void> _stop() async {
    _generation++;
    _cooldownTimer?.cancel();
    _watchdog?.cancel();
    final camera = _camera;
    _camera = null;
    if (mounted) setState(() {});
    await camera?.dispose();
  }

  Future<void> _switchCamera() async {
    _lens = _lens == CameraLensDirection.back ? CameraLensDirection.front : CameraLensDirection.back;
    await _stop();
    if (mounted && _active) await _start();
  }

  void _onFrameAnalyzed(CameraImage rawImage, FaceQualityResult? quality, bool isStable) {
    _gotFrame = true;
    if (_processingLock) return;
    if (quality == null) return _set(_ScanState.waiting, null);
    if (!quality.isGood) return _set(_ScanState.adjusting, quality.message);
    if (!isStable) return _set(_ScanState.adjusting, 'Hold still...');

    _processingLock = true;
    unawaited(_identify(rawImage, quality));
  }

  Future<void> _identify(CameraImage rawImage, FaceQualityResult quality) async {
    final camera = _camera?.camera;
    if (camera == null) return;
    _set(_ScanState.checking, null);
    final match = await ref.read(faceRecognizerProvider).identify(
          image: rawImage,
          face: quality.face!,
          sensorOrientation: camera.sensorOrientation,
        );
    if (!mounted || _camera == null) return;
    if (match.success) {
      final problem = widget.onRecognised(match.employeeCode!);
      if (problem == null) return;
      _fail(problem);
    } else {
      _fail('${match.error ?? 'Face not recognised'}. Try again, or search by EMP No.');
    }
  }

  void _fail(String message) {
    _set(_ScanState.failed, message);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(_cooldown, () {
      if (!mounted) return;
      _camera?.resetStability();
      _set(_ScanState.waiting, null);
      _processingLock = false;
    });
  }

  void _set(_ScanState state, String? message) {
    if (!mounted || (_state == state && _message == message)) return;
    setState(() {
      _state = state;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _camera?.controller;
    final (text, color) = switch (_state) {
      _ScanState.starting => ('Starting camera…', AppColors.mutedForeground),
      _ScanState.waiting => ('Point the camera at the worker\'s face', AppColors.mutedForeground),
      _ScanState.adjusting => (_message ?? 'Hold still...', AppColors.pending),
      _ScanState.checking => ('Identifying…', AppColors.primary),
      _ScanState.failed || _ScanState.error => (_message ?? 'Face not recognised', AppColors.destructive),
    };
    final borderColor = switch (_state) {
      _ScanState.adjusting => AppColors.pendingOnDark,
      _ScanState.checking => AppColors.accent,
      _ScanState.failed => AppColors.destructive,
      _ => Colors.white70,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 4 / 5,
            child: ColoredBox(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (controller != null && controller.value.isInitialized)
                    FaceCameraView(controller: controller, borderColor: borderColor)
                  else if (_state != _ScanState.error)
                    const Center(child: CircularProgressIndicator(color: Colors.white)),
                  if (_camera?.canSwitchCamera ?? false)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        tooltip: 'Switch camera',
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        icon: const Icon(LucideIcons.switchCamera, color: Colors.white),
                        onPressed: _switchCamera,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: color)),
      ],
    );
  }
}
