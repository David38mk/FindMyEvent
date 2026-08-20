import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_map/flutter_map.dart';

/// Disk-caching tile provider. Tiles a user has seen render instantly from
/// disk (and even offline) instead of re-hitting MapTiler — a pan around
/// Skopje burns ~10–20 tile loads, so caching cuts real quota usage several-fold
/// (the free tier is 100k loads/month, ADR 0001).
///
/// Own ~20 lines instead of flutter_map_tile_caching: FMTC is GPL-licensed
/// (viral for a future closed-source app), and the abandoned-plugin lesson
/// from clustering (HANDOFF 2026-08-19) applies here too.
class CachedTileProvider extends TileProvider {
  CachedTileProvider();

  /// Tiles get their own cache bucket: default cache caps at 200 objects,
  /// which a single map session would blow through. 14-day staleness matches
  /// how often street maps meaningfully change.
  static final _cacheManager = CacheManager(
    Config(
      'mapTiles',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 3000,
    ),
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      CachedNetworkImageProvider(
        getTileUrl(coordinates, options),
        cacheManager: _cacheManager,
      );
}
