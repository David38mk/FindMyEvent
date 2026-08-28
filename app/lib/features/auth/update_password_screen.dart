import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error_text.dart';
import '../../l10n/app_localizations.dart';
import 'auth_errors.dart';
import 'auth_providers.dart';

/// Second half of the password reset: the recovery link puts the app in a
/// temporary recovery session, and this screen spends it on a new password.
/// Opened from [AccountButton] when Supabase emits AuthChangeEvent.passwordRecovery.
class UpdatePasswordScreen extends ConsumerStatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  ConsumerState<UpdatePasswordScreen> createState() =>
      _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends ConsumerState<UpdatePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).updatePassword(_password.text);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      Navigator.of(context).pop();
      showInfoSnack(context, l10n.authPasswordUpdated);
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.authUpdatePassword)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.authNewPassword,
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
                  if (v.length < 8) return l10n.authPasswordTooShort;
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AppErrorText(_error!),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.authUpdatePassword),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
