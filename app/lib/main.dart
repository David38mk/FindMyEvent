import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/age_gate_prefs.dart';
import 'core/env.dart';
import 'features/age_gate/age_gate_screen.dart';
import 'features/map/map_screen.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // App must boot without keys so anyone can run the UI before getting them.
  if (Env.hasSupabase) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );
  }
  runApp(const ProviderScope(child: FindMyEventApp()));
}

class FindMyEventApp extends StatelessWidget {
  const FindMyEventApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF7B2CBF)),
      home: const _AppGate(),
    );
  }
}

/// Shows the one-time age gate before the map, per the confirmed local flag.
class _AppGate extends StatefulWidget {
  const _AppGate();

  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  late final Future<bool> _ageConfirmed = AgeGatePrefs.isConfirmed();
  bool _justConfirmed = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _ageConfirmed,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: SizedBox.shrink());
        }
        if (snapshot.data! || _justConfirmed) {
          return const MapScreen();
        }
        return AgeGateScreen(
          onConfirmed: () => setState(() => _justConfirmed = true),
        );
      },
    );
  }
}
