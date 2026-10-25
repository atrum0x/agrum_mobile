import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _isOnline(List<ConnectivityResult> results) => results.any((r) => r != ConnectivityResult.none);

/// Whether the phone has a network. A network does not prove the server is reachable,
/// so callers still treat connection errors as offline.
final onlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield _isOnline(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(_isOnline);
});

/// One-off check, for code that runs outside a widget.
final checkOnlineProvider = Provider<Future<bool> Function()>(
  (ref) => () async => _isOnline(await Connectivity().checkConnectivity()),
);
