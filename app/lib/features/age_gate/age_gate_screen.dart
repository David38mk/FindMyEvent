import 'package:flutter/material.dart';

import '../../core/age_gate_prefs.dart';
import '../../l10n/app_localizations.dart';

/// One-time full-screen gate shown before the map on first launch.
/// Declining leaves the user here — there's no server enforcement to bypass,
/// this is the honest self-attestation described in PLAN.md §5.3.
class AgeGateScreen extends StatefulWidget {
  const AgeGateScreen({super.key, required this.onConfirmed});

  final VoidCallback onConfirmed;

  @override
  State<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends State<AgeGateScreen> {
  bool _declined = false;

  Future<void> _confirm() async {
    await AgeGatePrefs.confirm();
    widget.onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_bar_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.ageGateTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.ageGateBody,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _confirm,
                    child: Text(l10n.ageGateConfirm),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _declined = true),
                  child: Text(l10n.ageGateDecline),
                ),
                if (_declined) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.ageGateDeclinedMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
