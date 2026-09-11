// lib/features/passenger/booking/map_picker_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/core.dart';
import '../../../core/services/geocoding_service.dart';

// Hasil yang dikembalikan ke caller
class MapPickerResult {
  const MapPickerResult({
    required this.latLng,
    required this.name,
  });
  final LatLng latLng;
  final String name;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({
    super.key,
    this.initialLatLng,
    this.title = 'Pilih Lokasi',
  });

  final LatLng? initialLatLng;
  final String  title;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  // Ubah titik tengah bawaan agar tidak menampilkan Bandung
  static const _defaultCenter = LatLng(-6.6023, 106.7628);

  final _mapCtrl = MapController();

  late LatLng _center;
  String  _addressLabel = 'Geser peta untuk memilih lokasi';
  bool    _loadingAddr  = false;
  bool    _isDragging   = false;

  Timer?  _reverseDebounce;

  @override
  void initState() {
    super.initState();
    _center = widget.initialLatLng ?? _defaultCenter; // Menggunakan default baru
    _reverseGeocode(_center);
    if (widget.initialLatLng == null) _flyToGps();
  }

  Future<void> _flyToGps() async {
    final gps = await LocationService.instance.getCurrentPosition();
    if (!mounted) return;
    setState(() => _center = gps);
    _mapCtrl.move(gps, 16);
    _reverseGeocode(gps);
  }

  @override
  void dispose() {
    _reverseDebounce?.cancel();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _loadingAddr = true);
    final name = await GeocodingService.instance.reverseGeocode(pos);
    if (!mounted) return;
    setState(() {
      _addressLabel = name;
      _loadingAddr  = false;
    });
  }

  void _onConfirm() {
    context.pop(MapPickerResult(
      latLng: _center,
      name  : _addressLabel,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.surface,
            shape: BoxShape.circle,
            boxShadow: AppElevation.card,
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: cs.onSurface, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: AppRadius.pillAll,
            boxShadow: AppElevation.card,
          ),
          child: Text(widget.title,
              style: AppTypography.bodyMd.copyWith(
                  fontWeight: FontWeight.w600, color: cs.onSurface)),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 16,
                interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.all),
                onPositionChanged: (pos, hasGesture) {
                  if (!hasGesture) return;
                  if (pos.center == null) return;
                  _center = pos.center!;
                  _reverseDebounce?.cancel();
                  setState(() {
                    _isDragging   = true;
                    _addressLabel = 'Mencari alamat…';
                  });
                  _reverseDebounce = Timer(const Duration(milliseconds: 600), () {
                    if (!mounted) return;
                    setState(() => _isDragging = false);
                    _reverseGeocode(_center);
                  });
                },
              ),
              children: [
                RihlahCachedTileLayer(
                  urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.rihlah',
                  tileBuilder: _tintTile,
                ),
              ],
            ),
          ),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  transform: Matrix4.translationValues(
                      0, _isDragging ? -12 : 0, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary500,
                          boxShadow: AppElevation.floating,
                        ),
                        child: const Icon(Icons.location_on_rounded,
                            color: AppColors.ink0, size: 24),
                      ),
                      Container(width: 2, height: 12,
                          color: AppColors.primary500),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: _isDragging ? 8 : 4,
                        height: _isDragging ? 4 : 2,
                        decoration: BoxDecoration(
                          color: AppColors.ink900.withOpacity(0.2),
                          borderRadius: AppRadius.pillAll,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xl)),
                boxShadow: AppElevation.floating,
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s16, AppSpacing.s16,
                      AppSpacing.s16, AppSpacing.s16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          margin: const EdgeInsets.only(
                              bottom: AppSpacing.s16),
                          decoration: BoxDecoration(
                            color: cs.outline,
                            borderRadius: AppRadius.pillAll,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary100,
                              borderRadius: AppRadius.mdAll,
                            ),
                            child: const Icon(
                                Icons.location_on_rounded,
                                color: AppColors.primary500,
                                size: 20),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: _loadingAddr
                                ? Row(children: [
                              const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                              const SizedBox(width: 8),
                              Text('Mencari alamat…',
                                  style: AppTypography.bodySm
                                      .copyWith(color:
                                  cs.onSurfaceVariant)),
                            ])
                                : Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text('Lokasi dipilih',
                                    style: AppTypography.bodySm
                                        .copyWith(color:
                                    cs.onSurfaceVariant)),
                                Text(
                                  _addressLabel,
                                  style: AppTypography.bodyMd
                                      .copyWith(
                                      fontWeight:
                                      FontWeight.w600,
                                      color: cs.onSurface),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      RihlahButton(
                        label: 'Pilih Lokasi Ini',
                        onPressed: _loadingAddr ? null : _onConfirm,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tile tint ─────────────────────────────────────────────────────────────────

Widget _tintTile(BuildContext ctx, Widget tile, TileImage ti) =>
    ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.85, 0.02, 0.02, 0, 5,
        0.00, 0.90, 0.02, 0, 5,
        0.00, 0.04, 0.78, 0, 8,
        0.00, 0.00, 0.00, 1, 0,
      ]),
      child: tile,
    );