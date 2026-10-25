import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config.dart';
import '../../../core/api/api_client.dart';
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

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    ref.read(sessionExpiryProvider).listener = expire;
    _lifecycle = AppLifecycleListener(onResume: _checkIdle, onPause: _saveActivity);
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
    _signedIn(session);
  }

  Future<void> logout() async {
    _idleTimer?.cancel();
    await _repo.logout();
    state = const LoggedOut();
  }

  /// LG-06: inactivity, or the server refused to refresh the session.
  Future<void> expire() async {
    if (state is! LoggedIn) return;
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
