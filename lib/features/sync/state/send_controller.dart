import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity.dart';
import '../../auth/state/auth_controller.dart';
import '../../setup/state/setup_controller.dart';
import '../data/send_queue.dart';
import '../data/sync_engine.dart';

/// Short texts for the one-line status under the window title.
class SendMessages {
  const SendMessages._();

  static const noConnection = 'Sending failed · no connection';
  static String failed(String reason) => 'Sending failed · $reason';
  static const allSent = 'All sent · site data updated';
  static const offlineSession = 'Logged in offline · log in online to send';
  static const updatingSiteData = 'Updating site data…';
  static String sending(String what, int done, int total) => 'Sending $what $done of $total…';

  static String result(int sent, int rejected) => [
        if (sent > 0) '$sent sent',
        if (rejected > 0) '$rejected rejected',
      ].join(' · ');
}

/// The outcome of the last send, shown for a few seconds.
typedef SendResult = ({String message, bool isError});

class SendState {
  const SendState({this.waiting = 0, this.sending = false, this.revision = 0, this.activity, this.result});

  final int waiting;
  final bool sending;

  /// Goes up after each send, so lists showing Sync Status reload.
  final int revision;

  /// What is happening right now, e.g. "Sending attendance 3 of 12…".
  final String? activity;

  /// The last send's outcome, cleared after a few seconds.
  final SendResult? result;

  SendState copyWith({
    int? waiting,
    bool? sending,
    int? revision,
    String? Function()? activity,
    SendResult? Function()? result,
  }) =>
      SendState(
        waiting: waiting ?? this.waiting,
        sending: sending ?? this.sending,
        revision: revision ?? this.revision,
        activity: activity == null ? this.activity : activity(),
        result: result == null ? this.result : result(),
      );
}

/// The waiting-to-send count and sending (FSD 8, 10.5). Sends by itself after login, when the
/// connection comes back, when the app is resumed and after a record is saved; Send Now on demand.
class SendController extends Notifier<SendState> {
  static const resultShownFor = Duration(seconds: 6);

  AppLifecycleListener? _lifecycle;
  Timer? _resultTimer;

  @override
  SendState build() {
    ref.listen(authControllerProvider, (previous, next) {
      if (next is LoggedIn && previous is! LoggedIn) {
        unawaited(sendInBackground());
      } else {
        unawaited(reloadCount());
      }
    });
    ref.listen(onlineProvider, (previous, next) {
      if (next.value == true && previous?.value != true) unawaited(sendInBackground());
    });
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(sendInBackground()));
    ref.onDispose(() {
      _lifecycle?.dispose();
      _resultTimer?.cancel();
    });
    // Built once Home first shows, right after a login or a restored session
    Future.microtask(sendInBackground);
    return const SendState();
  }

  Future<void> reloadCount() async {
    final auth = ref.read(authControllerProvider);
    final count = auth is LoggedIn ? await ref.read(sendQueueProvider).waitingCount(auth.session.profile.username) : 0;
    if (ref.mounted) state = state.copyWith(waiting: count);
  }

  /// Sends whatever is waiting, without being asked.
  Future<void> sendInBackground() async {
    await reloadCount();
    final auth = ref.read(authControllerProvider);
    if (!ref.mounted || auth is! LoggedIn || state.sending || state.waiting == 0) return;
    if (!await ref.read(checkOnlineProvider)()) return;
    // An offline login first logs in online with the password typed at login (LG-07)
    if (!await ref.read(authControllerProvider.notifier).goOnline()) return;
    await _send(refreshAfter: false);
  }

  /// Send Now: sends, then refreshes the site data (5.4) even when nothing was waiting.
  Future<SendResult?> sendNow() async {
    if (state.sending) return null;
    final auth = ref.read(authControllerProvider);
    if (auth is! LoggedIn) return null;
    if (!await ref.read(checkOnlineProvider)()) return _show((message: SendMessages.noConnection, isError: true));
    if (!await ref.read(authControllerProvider.notifier).goOnline()) {
      return _show((message: SendMessages.offlineSession, isError: true));
    }
    return _send(refreshAfter: true);
  }

  Future<SendResult?> _send({required bool refreshAfter}) async {
    final auth = ref.read(authControllerProvider);
    if (auth is! LoggedIn) return null;
    _resultTimer?.cancel();
    state = state.copyWith(sending: true, result: () => null, activity: () => null);
    try {
      final outcome = await ref.read(syncEngineProvider).run(
            auth.session.profile.username,
            onProgress: (what, done, total) {
              if (ref.mounted) state = state.copyWith(activity: () => SendMessages.sending(what, done, total));
            },
          );
      if (!ref.mounted) return null;
      state = state.copyWith(revision: state.revision + 1, activity: () => null);
      await reloadCount();

      if (!outcome.ok) {
        return _show((
          message: outcome.networkError ? SendMessages.noConnection : SendMessages.failed(outcome.error!),
          isError: true,
        ));
      }
      // 10.5: refresh the cache after a successful send
      String? refreshError;
      if (refreshAfter || outcome.sent > 0) {
        state = state.copyWith(activity: () => SendMessages.updatingSiteData);
        refreshError = await ref.read(setupControllerProvider.notifier).refresh();
        if (!ref.mounted) return null;
        state = state.copyWith(activity: () => null);
      }
      if (outcome.sent == 0 && outcome.rejected == 0) {
        return _show(refreshError == null
            ? (message: SendMessages.allSent, isError: false)
            : (message: SendMessages.failed(refreshError), isError: true));
      }
      return _show((message: SendMessages.result(outcome.sent, outcome.rejected), isError: outcome.rejected > 0));
    } finally {
      if (ref.mounted) state = state.copyWith(sending: false, activity: () => null);
    }
  }

  SendResult _show(SendResult result) {
    _resultTimer?.cancel();
    state = state.copyWith(result: () => result);
    _resultTimer = Timer(resultShownFor, () {
      if (ref.mounted && identical(state.result, result)) state = state.copyWith(result: () => null);
    });
    return result;
  }
}

final sendControllerProvider = NotifierProvider<SendController, SendState>(SendController.new);
