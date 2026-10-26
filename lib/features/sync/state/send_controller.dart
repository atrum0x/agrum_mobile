import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity.dart';
import '../../auth/state/auth_controller.dart';
import '../../setup/state/setup_controller.dart';
import '../data/send_queue.dart';

class SendMessages {
  const SendMessages._();

  static const noConnection = 'No connection. Records stay saved on this phone and are sent when you are back online.';
  static const nothingWaiting = 'Nothing waiting to send. Site data is up to date.';
}

class SendState {
  const SendState({this.waiting = 0, this.sending = false});

  final int waiting;
  final bool sending;
}

typedef SendResult = ({String message, bool isError});

/// The waiting-to-send count and Send Now, shown on every window (FSD 8, 10.5).
class SendController extends Notifier<SendState> {
  @override
  SendState build() {
    ref.listen(authControllerProvider, (_, _) => reloadCount());
    Future.microtask(reloadCount);
    return const SendState();
  }

  Future<void> reloadCount() async {
    final auth = ref.read(authControllerProvider);
    final count = auth is LoggedIn ? await ref.read(sendQueueProvider).waitingCount(auth.session.profile.username) : 0;
    if (ref.mounted) state = SendState(waiting: count, sending: state.sending);
  }

  Future<SendResult?> sendNow() async {
    if (state.sending) return null;
    if (!await ref.read(checkOnlineProvider)()) return (message: SendMessages.noConnection, isError: true);

    state = SendState(waiting: state.waiting, sending: true);
    try {
      // The send queue (attendance first, then weighings) plugs in here; then the 5.4 refresh
      final error = await ref.read(setupControllerProvider.notifier).refresh();
      await reloadCount();
      if (error != null) return (message: error, isError: true);
      return (message: SendMessages.nothingWaiting, isError: false);
    } finally {
      if (ref.mounted) state = SendState(waiting: state.waiting);
    }
  }
}

final sendControllerProvider = NotifierProvider<SendController, SendState>(SendController.new);
