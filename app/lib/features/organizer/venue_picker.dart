import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/env.dart';
import '../../core/error_text.dart';
import '../../core/map_tiles.dart';
import '../../l10n/app_localizations.dart';
import '../map/cached_tile_provider.dart';
import 'organizer_providers.dart';

/// Venue choice one: an existing Place. Search sheet over `places`, so the
/// common case (a known club) reuses curated coordinates instead of the
/// organizer guessing them on a map.
Future<PlaceOption?> pickExistingPlace(BuildContext context) {
  return showModalBottomSheet<PlaceOption>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _PlaceSearchSheet(),
  );
}

class _PlaceSearchSheet extends ConsumerStatefulWidget {
  const _PlaceSearchSheet();

  @override
  ConsumerState<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends ConsumerState<_PlaceSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final results = ref.watch(placeSearchProvider(_query));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.organizerSearchPlaces,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AppErrorText(l10n.pinsLoadError),
                ),
              ),
              data: (places) => places.isEmpty
                  ? Center(child: Text(l10n.organizerNoPlacesFound))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: places.length,
                      itemBuilder: (context, index) {
                        final place = places[index];
                        return ListTile(
                          leading: const Icon(Icons.storefront),
                          title: Text(place.name),
                          subtitle:
                              place.address == null ? null : Text(place.address!),
                          onTap: () => Navigator.of(context).pop(place),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Venue choice two: ad-hoc coordinates for an open-air event with no Place
/// (CONTEXT.md: an Event's location is "usually a Place, sometimes ad-hoc
/// coordinates"). Tap the map, confirm.
class PinPickerScreen extends StatefulWidget {
  const PinPickerScreen({super.key, this.initial});

  final LatLng? initial;

  @override
  State<PinPickerScreen> createState() => _PinPickerScreenState();
}

class _PinPickerScreenState extends State<PinPickerScreen> {
  static const _skopje = LatLng(41.9981, 21.4254);
  late LatLng? _picked = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final picked = _picked;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.organizerPickOnMap)),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: picked ?? _skopje,
              initialZoom: 14,
              interactionOptions:
                  const InteractionOptions(flags: InteractiveFlag.all),
              onTap: (_, point) => setState(() => _picked = point),
            ),
            children: [
              ColorFiltered(
                colorFilter: basemapFilter(Theme.of(context).brightness),
                child: TileLayer(
                  urlTemplate: mapTileUrl(Theme.of(context).brightness),
                  userAgentPackageName: 'com.findmyevent.findmyevent',
                  tileProvider: CachedTileProvider(),
                ),
              ),
              if (picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: picked,
                      width: 44,
                      height: 44,
                      // Tip on the exact coordinate, same anchoring rule the
                      // map pins use — a centered icon would lie by ~20px.
                      alignment: Alignment.topCenter,
                      child: Icon(
                        Icons.location_on,
                        size: 44,
                        color: Theme.of(context).colorScheme.primary,
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
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
                color: Theme.of(context).cardTheme.color,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    picked == null
                        ? l10n.organizerTapMapHint
                        : '${l10n.organizerCoordinates}: '
                            '${picked.latitude.toStringAsFixed(5)}, '
                            '${picked.longitude.toStringAsFixed(5)}',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: const Icon(Icons.check),
            label: Text(l10n.organizerConfirmLocation),
            onPressed: picked == null
                ? null
                : () => Navigator.of(context).pop(picked),
          ),
        ),
      ),
    );
  }
}
