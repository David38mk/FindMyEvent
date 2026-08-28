import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../../core/env.dart';
import '../../core/event_image.dart';
import '../../core/map_tiles.dart';
import '../../core/models.dart';
import '../../core/palette.dart';
import '../../l10n/app_localizations.dart';
import '../auth/account_button.dart';
import '../reviews/place_reviews_section.dart';
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
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    // Live expiry (ADR 0004): the server filters ended events per query, so a
    // periodic re-fetch makes finished pins vanish without user interaction.
    _expiryTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) ref.invalidate(mapPinsProvider);
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

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
                urlTemplate: mapTileUrl(Theme.of(context).brightness),
                userAgentPackageName: 'com.findmyevent.findmyevent',
                tileProvider: CachedTileProvider(),
              ),
              MarkerLayer(
                markers: [
                  for (final cluster in clusters)
                    _markerFor(cluster, categoryIndex),
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
          // Top row is night chips + identity only (docs/DESIGN.md § Map
          // chrome): filters moved to a bottom pill, theme into the account
          // sheet — four controls fighting for one row was the old layout's
          // problem, and the chips were being clipped.
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Expanded(child: _NightChips()),
                      SizedBox(width: 8),
                      AccountButton(),
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
          _EventListSheet(
            pins: pins,
            onPinTap: (pin) {
              _mapController.move(LatLng(pin.lat, pin.lng), 16);
              _showPinSheet(pin);
            },
          ),
          // Sits just above the sheet's peek detent (0.10 of the screen).
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.sizeOf(context).height * 0.10 + 12,
              ),
              child: _FilterPill(l10n: l10n),
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

  /// One marker per cluster: events render as cards (poster or generated
  /// artwork), places keep the slate teardrop, a multi-pin cluster becomes a
  /// stack of cards (docs/DESIGN.md § Pin system v2).
  Marker _markerFor(_PinCluster cluster, Map<String, MapCategory> categories) {
    IconData glyphFor(MapPin pin) =>
        iconForName(categories[pin.categorySlug]?.icon);

    if (cluster.pins.length > 1) {
      return Marker(
        point: cluster.center,
        width: 76,
        height: 76,
        // A cluster marks an area, not a spot, so it stays centred.
        child: _ClusterMarker(
          cluster: cluster,
          glyphFor: glyphFor,
          onTap: () => _showClusterSheet(cluster),
        ),
      );
    }

    final pin = cluster.pins.single;
    final isEvent = pin.kind == PinKind.event;
    return Marker(
      point: cluster.center,
      width: isEvent ? 60 : 44,
      height: isEvent ? 68 : 44,
      // topCenter puts the whole widget ABOVE the point (flutter_map's own
      // wording), so a pin's tip — or a card's tail — lands on the coordinate.
      alignment: Alignment.topCenter,
      child: isEvent
          ? _EventCardPin(
              pin: pin,
              glyph: glyphFor(pin),
              live: pin.isLiveAt(DateTime.now()),
              onTap: () => _showPinSheet(pin),
            )
          : _PinMarker(
              pin: pin,
              glyph: glyphFor(pin),
              live: false,
              onTap: () => _showPinSheet(pin),
            ),
    );
  }

  /// Expandable, scrollable detail sheet (docs/DESIGN.md § Detail sheet):
  /// opens at 55% with the essentials, drags to full screen for description
  /// and reviews. Must stay scrollable — PlaceReviewsSection is unbounded.
  void _showPinSheet(MapPin pin) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        snap: true,
        snapSizes: const [0.55],
        builder: (context, controller) =>
            _PinDetail(pin: pin, controller: controller),
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

/// Preset night chips with real dates (docs/DESIGN.md date & night UX):
/// Tonight / Tomorrow / Weekend / pick-a-night. Selection is a NightRange.
class _NightChips extends ConsumerWidget {
  const _NightChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(selectedNightsProvider);
    final tonight = currentEventNight();
    final tomorrow = tonight.add(const Duration(days: 1));
    final weekend = weekendRange();
    final df = DateFormat('EEE d', l10n.localeName);

    final presets = [
      (label: '${l10n.tonight} · ${df.format(tonight)}',
       range: NightRange(tonight, tonight)),
      (label: '${l10n.tomorrow} · ${df.format(tomorrow)}',
       range: NightRange(tomorrow, tomorrow)),
      (label:
          '${l10n.weekend} · ${weekend.from.day}–${weekend.to.day}',
       range: weekend),
    ];
    final isPreset = presets.any((p) => p.range == selected);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final preset in presets)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(preset.label),
                selected: selected == preset.range,
                onSelected: (_) => ref
                    .read(selectedNightsProvider.notifier)
                    .state = preset.range,
              ),
            ),
          ChoiceChip(
            avatar: const Icon(Icons.calendar_month, size: 16),
            label: Text(isPreset
                ? l10n.pickNight
                : df.format(selected.from)),
            selected: !isPreset,
            onSelected: (_) async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selected.from,
                firstDate: tonight,
                lastDate: tonight.add(const Duration(days: 365)),
              );
              if (picked != null) {
                ref.read(selectedNightsProvider.notifier).state =
                    NightRange(picked, picked);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// 3-detent draggable list of the selected nights' events over the map
/// (docs/DESIGN.md: Google-Maps pattern; map/list toggle rejected).
class _EventListSheet extends ConsumerWidget {
  const _EventListSheet({required this.pins, required this.onPinTap});

  final List<MapPin> pins;
  final ValueChanged<MapPin> onPinTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final events = pins.where((p) => p.kind == PinKind.event).toList()
      ..sort((a, b) => (a.startsAt ?? DateTime(2100))
          .compareTo(b.startsAt ?? DateTime(2100)));
    final placeCount = pins.length - events.length;
    final now = DateTime.now();
    final df = DateFormat('EEE d', l10n.localeName);
    final multiNight =
        events.map((e) => e.eventNight).whereType<DateTime>().toSet().length > 1;

    // Peek teaser: the count alone wasted the one line users always see.
    final next = events.where((e) => e.startsAt != null).firstOrNull;
    final headline = events.isEmpty
        ? l10n.noEventsNight
        : '${events.length} ${l10n.eventsLabel}'
            '${next != null ? ' · ${DateFormat.Hm().format(next.startsAt!)} ${next.title}' : ''}';

    return DraggableScrollableSheet(
      initialChildSize: 0.10,
      minChildSize: 0.10,
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const [0.45],
      // Short, eased snap — the default proportional duration feels abrupt.
      snapAnimationDuration: const Duration(milliseconds: 220),
      builder: (context, scrollController) => RepaintBoundary(
          child: Material(
        color: Theme.of(context).cardTheme.color,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        elevation: 8,
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (events.isEmpty)
              _EmptyNight(placeCount: placeCount),
            for (final event in events)
              ListTile(
                leading: Icon(Icons.location_pin, color: event.color),
                title: Text(event.title),
                subtitle: Text([
                  if (event.startsAt != null)
                    '${multiNight ? '${df.format(event.eventNight ?? event.startsAt!)} · ' : ''}${DateFormat.Hm().format(event.startsAt!)}',
                  if (event.subtitle != null) event.subtitle!,
                ].join(' · ')),
                // Solar Yellow NOW badge — always filled with near-black text,
                // both themes (yellow is invisible bare on light, ADR 0005).
                trailing: event.isLiveAt(now)
                    ? Badge(
                        backgroundColor: AppPalette.happeningNow,
                        textColor: Colors.black87,
                        label: Text(l10n.happeningNow),
                      )
                    : null,
                onTap: () => onPinTap(event),
              ),
          ],
        ),
      )),
    );
  }
}

