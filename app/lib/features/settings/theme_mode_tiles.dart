import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme_provider.dart';
import '../../l10n/app_localizations.dart';

/// Auto / Light / Dark radio tiles (docs/DESIGN.md § Theme override).
///
/// Lives in the account sheet rather than on the map: it is a rarely-touched
/// setting, and the map chrome budget belongs to night chips, identity and
/// filters (docs/DESIGN.md § Map chrome layout).
class ThemeModeTiles extends ConsumerWidget {
  const ThemeModeTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(themeModeProvider);
    return RadioGroup<ThemeMode>(
      groupValue: mode,
      onChanged: (m) => ref.read(themeModeProvider.notifier).set(m!),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(l10n.settings,
                style: Theme.of(context).textTheme.titleSmall),
          ),
          RadioListTile<ThemeMode>(
            dense: true,
            title: Text(l10n.themeAuto),
            value: ThemeMode.system,
          ),
          RadioListTile<ThemeMode>(
            dense: true,
            title: Text(l10n.themeLight),
            value: ThemeMode.light,
          ),
          RadioListTile<ThemeMode>(
            dense: true,
            title: Text(l10n.themeDark),
            value: ThemeMode.dark,
          ),
        ],
      ),
    );
  }
}
