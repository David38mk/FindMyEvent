import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/age_gate_prefs.dart';
import 'core/env.dart';
import 'core/theme_provider.dart';
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

class FindMyEventApp extends ConsumerWidget {
  const FindMyEventApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // docs/DESIGN.md: amber brand seed, dark designed first; Auto follows
      // system, user can pin Light/Dark in settings.
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      home: const _AppGate(),
    );
  }

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFFB300),
        brightness: brightness,
      ),
      scaffoldBackgroundColor:
          dark ? const Color(0xFF1A1815) : const Color(0xFFFAF8F5),
      cardTheme: CardThemeData(
        color: dark ? const Color(0xFF262320) : Colors.white,
      ),
    );
    // Manrope: single family, first-class Cyrillic (docs/DESIGN.md typography).
    return base.copyWith(
      textTheme: GoogleFonts.manropeTextTheme(base.textTheme),
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
