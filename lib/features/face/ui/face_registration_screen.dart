import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/sync_status_badge.dart';
import '../../auth/state/auth_controller.dart';
import '../../setup/data/setup_cache.dart';
import '../../setup/data/setup_data.dart';
import '../../setup/state/setup_controller.dart';
import '../../sync/data/sync_status.dart';
import '../../sync/state/send_controller.dart';
import '../data/camera_image_converter.dart';
import '../data/face_camera_service.dart';
import '../data/face_recognizer.dart';
import '../data/face_store.dart';
import '../data/face_template_row.dart';
import '../domain/face_quality.dart';
import '../state/face_providers.dart';
import 'face_camera_view.dart';
import 'face_scanner.dart' show faceCheckError, noFramesAfter, noFramesMessage;

const _text = TextStyle(fontSize: 14);
const _muted = TextStyle(fontSize: 13, color: AppColors.mutedForeground);

/// Every employee in the site data, to pick whose face to register.
final _employeesProvider = FutureProvider.autoDispose<List<CachedWorker>>((ref) async {
  ref.watch(setupControllerProvider.select((s) => s.info?.refreshedAt));
  final workers = await ref.watch(setupCacheProvider).workers(includeAttended: true);
  return workers..sort((a, b) => a.employeeCode.compareTo(b.employeeCode));
});

/// More → Face Registration: pick an employee, then capture the guided poses that the weighing
/// screen matches against.
class FaceRegistrationScreen extends ConsumerStatefulWidget {
  const FaceRegistrationScreen({super.key});

  @override
  ConsumerState<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends ConsumerState<FaceRegistrationScreen> {
  CachedWorker? _employee;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final employee = _employee;
    if (employee != null) {
      return _PoseCapture(
        key: ValueKey(employee.employeeCode),
        employee: employee,
        onClose: () => setState(() => _employee = null),
      );
    }

    final employeesAsync = ref.watch(_employeesProvider);
    final registered = ref.watch(registeredFacesProvider);
    final employees = employeesAsync.value;
    if (employees == null) {
      return employeesAsync.hasError
          ? Center(child: Text('${employeesAsync.error}', style: _muted))
          : const Center(child: CircularProgressIndicator());
    }
    final term = _search.trim().toLowerCase();
    final matches = employees
        .where((w) =>
            term.isEmpty || w.employeeCode.toLowerCase().contains(term) || w.fullName.toLowerCase().contains(term))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(LucideIcons.arrowLeft, size: 20),
              onPressed: () => context.go('/more'),
            ),
            const Expanded(
              child: Text('Face Registration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const Text(
          'Pick the employee, then follow the steps with their face in the oval. '
          'Registering again replaces their face. Faces are sent to the server like other records.',
          style: _muted,
        ),
        const SizedBox(height: 12),
        ShadInput(
          placeholder: const Text('Search EMP No or name'),
          leading: const Icon(LucideIcons.search, size: 18, color: AppColors.mutedForeground),
          style: _text,
          onChanged: (v) => setState(() => _search = v),
        ),
        const SizedBox(height: 4),
        if (matches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              term.isNotEmpty ? 'No employees match "$_search".' : 'No employees in the site data yet.',
              style: _muted,
            ),
          )
        else
          for (final w in matches)
            InkWell(
              onTap: () => setState(() => _employee = w),
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.muted))),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(w.fullName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          Text(w.employeeCode, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                          if (registered[w.employeeCode] case FaceTemplateRow(
                            status: SyncStatus.rejected,
                            :final reason?,
                          ))
                            Text(reason, style: const TextStyle(fontSize: 13, color: AppColors.destructive)),
                        ],
                      ),
                    ),
                    if (registered[w.employeeCode] case final face?)
                      SyncStatusBadge(status: face.status)
                    else
                      const Icon(LucideIcons.scanFace, size: 20, color: AppColors.mutedForeground),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

/// Walks the employee through [registrationPoses], capturing each one once the face is good and still.
class _PoseCapture extends ConsumerStatefulWidget {
  const _PoseCapture({super.key, required this.employee, required this.onClose});

  final CachedWorker employee;
  final VoidCallback onClose;

  @override
  ConsumerState<_PoseCapture> createState() => _PoseCaptureState();
}

class _PoseCaptureState extends ConsumerState<_PoseCapture> {
  final _camera = FaceCameraService();
  // Read up front: ref can't be used in dispose
  late final FaceRecognizer _recognizer;
  bool _cameraReady = false;
  bool _processingLock = false;
  bool _faceInFrame = false;
  bool _allDone = false;
  int _poseIndex = 0;
  String? _subtitle;
  String? _error;

  /// Set once the face check has answered for any frame; see [_watchdog].
  bool _gotFrame = false;
  Timer? _watchdog;

  String get _code => widget.employee.employeeCode;

  @override
  void initState() {
    super.initState();
    _recognizer = ref.read(faceRecognizerProvider);
    unawaited(_start());
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    unawaited(_camera.dispose());
    // Left half way: drop the captured poses; the worker's saved face, if any, stays
    if (!_allDone) _recognizer.clear(_code);
    super.dispose();
  }

