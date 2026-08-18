import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../core/env.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';
import 'map_providers.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _skopje = LatLng(41.9981, 21.4254);
  final _mapController = MapController();

  String get _tileUrl => Env.hasMapTiler
      ? 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=${Env.maptilerKey}'
      // OSM demo tiles: dev fallback only, never production (ADR 0001).
      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  void _updateBounds() {
    ref.read(mapBoundsProvider.notifier).state =
        _mapController.camera.visibleBounds;
  }

  Future<void> _goToMyLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    final position = await Geolocator.getCurrentPosition();
    _mapController.move(LatLng(position.latitude, position.longitude), 15);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pinsAsync = ref.watch(mapPinsProvider);
    final selectedCats = ref.watch(selectedCategoriesProvider);

    final pins = (pinsAsync.valueOrNull ?? const <MapPin>[])
        .where((p) =>
            selectedCats.isEmpty || selectedCats.contains(p.categorySlug))
        .toList();

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _skopje,
              initialZoom: 14,
              onMapReady: _updateBounds,
              onMapEvent: (event) {
                if (event is MapEventMoveEnd ||
                    event is MapEventFlingAnimationEnd ||
                    event is MapEventDoubleTapZoomEnd) {
                  _updateBounds();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _tileUrl,
                userAgentPackageName: 'com.findmyevent.findmyevent',
              ),
              MarkerLayer(
                markers: [
                  for (final pin in pins)
                    Marker(
                      point: LatLng(pin.lat, pin.lng),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _showPinSheet(pin),
                        child: Icon(
                          pin.kind == PinKind.event
                              ? Icons.location_on
                              : Icons.storefront,
                          color: pin.color,
                          size: 36,
                          shadows: const [
                            Shadow(blurRadius: 4, color: Colors.black45),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              SimpleAttributionWidget(
                source: Text(
                  Env.hasMapTiler
                      ? '© MapTiler © OpenStreetMap'
                      : '© OpenStreetMap',
                ),
              ),
            ],
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DaySelector(l10n: l10n),
                _CategoryChips(l10n: l10n),
                if (pinsAsync.hasError)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(l10n.pinsLoadError),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.myLocation,
        onPressed: _goToMyLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  void _showPinSheet(MapPin pin) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, color: pin.color, size: 14),
                const SizedBox(width: 8),
                Text(
                  categoryLabel(l10n, pin.categorySlug),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(pin.title, style: Theme.of(context).textTheme.headlineSmall),
            if (pin.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(pin.subtitle!),
            ],
            if (pin.startsAt != null) ...[
              const SizedBox(height: 4),
              Text(DateFormat.MMMEd(l10n.localeName)
                  .add_Hm()
                  .format(pin.startsAt!)),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DaySelector extends ConsumerWidget {
  const _DaySelector({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(selectedDayProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final label = day == today
        ? l10n.today
        : day == tomorrow
            ? l10n.tomorrow
            : DateFormat.MMMEd(l10n.localeName).format(day);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            // No past days — the app's promise is "what's happening", not history.
            onPressed: day.isAfter(today)
                ? () => ref.read(selectedDayProvider.notifier).state =
                    day.subtract(const Duration(days: 1))
                : null,
          ),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => ref.read(selectedDayProvider.notifier).state =
                day.add(const Duration(days: 1)),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final selected = ref.watch(selectedCategoriesProvider);
    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final cat in categories)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: Icon(Icons.circle, color: cat.color, size: 14),
                label: Text(categoryLabel(l10n, cat.slug)),
                selected: selected.contains(cat.slug),
                onSelected: (_) {
                  final next = {...selected};
                  next.contains(cat.slug)
                      ? next.remove(cat.slug)
                      : next.add(cat.slug);
                  ref.read(selectedCategoriesProvider.notifier).state = next;
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Slug → localized label. Slugs are stable DB identifiers; labels are UI.
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
