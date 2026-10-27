import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config.dart';
import '../../../core/api/api_client.dart';
import '../../../core/connectivity.dart';
import '../data/auth_repository.dart';

sealed class AuthState {
  const AuthState();
}

/// Checking for a saved session at start-up.
class AuthRestoring extends AuthState {
  const AuthRestoring();
}

class LoggedOut extends AuthState {
  const LoggedOut({this.message});

  /// Shown on the Login screen, e.g. LG-06 after inactivity.
  final String? message;
}

class LoggedIn extends AuthState {
  const LoggedIn(this.session);

  final Session session;
}

class AuthController extends Notifier<AuthState> {
  Timer? _idleTimer;
  DateTime _lastActivity = DateTime.now();
  DateTime _lastActivitySaved = DateTime.fromMillisecondsSinceEpoch(0);
  AppLifecycleListener? _lifecycle;

  /// The password typed at an offline login, kept in memory only (never stored), so the session can
  /// log in online by itself when the server is reachable again. Gone after an app restart.
  String? _offlinePassword;
  Future<bool>? _goingOnline;

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    ref.read(sessionExpiryProvider).listener = expire;
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _checkIdle();
        unawaited(goOnline());
      },
      onPause: _saveActivity,
    );
    ref.listen(onlineProvider, (previous, next) {
      if (next.value == true && previous?.value != true) unawaited(goOnline());
    });
    ref.onDispose(() {
      _idleTimer?.cancel();
      _lifecycle?.dispose();
    });
    Future.microtask(_restore);
    return const AuthRestoring();
  }

  Future<void> _restore() async {
    final session = await _repo.restore(AppConfig.sessionTimeout);
    if (session == null) {
      state = const LoggedOut();
    } else {
      _signedIn(session);
    }
  }

  /// Throws [LoginException] with the message to show.
  Future<void> login(String username, String password) async {
    final session = await _repo.login(username, password);
    _offlinePassword = session.offline ? password : null;
    _signedIn(session);
  }

  /// An offline session logs in online as soon as it can, so it gets a token to send with (LG-07).
  /// True when the session is online. Safe to call often: only one attempt runs at a time.
  Future<bool> goOnline() {
    final current = state;
    if (current is! LoggedIn) return Future.value(false);
    if (!current.session.offline) return Future.value(true);
    final password = _offlinePassword;
    if (password == null) return Future.value(false);
    return _goingOnline ??= _tryGoOnline(current.session.profile.username, password)
        .whenComplete(() => _goingOnline = null);
  }

  Future<bool> _tryGoOnline(String username, String password) async {
    if (!await ref.read(checkOnlineProvider)()) return false;
    try {
      final session = await _repo.goOnline(username, password);
      if (session == null) return false;
      // Logged out while the call was running: don't bring the session back
      if (state is! LoggedIn) {
        await _repo.logout();
        return false;
      }
      _offlinePassword = null;
      state = LoggedIn(session);
      return true;
    } on LoginException catch (e) {
      // The server is the authority: password changed, person inactive, or no access any more
      _offlinePassword = null;
      if (state is LoggedIn) {
        _idleTimer?.cancel();
        await _repo.expire();
        state = LoggedOut(message: e.message);
      }
      return false;
    }
  }

  Future<void> logout() async {
    _offlinePassword = null;
    _idleTimer?.cancel();
    await _repo.logout();
    state = const LoggedOut();
  }

  /// LG-06: inactivity, or the server refused to refresh the session.
  Future<void> expire() async {
    if (state is! LoggedIn) return;
    _offlinePassword = null;
    _idleTimer?.cancel();
    await _repo.expire();
    state = const LoggedOut(message: LoginMessages.sessionExpired);
  }

  /// Called on every touch while logged in.
  void activity() {
    if (state is! LoggedIn) return;
    _lastActivity = DateTime.now();
    _restartIdleTimer();
    // The timestamp survives an app restart; writing it on every touch is not needed
    if (_lastActivity.difference(_lastActivitySaved) > const Duration(seconds: 30)) _saveActivity();
  }

  void _signedIn(Session session) {
    state = LoggedIn(session);
    _lastActivity = DateTime.now();
    _restartIdleTimer();
  }

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(AppConfig.sessionTimeout, expire);
  }

  // Timers don't run while the app is in the background
  void _checkIdle() {
    if (state is LoggedIn && DateTime.now().difference(_lastActivity) >= AppConfig.sessionTimeout) expire();
  }

  void _saveActivity() {
    if (state is! LoggedIn) return;
    _lastActivitySaved = DateTime.now();
    _repo.recordActivity();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