/// Filter button + expandable panel (docs/DESIGN.md filter & legend UX):
/// the panel doubles as the legend — every category shown with its color
/// dot (events) or glyph (places). Badge = active filter count.
/// A quiet night must never dead-end (docs/DESIGN.md § Empty state): offer the
/// next night that actually has something, and point at the places that are
/// open regardless — the vice layer is what nobody else can fall back on.
class _EmptyNight extends ConsumerWidget {
  const _EmptyNight({required this.placeCount});

  final int placeCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selected = ref.watch(selectedNightsProvider);
    final nights = ref.watch(upcomingNightsProvider).valueOrNull ?? const [];
    // The first night with events that isn't the one already being shown.
    final suggestion =
        nights.where((n) => n.night.isAfter(selected.to)).firstOrNull;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (placeCount > 0)
            Text(
              l10n.emptyNightPlaces(placeCount),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          if (suggestion != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.east),
              label: Text(l10n.emptyNightJump(
                DateFormat('EEEE', l10n.localeName).format(suggestion.night),
                suggestion.count,
              )),
              onPressed: () => ref.read(selectedNightsProvider.notifier).state =
                  NightRange(suggestion.night, suggestion.night),
            ),
          ],
        ],
      ),
    );
  }
}

/// Floating pill above the sheet (docs/DESIGN.md § Map chrome layout):
/// thumb-reachable, and the active count stays readable without opening it.
class _FilterPill extends ConsumerWidget {
  const _FilterPill({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCategoriesProvider);
    final filtering = selected.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: filtering ? scheme.primary : Theme.of(context).cardTheme.color,
      shape: const StadiumBorder(),
      elevation: 6,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          builder: (context) => const SafeArea(child: _FilterPanel()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune,
                  size: 18,
                  color: filtering ? scheme.onPrimary : scheme.onSurface),
              const SizedBox(width: 8),
              Text(
                filtering ? '${l10n.filters} · ${selected.length}' : l10n.filters,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: filtering ? scheme.onPrimary : scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
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
  const _PinMarker({
    required this.pin,
    required this.glyph,
    required this.live,
    required this.onTap,
  });

  final MapPin pin;

  /// White category glyph for place pins; null for events (plain head dot).
  final IconData? glyph;

  /// Happening Now (ADR 0004): started, not yet expired — amber head dot.
  final bool live;
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
              top: glyph == null ? (live ? 10 : 12) : 9,
              child: glyph == null
                  ? Container(
                      width: live ? 14 : 10,
                      height: live ? 14 : 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: live ? AppPalette.happeningNow : Colors.white,
                        border: live
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
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

/// Event marker as a card (docs/DESIGN.md § Pin system v2): the poster when
/// there is one, generated artwork from the category otherwise — so the map
/// reads the same whether or not organizers have uploaded anything yet.
/// A live event trades its white frame for Solar Yellow.
class _EventCardPin extends StatelessWidget {
  const _EventCardPin({
    required this.pin,
    required this.glyph,
    required this.live,
    required this.onTap,
  });

  final MapPin pin;
  final IconData glyph;
  final bool live;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: _PinMarker._tooltipText(pin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EventCard(pin: pin, glyph: glyph, live: live, size: 52),
            // Tail: the card floats, this is what actually points at the spot.
            CustomPaint(
              size: const Size(12, 8),
              painter: _TailPainter(
                live ? AppPalette.happeningNow : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The card itself, reused by single pins and by cluster stacks.
class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.pin,
    required this.glyph,
    required this.live,
    required this.size,
  });

  final MapPin pin;
  final IconData glyph;
  final bool live;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = pin.imageUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: pin.color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: live ? AppPalette.happeningNow : Colors.white,
          width: 2.5,
        ),
        boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black54)],
      ),
      clipBehavior: Clip.antiAlias,
      child: image != null && image.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: image,
              fit: BoxFit.cover,
              // Fallback artwork also covers a broken/slow poster, so a card
              // is never an empty rectangle on the map.
              placeholder: (_, _) => _fallback(),
              errorWidget: (_, _, _) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() => ColoredBox(
        color: pin.color,
        child: Center(
          child: Icon(glyph, size: size * 0.45, color: Colors.white),
        ),
      );
}

class _TailPainter extends CustomPainter {
  const _TailPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawShadow(path, Colors.black54, 2, false);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter oldDelegate) => oldDelegate.color != color;
}

