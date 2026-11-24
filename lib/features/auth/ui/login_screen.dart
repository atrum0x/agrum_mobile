import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/agrum_logo.dart';
import '../../../app/config.dart';
import '../../../app/theme.dart';
import '../../../core/connectivity.dart';
import '../data/auth_repository.dart';
import '../state/auth_controller.dart';
import '../state/fingerprint_controller.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../shared/widgets/language_picker.dart';

/// FSD 2.1 Login. Online when the server can be reached, otherwise offline login (LG-07).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  String? _usernameError;
  String? _passwordError;
  String? _formError;
  bool _showPassword = false;
  bool _busy = false;

  bool _askedFingerprint = false;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authControllerProvider);
    if (auth is LoggedOut) _formError = auth.message;
    // Ask for the fingerprint as the screen opens, as banking apps do; not right after Logout
    _askedFingerprint = auth is LoggedOut && auth.byUser;
    ref.listenManual(fingerprintControllerProvider, (_, fingerprint) {
      if (!fingerprint.canLogIn) return;
      if (_username.text.isEmpty) _username.text = fingerprint.enabledFor!;
      if (_askedFingerprint) return;
      _askedFingerprint = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fingerprintLogin();
      });
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _formError = null;
      _usernameError = _username.text.trim().isEmpty ? LoginMessages.enterUsername : null; // LG-01
      _passwordError = _password.text.isEmpty ? LoginMessages.enterPassword : null; // LG-02
    });
    if (_usernameError != null || _passwordError != null) return;

    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).login(_username.text, _password.text);
    } on LoginException catch (e) {
      if (!mounted) return;
      _password.clear(); // FSD 2.1: wrong details clear the password field
      setState(() => _formError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _formError = tr.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fingerprintLogin() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _formError = null;
      _busy = true;
    });
    try {
      await ref.read(authControllerProvider.notifier).loginWithFingerprint();
    } on FingerprintCanceled {
      // Closed the prompt or chose "Use password": stay here for the password
    } on LoginException catch (e) {
      if (!mounted) return;
      setState(() => _formError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _formError = tr.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _forgotPassword() {
    ShadToaster.of(
      context,
    ).show(ShadToast(title: Text(tr.forgotChangePassword), description: Text(LoginMessages.forgotPassword)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final online = ref.watch(onlineProvider).value ?? true;
    final fingerprint = ref.watch(fingerprintControllerProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Brand(busy: _busy),
                  const SizedBox(height: 28),
                  if (!online) ...[const _OfflineNotice(), const SizedBox(height: 16)],
                  if (_formError != null) ...[
                    ShadAlert.destructive(icon: const Icon(LucideIcons.circleAlert), title: Text(_formError!)),
                    const SizedBox(height: 16),
                  ],
                  ShadCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FieldLabel(tr.username),
                        ShadInput(
                          controller: _username,
                          placeholder: Text(tr.yourUsername),
                          enabled: !_busy,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                          constraints: const BoxConstraints(minHeight: 52),
                          leading: const Icon(LucideIcons.user, size: 20),
                          onChanged: (_) {
                            if (_usernameError != null) setState(() => _usernameError = null);
                          },
                          onSubmitted: (_) => _passwordFocus.requestFocus(),
                        ),
                        _FieldError(_usernameError),
                        const SizedBox(height: 16),
                        _FieldLabel(tr.password),
                        ShadInput(
                          controller: _password,
                          focusNode: _passwordFocus,
                          placeholder: Text(tr.yourPassword),
                          enabled: !_busy,
                          obscureText: !_showPassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          constraints: const BoxConstraints(minHeight: 52),
                          leading: const Icon(LucideIcons.lock, size: 20),
                          trailing: ShadIconButton.ghost(
                            width: 40,
                            height: 40,
                            icon: Icon(_showPassword ? LucideIcons.eyeOff : LucideIcons.eye, size: 20),
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                          ),
                          onChanged: (_) {
                            if (_passwordError != null) setState(() => _passwordError = null);
                          },
                          onSubmitted: (_) => _submit(),
                        ),
                        _FieldError(_passwordError),
                        const SizedBox(height: 24),
                        ShadButton(
                          width: double.infinity,
                          height: 52,
                          enabled: !_busy,
                          onPressed: _submit,
                          leading: _busy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : null,
                          child: Text(_busy ? tr.loggingIn : tr.login, style: const TextStyle(fontSize: 17)),
                        ),
                        if (fingerprint.canLogIn) ...[
                          const SizedBox(height: 12),
                          ShadButton.outline(
                            width: double.infinity,
                            height: 52,
                            enabled: !_busy,
                            onPressed: _fingerprintLogin,
                            leading: const Icon(LucideIcons.fingerprint, size: 22),
                            child: Text(tr.loginWithFingerprint, style: const TextStyle(fontSize: 17)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ShadButton.link(
                    height: 48,
                    onPressed: _forgotPassword,
                    child: Text(tr.forgotChangePassword, style: TextStyle(color: theme.colorScheme.mutedForeground)),
                  ),
                  const SizedBox(height: 8),
                  Text(tr.language, style: theme.textTheme.small, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const LanguagePicker(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Column(
      children: [
        AgrumLogo(animated: busy),
        const SizedBox(height: 16),
        Text('Agrum', style: theme.textTheme.h2),
        const SizedBox(height: 4),
        Text(tr.fieldSupervisorLogin, style: theme.textTheme.muted),
        if (!AppConfig.isProduction) ...[const SizedBox(height: 12), const _EnvironmentBadge()],
      ],
    );
  }
}

/// Marks the DEV and UAT apps so test data is never entered in the wrong one. Hidden in prod.
class _EnvironmentBadge extends StatelessWidget {
  const _EnvironmentBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.pending.withValues(alpha: 0.12),
          border: Border.all(color: AppColors.pending),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          tr.environmentBadge(AppConfig.environment.toUpperCase()),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.foreground),
        ),
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.pending.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.pending.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.wifiOff, color: AppColors.pending, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr.noConnectionLogin(AppConfig.offlineLoginDays),
              style: const TextStyle(fontSize: 16, color: AppColors.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: ShadTheme.of(context).textTheme.small),
  );
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.message);

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(message!, style: const TextStyle(fontSize: 15, color: AppColors.destructive)),
    );
  }
}
