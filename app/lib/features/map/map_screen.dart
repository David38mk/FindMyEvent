import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/env.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';
import 'cached_tile_provider.dart';
import 'map_providers.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _skopje = LatLng(41.9981, 21.4254);
  final _mapController = MapController();

  /// dataviz styles (docs/DESIGN.md): near-monochrome basemap so pins and the
  /// amber brand are the only loud things on screen; variant follows theme.
  String _tileUrl(Brightness brightness) => Env.hasMapTiler
      ? 'https://api.maptiler.com/maps/${brightness == Brightness.dark ? 'dataviz-dark' : 'dataviz'}/{z}/{x}/{y}.png?key=${Env.maptilerKey}'
      // OSM demo tiles: dev fallback only, never production (ADR 0001).
      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  void _updateBounds() {
    ref.read(mapBoundsProvider.notifier).state =
        _mapController.camera.visibleBounds;
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom + delta);
    // Programmatic moves fire no MapEventMoveEnd — refresh pins ourselves.
    _updateBounds();
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
    final categoryIndex = {
      for (final c
          in ref.watch(categoriesProvider).valueOrNull ?? const <MapCategory>[])
        c.slug: c,
    };

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
              // Explicit: mouse wheel must zoom (desktop/web testing), all
              // touch gestures on. Note: inside the Android emulator the host
              // wheel is translated to a touch fling before the app sees it —
              // that's emulator behavior, not ours (Ctrl+drag = pinch there).
              interactionOptions:
                  const InteractionOptions(flags: InteractiveFlag.all),
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
                urlTemplate: _tileUrl(Theme.of(context).brightness),
                userAgentPackageName: 'com.findmyevent.findmyevent',
                tileProvider: CachedTileProvider(),
              ),
              MarkerLayer(
                markers: [
                  for (final cluster in clusters)
                    Marker(
                      point: cluster.center,
                      width: cluster.pins.length > 1 ? 48 : 44,
                      height: cluster.pins.length > 1 ? 48 : 44,
                      // Single pins anchor their TIP at the coordinate
                      // (topCenter = widget sits above the point); cluster
                      // bubbles stay centered — they mark an area, not a spot.
                      alignment: cluster.pins.length == 1
                          ? Alignment.topCenter
                          : Alignment.center,
                      child: cluster.pins.length == 1
                          ? _PinMarker(
                              pin: cluster.pins.single,
                              glyph: cluster.pins.single.kind == PinKind.place
                                  ? iconForName(categoryIndex[
                                          cluster.pins.single.categorySlug]
                                      ?.icon)
                                  : null,
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      const Expanded(child: _DaySelector()),
                      const SizedBox(width: 8),
                      _FilterButton(l10n: l10n),
                    ],
                  ),
                ),
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'zoomIn',
            tooltip: l10n.zoomIn,
            onPressed: () => _zoomBy(1),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'zoomOut',
            tooltip: l10n.zoomOut,
            onPressed: () => _zoomBy(-1),
            child: const Icon(Icons.remove),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'myLocation',
            tooltip: l10n.myLocation,
            onPressed: _goToMyLocation,
            child: const Icon(Icons.my_location),
          ),
        ],
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
              Text(_eventTimeText(l10n, pin)),
            ],
            if (pin.description != null && pin.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(pin.description!),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.directions),
                label: Text(l10n.directions),
                // Universal maps URL: Android/iOS hand it to the installed
                // maps app; falls back to browser everywhere else.
                onPressed: () => launchUrl(
                  Uri.parse(
                    'https://www.google.com/maps/dir/?api=1&destination=${pin.lat},${pin.lng}',
                  ),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
            const SizedBox(height: 8),
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
  const _DaySelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
      margin: EdgeInsets.zero,
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

/// Filter button + expandable panel (docs/DESIGN.md filter & legend UX):
/// the panel doubles as the legend — every category shown with its color
/// dot (events) or glyph (places). Badge = active filter count.
class _FilterButton extends ConsumerWidget {
  const _FilterButton({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCategoriesProvider);
    return Card(
      margin: EdgeInsets.zero,
      child: IconButton(
        tooltip: l10n.filters,
        icon: Badge(
          isLabelVisible: selected.isNotEmpty,
          label: Text('${selected.length}'),
          child: const Icon(Icons.filter_list),
        ),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          builder: (context) => const SafeArea(child: _FilterPanel()),
        ),
      ),
    );
  }
}

