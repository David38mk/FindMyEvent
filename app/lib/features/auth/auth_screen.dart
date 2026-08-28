import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';
import '../../core/error_text.dart';
import '../../l10n/app_localizations.dart';
import 'auth_errors.dart';
import 'auth_providers.dart';

enum AuthMode { signIn, signUp, resetPassword }

/// Email+password and Google sign-in in one screen. Three modes instead of
/// three routes: the fields overlap almost entirely, and switching modes must
/// not lose what the user already typed.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.initialMode = AuthMode.signIn});

  final AuthMode initialMode;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();

  late AuthMode _mode = widget.initialMode;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {String? notice}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
      if (!mounted) return;
      if (notice != null) {
        setState(() => _notice = notice);
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = authFailureText(AppLocalizations.of(context), e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = authFailureText(AppLocalizations.of(context), e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.read(authServiceProvider);
    final title = switch (_mode) {
      AuthMode.signIn => l10n.authSignIn,
      AuthMode.signUp => l10n.authSignUp,
      AuthMode.resetPassword => l10n.authResetTitle,
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_mode == AuthMode.resetPassword) ...[
                Text(l10n.authResetBody),
                const SizedBox(height: 16),
              ],
              if (_mode == AuthMode.signUp) ...[
                TextFormField(
                  controller: _displayName,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.authDisplayName,
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.authRequiredField
                      : null,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.authEmail,
                  prefixIcon: const Icon(Icons.alternate_email),
                ),
                validator: (v) =>
                    _looksLikeEmail(v) ? null : l10n.authInvalidEmail,
              ),
              if (_mode != AuthMode.resetPassword) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.authPassword,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return l10n.authRequiredField;
                    // Only enforced on sign-up: an existing account may predate
                    // any rule we invent, and rejecting it here would lock the
                    // user out of their own password field.
                    if (_mode == AuthMode.signUp && v.length < 8) {
                      return l10n.authPasswordTooShort;
                    }
                    return null;
                  },
                ),
              ],
              if (_mode == AuthMode.signIn)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _mode = AuthMode.resetPassword;
                              _error = null;
                              _notice = null;
                            }),
                    child: Text(l10n.authForgotPassword),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                AppErrorText(_error!),
              ],
              if (_notice != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.mark_email_read_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_notice!)),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => switch (_mode) {
                          AuthMode.signIn => _run(() => auth.signIn(
                                email: _email.text,
                                password: _password.text,
                              )),
                          AuthMode.signUp => _run(
                              () => auth.signUp(
                                email: _email.text,
                                password: _password.text,
                                displayName: _displayName.text,
                              ),
                              // Stay on the screen: with email confirmation on
                              // there is no session yet, so popping would look
                              // like a silent failure.
                              notice: l10n.authSignUpConfirmEmail,
                            ),
                          AuthMode.resetPassword => _run(
                              () => auth.sendPasswordReset(_email.text),
                              notice: l10n.authResetSent,
                            ),
                        },
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(switch (_mode) {
                        AuthMode.signIn => l10n.authSignIn,
                        AuthMode.signUp => l10n.authSignUp,
                        AuthMode.resetPassword => l10n.authSendResetLink,
                      }),
              ),
              if (_mode != AuthMode.resetPassword && Env.hasGoogleSignIn) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        l10n.authOr,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _google,
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: Text(l10n.authContinueWithGoogle),
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _mode = _mode == AuthMode.signUp
                              ? AuthMode.signIn
                              : AuthMode.signUp;
                          _error = null;
                          _notice = null;
                        }),
                child: Text(_mode == AuthMode.signUp
                    ? l10n.authHaveAccount
                    : l10n.authNoAccount),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Deliberately loose: real validation is the confirmation email. A strict
/// regex here only ever rejects valid addresses.
bool _looksLikeEmail(String? value) {
  final v = value?.trim() ?? '';
  final at = v.indexOf('@');
  return at > 0 && v.indexOf('.', at) > at + 1 && !v.endsWith('.');
}
