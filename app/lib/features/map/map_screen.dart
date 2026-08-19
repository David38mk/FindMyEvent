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

    // Guard: pins are always empty before onMapReady fires (mapBoundsProvider
    // is null until then), so this never touches .camera before FlutterMap
    // has rendered at least once — accessing it earlier throws.
    final clusters =
        pins.isEmpty ? const <_PinCluster>[] : _clusterPins(pins, _mapController.camera);

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
                  for (final cluster in clusters)
                    Marker(
                      point: cluster.center,
                      width: cluster.pins.length > 1 ? 48 : 40,
                      height: cluster.pins.length > 1 ? 48 : 40,
                      child: cluster.pins.length == 1
                          ? _PinMarker(
                              pin: cluster.pins.single,
                              onTap: () => _showPinSheet(cluster.pins.single),
                            )
                          : _ClusterMarker(
                              cluster: cluster,
                              onTap: () => _showClusterSheet(cluster),
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
            if (pin.description != null && pin.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(pin.description!),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showClusterSheet(_PinCluster cluster) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final pin in cluster.pins)
              ListTile(
                leading: Icon(
                  pin.kind == PinKind.event ? Icons.location_on : Icons.storefront,
                  color: pin.color,
                ),
                title: Text(pin.title),
                subtitle: Text([
                  categoryLabel(l10n, pin.categorySlug),
                  if (pin.subtitle != null) pin.subtitle!,
                ].join(' · ')),
                onTap: () {
                  Navigator.of(context).pop();
                  _showPinSheet(pin);
                },
              ),
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

class _PinMarker extends StatelessWidget {
  const _PinMarker({required this.pin, required this.onTap});

  final MapPin pin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        // Shown on mouse hover (web/desktop) and long-press (touch); tap
        // always opens the full detail sheet regardless of platform.
        message: _tooltipText(pin),
        child: Icon(
          pin.kind == PinKind.event ? Icons.location_on : Icons.storefront,
          color: pin.color,
          size: 36,
          shadows: const [Shadow(blurRadius: 4, color: Colors.black45)],
        ),
      ),
    );
  }

  static String _tooltipText(MapPin pin) {
    final description = pin.description;
    if (description == null || description.isEmpty) return pin.title;
    const maxLen = 80;
    final snippet =
        description.length > maxLen ? '${description.substring(0, maxLen)}…' : description;
    return '${pin.title}\n$snippet';
  }
}

class _ClusterMarker extends StatelessWidget {
  const _ClusterMarker({required this.cluster, required this.onTap});

  final _PinCluster cluster;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        // Hover (web/desktop) previews what's inside; tap (all platforms,
        // including mobile where hover doesn't exist) opens the full list.
        message: cluster.pins.map((p) => p.title).join(', '),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black45)],
          ),
          alignment: Alignment.center,
          child: Text(
            '${cluster.pins.length}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// A group of pins collapsed into one marker because they're within
/// [_clusterPins]'s pixel radius of each other at the current zoom.
class _PinCluster {
  _PinCluster(this.pins) : center = _centroid(pins);

  final List<MapPin> pins;
  final LatLng center;

  static LatLng _centroid(List<MapPin> pins) {
    final lat = pins.map((p) => p.lat).reduce((a, b) => a + b) / pins.length;
    final lng = pins.map((p) => p.lng).reduce((a, b) => a + b) / pins.length;
    return LatLng(lat, lng);
  }
}

/// Greedy pixel-distance clustering: pins within [radius] screen pixels of
/// each other (at the map's current zoom/rotation) collapse into one marker.
/// O(n²) — fine for a single city's viewport (dozens to low hundreds of
/// pins); revisit if a Region ever needs more than that on screen at once.
List<_PinCluster> _clusterPins(
  List<MapPin> pins,
  MapCamera camera, {
  double radius = 44,
}) {
  final remaining = [...pins];
  final clusters = <_PinCluster>[];
  while (remaining.isNotEmpty) {
    final seed = remaining.removeAt(0);
    final seedPoint = camera.latLngToScreenOffset(LatLng(seed.lat, seed.lng));
    final group = [seed];
    remaining.removeWhere((pin) {
      final point = camera.latLngToScreenOffset(LatLng(pin.lat, pin.lng));
      if ((point - seedPoint).distance <= radius) {
        group.add(pin);
        return true;
      }
      return false;
    });
    clusters.add(_PinCluster(group));
  }
  return clusters;
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