class _FilterPanel extends ConsumerWidget {
  const _FilterPanel();

  /// Empty selection = "all". First tap from "all" isolates the tapped
  /// category; selecting every category collapses back to "all".
  void _tap(WidgetRef ref, String slug, int totalCount) {
    final selected = ref.read(selectedCategoriesProvider);
    Set<String> next;
    if (selected.isEmpty) {
      next = {slug};
    } else {
      next = {...selected};
      next.contains(slug) ? next.remove(slug) : next.add(slug);
    }
    if (next.length == totalCount) next = {};
    ref.read(selectedCategoriesProvider.notifier).state = next;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final selected = ref.watch(selectedCategoriesProvider);
    final showAll = selected.isEmpty;

    Widget tile(MapCategory cat) {
      final isOn = showAll || selected.contains(cat.slug);
      return ListTile(
        dense: true,
        leading: cat.kind == 'event'
            ? Icon(Icons.circle, color: cat.color, size: 16)
            : CircleAvatar(
                radius: 10,
                backgroundColor: cat.color,
                child: Icon(iconForName(cat.icon),
                    size: 12, color: Colors.white),
              ),
        title: Text(categoryLabel(l10n, cat.slug)),
        trailing: isOn
            ? Icon(Icons.check,
                color: Theme.of(context).colorScheme.primary, size: 20)
            : null,
        onTap: () => _tap(ref, cat.slug, categories.length),
      );
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.filters,
                  style: Theme.of(context).textTheme.titleMedium),
              TextButton(
                onPressed: showAll
                    ? null
                    : () => ref
                        .read(selectedCategoriesProvider.notifier)
                        .state = {},
                child: Text(l10n.filterAll),
              ),
            ],
          ),
        ),
        for (final cat in categories.where((c) => c.kind == 'event')) tile(cat),
        const Divider(),
        for (final cat in categories.where((c) => c.kind == 'place')) tile(cat),
      ],
    );
  }
}

class _PinMarker extends StatelessWidget {
  const _PinMarker({required this.pin, required this.glyph, required this.onTap});

  final MapPin pin;

  /// White category glyph for place pins; null for events (plain head dot).
  final IconData? glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        // Shown on mouse hover (web/desktop) and long-press (touch); tap
        // always opens the full detail sheet regardless of platform.
        message: _tooltipText(pin),
        // Classic pin, tip on the exact coordinate (marker anchors topCenter).
        // docs/DESIGN.md pin system: events = curated hue + plain head,
        // places = neutral slate + white category glyph. No time indication.
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Icon(
              Icons.location_pin,
              color: pin.color,
              size: 44,
              shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
            Positioned(
              top: glyph == null ? 12 : 9,
              child: glyph == null
                  ? Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    )
                  : Icon(glyph, size: 14, color: Colors.white),
            ),
          ],
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

/// Material icon name (from the DB `categories.icon` column) → IconData.
/// Flutter can't look up icons by string at runtime without pulling the whole
/// icon font map in — a small const map over our 10 categories is enough.
const _materialIcons = <String, IconData>{
  'celebration': Icons.celebration,
  'music_note': Icons.music_note,
  'mic': Icons.mic,
  'festival': Icons.festival,
  'local_bar': Icons.local_bar,
  'smoking_rooms': Icons.smoking_rooms,
  'liquor': Icons.liquor,
  'air': Icons.air,
  'casino': Icons.casino,
  'storefront': Icons.storefront,
};

IconData iconForName(String? name) => _materialIcons[name] ?? Icons.place;

/// Start time, plus the full date range when the event spans several days
/// (docs/DESIGN.md: duration lives in the detail view, not on the pin).
String _eventTimeText(AppLocalizations l10n, MapPin pin) {
  final df = DateFormat.MMMEd(l10n.localeName);
  final start = df.add_Hm().format(pin.startsAt!);
  final end = pin.endsAt;
  if (end == null) return start;
  final sameDay = end.year == pin.startsAt!.year &&
      end.month == pin.startsAt!.month &&
      end.day == pin.startsAt!.day;
  return sameDay ? start : '$start — ${df.format(end)}';
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
