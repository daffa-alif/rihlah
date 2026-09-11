import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

/// Reusable [TileLayer] with disk + memory caching for offline resilience.
///
/// SRS D-S3: "Offline map tiles cached for service area (Bandung Kota +
/// Cimahi)."  Uses [CancellableNetworkTileProvider] which persists tiles
/// to disk so previously-viewed areas remain available without internet.
class RihlahCachedTileLayer extends StatelessWidget {
  const RihlahCachedTileLayer({
    super.key,
    this.urlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.userAgentPackageName = 'com.example.rihlah',
    this.tileBuilder,
  });

  final String urlTemplate;
  final String userAgentPackageName;
  final TileBuilder? tileBuilder;

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: urlTemplate,
      userAgentPackageName: userAgentPackageName,
      tileProvider: CancellableNetworkTileProvider(),
      tileBuilder: tileBuilder,
    );
  }
}
