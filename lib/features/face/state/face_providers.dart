import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../setup/state/setup_controller.dart';
import '../../sync/state/send_controller.dart';
import '../data/face_recognizer.dart';
import '../data/face_store.dart';
import '../data/face_template_row.dart';

/// One ArcFace model for the whole app, loaded on first use.
final faceRecognizerProvider = Provider<FaceRecognizer>((ref) {
  final recognizer = FaceRecognizer();
  ref.onDispose(recognizer.dispose);
  return recognizer;
});

/// The faces saved on this phone, by EMP No; also what the recognizer matches against.
/// Reloads after a send (Sync Status changes) and after the site data is refreshed (downloads).
final faceTemplatesProvider = FutureProvider<Map<String, FaceTemplateRow>>((ref) async {
  ref.watch(sendControllerProvider.select((s) => s.revision));
  ref.watch(setupControllerProvider.select((s) => s.info?.refreshedAt));
  final rows = await ref.watch(faceStoreProvider).all();
  ref.read(faceRecognizerProvider).setTemplates({for (final r in rows) r.employeeCode: r.embedding});
  return {for (final r in rows) r.employeeCode: r};
});

/// EMP Nos with a registered face; empty until the faces have loaded.
final registeredFacesProvider = Provider<Map<String, FaceTemplateRow>>(
  (ref) => ref.watch(faceTemplatesProvider).value ?? const {},
);
