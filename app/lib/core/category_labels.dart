import '../l10n/app_localizations.dart';

/// Slug → localized label. Slugs are stable DB identifiers; labels are UI.
///
/// Same table as the private copy inside the map screen — kept here so
/// features outside the map (the organizer form, review headers) can label a
/// category without importing the map. The map's copy can be deleted in
/// favour of this one next time that file is touched.
String categoryLabel(AppLocalizations l10n, String slug) => switch (slug) {
      'party' => l10n.catParty,
      'concert' => l10n.catConcert,
      'standup' => l10n.catStandup,
      'festival' => l10n.catFestival,
      'bar' => l10n.catBar,
      'cigarettes' => l10n.catCigarettes,
      'alcohol' => l10n.catAlcohol,
      'hookah' => l10n.catHookah,
      'betting' => l10n.catBetting,
      'nightshop' => l10n.catNightshop,
      _ => slug,
    };
