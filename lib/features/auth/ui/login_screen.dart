import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/config.dart';
import '../../../app/theme.dart';
import '../../../core/connectivity.dart';
import '../data/auth_repository.dart';
import '../state/auth_controller.dart';

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

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authControllerProvider);
    if (auth is LoggedOut) _formError = auth.message;
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
      setState(() => _formError = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _forgotPassword() {
    ShadToaster.of(context).show(const ShadToast(
      title: Text('Forgot / Change Password'),
      description: Text(LoginMessages.forgotPassword),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final online = ref.watch(onlineProvider).value ?? true;

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
                  const _Brand(),
                  const SizedBox(height: 28),
                  if (!online) ...[
                    const _OfflineNotice(),
                    const SizedBox(height: 16),
                  ],
                  if (_formError != null) ...[
                    ShadAlert.destructive(
                      icon: const Icon(LucideIcons.circleAlert),
                      title: Text(_formError!),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ShadCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FieldLabel('Username'),
                        ShadInput(
                          controller: _username,
                          placeholder: const Text('Your username'),
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
                        _FieldLabel('Password'),
                        ShadInput(
                          controller: _password,
                          focusNode: _passwordFocus,
                          placeholder: const Text('Your password'),
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
                          child: Text(_busy ? 'Logging in…' : 'Login', style: const TextStyle(fontSize: 17)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ShadButton.link(
                    height: 48,
                    onPressed: _forgotPassword,
                    child: Text('Forgot / Change Password', style: TextStyle(color: theme.colorScheme.mutedForeground)),
                  ),
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
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
          child: const Icon(LucideIcons.leaf, color: Colors.white, size: 38),
        ),
        const SizedBox(height: 16),
        Text('Agrum', style: theme.textTheme.h2),
        const SizedBox(height: 4),
        Text('Field supervisor login', style: theme.textTheme.muted),
      ],
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
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.wifiOff, color: AppColors.pending, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No connection. You can still log in if you logged in on this phone '
              'in the last ${AppConfig.offlineLoginDays} days.',
              style: TextStyle(fontSize: 16, color: AppColors.foreground),
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
