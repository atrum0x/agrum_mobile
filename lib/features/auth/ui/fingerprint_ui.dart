import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/theme.dart';
import '../data/auth_repository.dart';
import '../state/fingerprint_controller.dart';
import '../../../core/i18n/app_strings.dart';

/// Asks once after a password login: "Use your fingerprint to log in next time?"
class FingerprintOfferListener extends ConsumerStatefulWidget {
  const FingerprintOfferListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FingerprintOfferListener> createState() => _FingerprintOfferListenerState();
}

class _FingerprintOfferListenerState extends ConsumerState<FingerprintOfferListener> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(fingerprintControllerProvider, (_, fingerprint) {
      if (!fingerprint.offer || _showing) return;
      _showing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
    }, fireImmediately: true);
  }

  Future<void> _ask() async {
    if (!mounted) return;
    final controller = ref.read(fingerprintControllerProvider.notifier);
    final accepted = await showShadDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ShadDialog.alert(
        title: Text(tr.fingerprintOfferTitle),
        description: Text(tr.fingerprintOfferBody),
        actions: [
          ShadButton.outline(
            height: 48,
            child: Text(tr.notNow),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ShadButton(
            height: 48,
            leading: const Icon(LucideIcons.fingerprint, size: 20),
            child: Text(tr.turnOn),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    _showing = false;
    if (accepted == true) {
      if (mounted) await _run(context, controller.acceptOffer);
    } else {
      await controller.declineOffer();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The "Fingerprint login" switch on the More tab.
class FingerprintSetting extends ConsumerWidget {
  const FingerprintSetting({super.key, required this.username});

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fingerprint = ref.watch(fingerprintControllerProvider);
    if (!fingerprint.loaded || !fingerprint.available) return const SizedBox.shrink();
    final on = fingerprint.isOnFor(username);

    return Row(
      children: [
        Icon(LucideIcons.fingerprint, size: 22, color: on ? AppColors.primary : AppColors.mutedForeground),
        const SizedBox(width: 10),
        Expanded(child: Text(tr.loginWithFingerprint, style: const TextStyle(fontSize: 16))),
        ShadSwitch(
          value: on,
          onChanged: (value) => value ? _turnOn(context, ref) : _turnOff(context, ref),
        ),
      ],
    );
  }

  Future<void> _turnOn(BuildContext context, WidgetRef ref) async {
    final password = await showShadDialog<String>(context: context, builder: (_) => const _PasswordDialog());
    if (password == null || password.isEmpty || !context.mounted) return;
    await _run(context, () => ref.read(fingerprintControllerProvider.notifier).enable(username, password));
  }

  Future<void> _turnOff(BuildContext context, WidgetRef ref) async {
    await ref.read(fingerprintControllerProvider.notifier).disable();
    if (!context.mounted) return;
    ShadToaster.of(context).show(ShadToast(title: Text(tr.fingerprintTurnedOff)));
  }
}

/// Turning it on needs the password again, as banking apps ask: the session alone is not enough.
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_password.text.isEmpty) {
      setState(() => _error = LoginMessages.enterPassword); // LG-02
      return;
    }
    Navigator.of(context).pop(_password.text);
  }

  @override
  Widget build(BuildContext context) {
    return ShadDialog(
      title: Text(tr.turnOnFingerprintLogin),
      description: Text(tr.confirmWithPassword),
      actions: [
        ShadButton.outline(height: 48, child: Text(tr.cancel), onPressed: () => Navigator.of(context).pop()),
        ShadButton(height: 48, onPressed: _submit, child: Text(tr.continueLabel)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ShadInput(
              controller: _password,
              autofocus: true,
              obscureText: true,
              placeholder: Text(tr.yourPassword),
              constraints: const BoxConstraints(minHeight: 52),
              leading: const Icon(LucideIcons.lock, size: 20),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_error!, style: const TextStyle(fontSize: 15, color: AppColors.destructive)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Turns fingerprint login on and says how it went.
Future<void> _run(BuildContext context, Future<void> Function() enable) async {
  final toaster = ShadToaster.of(context);
  try {
    await enable();
    toaster.show(ShadToast(
      title: Text(tr.fingerprintIsOn),
      description: Text(tr.fingerprintNextTime),
    ));
  } on FingerprintCanceled {
    // Closed the fingerprint prompt; it can be turned on later in More
  } on LoginException catch (e) {
    toaster.show(ShadToast.destructive(title: Text(tr.fingerprintNotTurnedOn), description: Text(e.message)));
  } catch (_) {
    toaster.show(ShadToast.destructive(
      title: Text(tr.fingerprintNotTurnedOn),
      description: Text(tr.somethingWentWrong),
    ));
  }
}