  Future<void> _start() async {
    try {
      await _recognizer.ensureInitialized();
      // Start from no poses; the saved face is replaced only when all poses are captured
      _recognizer.clear(_code);
      await _camera.initialize(lensDirection: CameraLensDirection.back);
      _camera.onFrameAnalyzed = _onFrameAnalyzed;
      // Shown on screen: a face check that keeps failing would otherwise just look stuck
      _camera.onError = (e) {
        debugPrint('Camera/ML Kit error: $e');
        if (!_processingLock) _setSubtitle(faceCheckError(e));
      };
      _applyPoseThresholds();
      await _camera.startStream();
      if (mounted) setState(() => _cameraReady = true);
      _watchdog = Timer(noFramesAfter, () {
        if (!_gotFrame) _setSubtitle(noFramesMessage);
      });
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _error = e.code.contains('AccessDenied')
            ? 'Camera permission is needed to register faces. Allow it in the phone settings.'
            : 'Camera could not start: ${e.description ?? e.code}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera could not start: $e');
    }
  }

  void _applyPoseThresholds() {
    final pose = registrationPoses[_poseIndex];
    _camera.minYaw = pose.minYaw;
    _camera.maxYaw = pose.maxYaw;
  }

  void _onFrameAnalyzed(CameraImage rawImage, FaceQualityResult? quality, bool isStable) {
    _gotFrame = true;
    if (_processingLock || _allDone || !mounted) return;

    if (quality == null) {
      if (_faceInFrame) setState(() => _faceInFrame = false);
      return _setSubtitle('No face found');
    }
    if (!_faceInFrame) setState(() => _faceInFrame = true);
    if (!quality.isGood) return _setSubtitle(quality.message);
    if (!isStable) return _setSubtitle('Hold still...');

    _processingLock = true;
    unawaited(_captureCurrentPose(rawImage));
  }

  Future<void> _captureCurrentPose(CameraImage rawImage) async {
    final pose = registrationPoses[_poseIndex];
    setState(() => _subtitle = 'Capturing "${pose.instruction}"...');
    try {
      final controller = _camera.controller;
      final camera = _camera.camera;
      if (controller == null || camera == null) return;

      // The photo is only needed to read the face from; it is deleted straight after
      final file = File('${(await getTemporaryDirectory()).path}/face_${_code}_${pose.imageId}.jpg');
      try {
        await saveCameraImageAsJpeg(
          image: rawImage,
          camera: camera,
          deviceOrientation: controller.value.deviceOrientation,
          outputPath: file.path,
          quality: 85,
        );
        await _recognizer.registerSample(employeeCode: _code, imagePath: file.path);
      } finally {
        if (await file.exists()) await file.delete();
      }
      await _advanceToNextPose();
    } catch (e) {
      _setSubtitle('$e');
      // Release the lock so this pose can be tried again
      _processingLock = false;
    }
  }

  Future<void> _advanceToNextPose() async {
    if (!mounted) return;
    if (_poseIndex >= registrationPoses.length - 1) {
      await _camera.stopStream();
      await _saveFace();
      if (!mounted) return;
      setState(() {
        _allDone = true;
        _subtitle = null;
      });
      return;
    }

    setState(() {
      _poseIndex++;
      _subtitle = null;
    });
    _applyPoseThresholds();
    _camera.resetStability();
    // Time to read the next step and move before auto-capture starts again
    await Future<void>.delayed(const Duration(milliseconds: 800));
    _processingLock = false;
  }

  /// Saves the face on the phone as Waiting, then sends it when there is a connection.
  Future<void> _saveFace() async {
    final auth = ref.read(authControllerProvider);
    if (auth is! LoggedIn) return;
    final face = _recognizer.finishRegistration(_code);
    await ref.read(faceStoreProvider).save(FaceTemplateRow(
          employeeCode: _code,
          embedding: face.embedding,
          sampleCount: face.sampleCount,
          registeredAt: DateTime.now(),
          registeredBy: auth.session.profile.username,
          status: SyncStatus.waiting,
        ));
    ref.invalidate(faceTemplatesProvider);
    unawaited(ref.read(sendControllerProvider.notifier).sendInBackground());
  }

  void _setSubtitle(String text) {
    if (!mounted || _subtitle == text) return;
    setState(() => _subtitle = text);
  }

  Color get _borderColor {
    if (_processingLock) return AppColors.accent;
    if (_faceInFrame && _subtitle == 'Hold still...') return AppColors.pendingOnDark;
    if (_faceInFrame) return Colors.yellowAccent;
    return Colors.white54;
  }

  @override
  Widget build(BuildContext context) {
    final name = '${widget.employee.fullName} (${widget.employee.employeeCode})';

    if (_allDone) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(LucideIcons.circleCheck, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text('Face registered for $name.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            ShadButton(
              height: 48,
              width: double.infinity,
              gradient: AppColors.headerGradient,
              shadows: AppColors.buttonShadows,
              onPressed: widget.onClose,
              child: const Text('Register another', style: TextStyle(fontSize: 15)),
            ),
            const SizedBox(height: 8),
            ShadButton.outline(
              height: 48,
              width: double.infinity,
              onPressed: () => context.go('/more'),
              child: const Text('Done', style: TextStyle(fontSize: 15)),
            ),
          ],
        ),
      );
    }

    final pose = registrationPoses[_poseIndex];
    final controller = _camera.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Cancel',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(LucideIcons.x, size: 20),
                onPressed: widget.onClose,
              ),
              Expanded(child: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
              Text('${_poseIndex + 1} of ${registrationPoses.length}', style: _muted),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShadProgress(value: (_poseIndex + 1) / registrationPoses.length),
              const SizedBox(height: 12),
              Text(pose.instruction,
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
            ],
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: Colors.black,
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!,
                          textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.white)),
                    ),
                  )
                : !_cameraReady || controller == null || !controller.value.isInitialized
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : FaceCameraView(controller: controller, borderColor: _borderColor),
          ),
        ),
        Container(
          width: double.infinity,
          color: AppColors.foreground,
          padding: const EdgeInsets.all(16),
          child: Text(
            _subtitle ?? 'Put the face in the oval',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ],
    );
  }
}