/// A cluster renders as a stack of cards (Findzzer's look) rather than a
/// numbered bubble — it reads as "a scene here", not "a number here".
class _ClusterMarker extends StatelessWidget {
  const _ClusterMarker({
    required this.cluster,
    required this.glyphFor,
    required this.onTap,
  });

  final _PinCluster cluster;
  final IconData Function(MapPin) glyphFor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Events first: they are what the stack is advertising.
    final ordered = [...cluster.pins]..sort((a, b) =>
        (a.kind == PinKind.event ? 0 : 1) - (b.kind == PinKind.event ? 0 : 1));
    final top = ordered.take(3).toList();
    final now = DateTime.now();

    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: cluster.pins.map((p) => p.title).join(', '),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            for (var i = top.length - 1; i >= 0; i--)
              Transform.translate(
                offset: Offset(i * 6.0 - 6, i * -5.0 + 5),
                child: Transform.rotate(
                  angle: (i - 1) * 0.11,
                  child: _EventCard(
                    pin: top[i],
                    glyph: glyphFor(top[i]),
                    live: top[i].isLiveAt(now),
                    size: 46,
                  ),
                ),
              ),
            Positioned(
              right: 0,
              bottom: 2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  '${cluster.pins.length}',
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Contents of the expandable detail sheet (docs/DESIGN.md § Detail sheet).
class _PinDetail extends StatelessWidget {
  const _PinDetail({required this.pin, required this.controller});

  final MapPin pin;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // An event held at a Place shows that venue's reviews; a place pin's own
    // id IS the place id.
    final reviewablePlaceId =
        pin.kind == PinKind.place ? pin.id : pin.placeId;

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        if (pin.kind == PinKind.event) ...[
          EventImage(url: pin.imageUrl),
          if (pin.imageUrl != null && pin.imageUrl!.isNotEmpty)
            const SizedBox(height: 16),
        ],
        Row(
          children: [
            Icon(Icons.circle, color: pin.color, size: 14),
            const SizedBox(width: 8),
            Text(
              categoryLabel(l10n, pin.categorySlug),
              style: theme.textTheme.labelLarge,
            ),
            if (pin.isLiveAt(DateTime.now())) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppPalette.happeningNow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.happeningNow,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: Colors.black87, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(pin.title, style: theme.textTheme.headlineSmall),
        if (pin.subtitle != null) ...[
          const SizedBox(height: 4),
          Text(pin.subtitle!, style: theme.textTheme.bodyMedium),
        ],
        if (pin.startsAt != null) ...[
          const SizedBox(height: 4),
          Text(_eventTimeText(l10n, pin), style: theme.textTheme.bodyMedium),
        ],
        if (pin.description != null && pin.description!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(pin.description!),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.directions),
            label: Text(l10n.directions),
            // Universal maps URL: Android/iOS hand it to the installed maps
            // app; falls back to the browser everywhere else.
            onPressed: () => launchUrl(
              Uri.parse(
                'https://www.google.com/maps/dir/?api=1&destination=${pin.lat},${pin.lng}',
              ),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ),
        if (reviewablePlaceId != null) ...[
          const SizedBox(height: 8),
          PlaceReviewsSection(placeId: reviewablePlaceId),
        ],
      ],
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
