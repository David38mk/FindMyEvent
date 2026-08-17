import 'package:flutter/material.dart';

import '../../core/env.dart';
import '../../l10n/app_localizations.dart';

/// Phase 0 placeholder — real map (flutter_map + MapTiler) lands in Phase 1.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.mapComingSoon, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              Env.hasSupabase ? l10n.supabaseConnected : l10n.supabaseNotConfigured,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
