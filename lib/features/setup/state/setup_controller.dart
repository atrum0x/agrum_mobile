import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../auth/state/auth_controller.dart';
import '../data/setup_api.dart';
import '../data/setup_cache.dart';

class SetupMessages {
  const SetupMessages._();

  static const offlineSession = 'You logged in without internet. Log out and log in again online to send.';
}

class SetupState {
  const SetupState({this.info, this.refreshing = false, this.error});

  /// Null until the site data has been downloaded once on this phone.
  final CacheInfo? info;
  final bool refreshing;

  /// Why the last refresh failed; the old cache is still used.
  final String? error;
}

/// FSD 5.4: downloads the setup cache at login and after each successful send.
class SetupController extends Notifier<SetupState> {
  @override
  SetupState build() {
    ref.listen(authControllerProvider, (previous, next) {
      if (next is LoggedIn && previous is! LoggedIn) unawaited(refresh());
    });
    // Built once Home first shows, which is right after a login or a restored session
    Future.microtask(() async {
      await _loadInfo();
      if (ref.read(authControllerProvider) is LoggedIn) await refresh();
    });
    return const SetupState();
  }

  SetupCache get _cache => ref.read(setupCacheProvider);

  Future<void> _loadInfo() async {
    final info = await _cache.info();
    if (ref.mounted) state = SetupState(info: info, refreshing: state.refreshing, error: state.error);
  }

  /// Returns why it failed, or null. A failure keeps the old cache.
  Future<String?> refresh() async {
    final auth = ref.read(authControllerProvider);
    if (auth is! LoggedIn || state.refreshing) return null;
    // An offline login has no token; calling the server would end the session
    if (auth.session.offline) return SetupMessages.offlineSession;

    state = SetupState(info: state.info, refreshing: true);
    try {
      final data = await ref.read(setupApiProvider).fetch();
      await _cache.save(data, username: auth.session.profile.username, receivedAt: DateTime.now());
      final info = await _cache.info();
      if (ref.mounted) state = SetupState(info: info);
      return null;
    } on ApiException catch (e) {
      if (ref.mounted) state = SetupState(info: state.info, error: e.message);
      return e.message;
    }
  }
}

final setupControllerProvider = NotifierProvider<SetupController, SetupState>(SetupController.new);
