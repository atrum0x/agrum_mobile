import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../core/connectivity.dart';
import '../features/auth/state/auth_controller.dart';
import '../features/setup/state/setup_controller.dart';
import '../features/sync/state/send_controller.dart';
import 'agrum_logo.dart';
import 'theme.dart';

/// Light red that stays readable on the dark header, for a failed send.
const _errorOnDark = Color(0xFFFCA5A5);

/// Header for every window: a black-to-green gradient with the logo, the window's name and a
/// one-line live status under it, and the connection icon on the right. The logo is the sync
/// button: it shows the waiting count and does Send Now (FSD 8: online status, waiting-to-send
/// and Send Now always visible). Logout and the details are on the More tab.
class WindowAppBar extends StatelessWidget implements PreferredSizeWidget {
  const WindowAppBar({super.key, required this.title});

  final String title;

  static const height = 68.0;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // The gradient is painted by flexibleSpace; keep Material 3 from tinting it on scroll.
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      // flexibleSpace gets loose height constraints, so a bare DecoratedBox would be 0 px tall
      // and the transparent bar would show the white page; expand it to fill the bar.
      flexibleSpace: const SizedBox.expand(
        child: DecoratedBox(decoration: BoxDecoration(gradient: AppColors.headerGradient)),
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      foregroundColor: Colors.white,
      toolbarHeight: height,
      automaticallyImplyLeading: false,
      leading: const Padding(padding: EdgeInsets.only(left: 8), child: SyncLogo()),
      leadingWidth: 64,
      titleSpacing: 4,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.2)),
          const _StatusLine(),
        ],
      ),
      actions: const [_ConnectionIcon(), SizedBox(width: 8)],
    );
  }
}

/// What the app is doing, or the state of the records on the phone, in one line.
class _StatusLine extends ConsumerWidget {
  const _StatusLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final send = ref.watch(sendControllerProvider);
    final setup = ref.watch(setupControllerProvider);
    final online = ref.watch(onlineProvider).value ?? true;
    final auth = ref.watch(authControllerProvider);
    final offlineSession = auth is LoggedIn && auth.session.offline;
    final waiting = send.waiting;

    final (String text, Color color) = switch (send) {
      SendState(:final activity?) => (activity, Colors.white),
      _ when setup.refreshing => (SendMessages.updatingSiteData, Colors.white),
      SendState(:final result?) => (result.message, result.isError ? _errorOnDark : Colors.white),
      _ when !online && waiting > 0 => ('Offline · $waiting waiting to send', AppColors.pendingOnDark),
      _ when !online => ('Offline · records are saved on this phone', AppColors.pendingOnDark),
      _ when offlineSession && waiting > 0 => ('Logged in offline · $waiting waiting', AppColors.pendingOnDark),
      _ when waiting > 0 => ('$waiting waiting to send', AppColors.pendingOnDark),
      _ when setup.info == null => ('Site data not downloaded yet', AppColors.pendingOnDark),
      _ => ('All sent', Colors.white.withValues(alpha: 0.8)),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
      child: Text(
        text,
        key: ValueKey(text),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: color, height: 1.3),
      ),
    );
  }
}

/// Online / offline as an icon only; the words are in its tooltip and on the More tab.
class _ConnectionIcon extends ConsumerWidget {
  const _ConnectionIcon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineProvider).value ?? true;
    final label = online ? 'Online' : 'Offline · records are saved on this phone';
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: SizedBox.square(
          dimension: 48,
          child: Icon(
            online ? LucideIcons.wifi : LucideIcons.wifiOff,
            color: online ? Colors.white : AppColors.pendingOnDark,
            size: 24,
          ),
        ),
      ),
    );
  }
}

/// The logo as the sync button (Send Now). It plays the leaf animation while sending, beats like a
/// heart while records are waiting, and gets a red mark when a send failed; the badge is the
/// waiting-to-send count.
class SyncLogo extends ConsumerStatefulWidget {
  const SyncLogo({super.key});

  @override
  ConsumerState<SyncLogo> createState() => _SyncLogoState();
}

enum _SyncLook { idle, waiting, sending, failed }

class _SyncLogoState extends ConsumerState<SyncLogo> with SingleTickerProviderStateMixin {
  static const _size = 44.0;

  late final _beat = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  // Two quick beats, then a rest, like a heartbeat
  late final _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18).chain(CurveTween(curve: Curves.easeOut)), weight: 10),
    TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 10),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12).chain(CurveTween(curve: Curves.easeOut)), weight: 10),
    TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 10),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
  ]).animate(_beat);

  _SyncLook? _look;

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  void _animate(_SyncLook look) {
    if (look == _look) return;
    _look = look;
    look == _SyncLook.waiting ? _beat.repeat() : (_beat..stop()..reset());
  }

  @override
  Widget build(BuildContext context) {
    final send = ref.watch(sendControllerProvider);
    final refreshing = ref.watch(setupControllerProvider.select((s) => s.refreshing));
    final look = switch (send) {
      _ when send.sending || refreshing => _SyncLook.sending,
      SendState(result: (isError: true, message: _)) => _SyncLook.failed,
      _ when send.waiting > 0 => _SyncLook.waiting,
      _ => _SyncLook.idle,
    };
    // Starting or stopping a controller notifies listeners, which must not happen mid-build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animate(look);
    });

    final waiting = send.waiting;
    final badge = switch (look) {
      _SyncLook.failed => const _Badge(text: '!', color: _errorOnDark),
      _ when waiting > 0 => _Badge(text: waiting > 99 ? '99+' : '$waiting', color: AppColors.pendingOnDark),
      _ => null,
    };

    return Tooltip(
      message: waiting > 0 ? 'Send Now · $waiting waiting to send' : 'Send Now',
      child: Semantics(
        button: true,
        label: 'Send Now',
        child: InkResponse(
          radius: 28,
          onTap: send.sending
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  ref.read(sendControllerProvider.notifier).sendNow();
                },
          child: SizedBox.square(
            dimension: 56,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                ScaleTransition(
                  scale: _scale,
                  child: AgrumLogo(size: _size, animated: look == _SyncLook.sending),
                ),
                if (badge != null) Positioned(right: 0, top: 4, child: badge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black),
      ),
    );
  }
}
