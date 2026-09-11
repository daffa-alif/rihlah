import 'dart:async';
import 'dart:math' show pi;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart'; // ← Import Hive ditambahkan
import 'package:latlong2/latlong.dart';
import '../../core/core.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/routing_service.dart';
import '../../core/utils/gps_fix_filter.dart';
import '../../data/models/trip_model.dart' hide TripStatus;

// Helper kalkulasi jarak
const _kDistance = Distance();

/// Read-only live-tracking view opened from a "Bagikan perjalanan" link
class TripTrackingScreen extends StatefulWidget {
  const TripTrackingScreen({super.key, required this.tripId});
  final String tripId;

  @override
  State<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends State<TripTrackingScreen>
    with SingleTickerProviderStateMixin {
  final _mapController = MapController();

  TripModel? _trip;
  String? _error;
  LatLng? _driverPos;
  double _driverHeading = 0.0;

  StreamSubscription? _tripSub;
  StreamSubscription? _gpsSub;
  String? _driverId;
  String _driverName = 'Mencari Driver...';

  // Variabel untuk menampung Rute Garis
  List<LatLng> _routePath = []; // Pickup -> Dropoff
  List<LatLng> _approachPath = []; // Driver -> Pickup
  bool _hasFetchedMainRoute = false;
  bool _hasFetchedApproachRoute = false;

  // Estimasi Jarak & Waktu
  int _etaSeconds = 0;
  double _remainingKm = 0.0;

  // Smooth marker movement
  final _gpsFilter = GpsFixFilter();
  AnimationController? _smoothCtrl;
  LatLng _smoothFrom = const LatLng(0, 0);
  LatLng _smoothTo   = const LatLng(0, 0);
  double _smoothHeadingTo = 0.0;
  DateTime? _lastFixAt;
  bool _isFirstFix = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (FirebaseAuth.instance.currentUser == null) {
      try {
        // Sign-in anonim agar orang luar bisa baca database
        await FirebaseAuth.instance.signInAnonymously();
      } catch (_) {
        if (mounted) setState(() => _error = 'Tidak bisa memuat perjalanan');
        return;
      }
    }
    if (!mounted) return;

    _tripSub = FirestoreService.instance.tripStream(widget.tripId).listen(
          (trip) {
        if (!mounted) return;
        if (trip == null) {
          setState(() => _error = 'Perjalanan tidak ditemukan');
          return;
        }
        setState(() => _trip = trip);

        // Tarik rute utama
        if (!_hasFetchedMainRoute) {
          _hasFetchedMainRoute = true;
          _fetchMainRoute(
            LatLng(trip.pickupLat, trip.pickupLng),
            LatLng(trip.dropoffLat, trip.dropoffLng),
            trip.serviceType,
          );
        }

        // ── 1. CEK STATUS: Jika selesai/batal, hentikan pelacakan GPS! ──
        if (trip.status.name == 'completed' || trip.status.name == 'cancelled') {
          _gpsSub?.cancel();
          _gpsSub = null;
          _smoothCtrl?.stop();

          // Kunci posisi ikon mobil di titik tujuan (dropoff) jika selesai
          if (trip.status.name == 'completed') {
            setState(() {
              _driverPos = LatLng(trip.dropoffLat, trip.dropoffLng);
              _etaSeconds = 0;
              _remainingKm = 0.0;
            });
            try { _mapController.move(_driverPos!, 16); } catch (_) {}
          }
          return;
        }

        // ── 2. Jika perjalanan MASIH AKTIF, mulai/lanjutkan pelacakan ──
        if (trip.driverId != null && _gpsSub == null) {
          _driverId = trip.driverId;
          _fetchDriverInfo(_driverId!);

          _gpsSub = FirestoreService.instance
              .driverLocationStream(_driverId!)
              .listen((data) {
            if (!mounted || data == null) return;

            final lat = (data['lat'] as num?)?.toDouble();
            final lng = (data['lng'] as num?)?.toDouble();
            final heading = (data['headingDeg'] as num?)?.toDouble() ?? 0.0;

            if (lat == null || lng == null) return;

            final accepted = _gpsFilter.filter(LatLng(lat, lng));
            if (accepted == null) return;

            // Tarik rute penjemputan satu kali
            if (!_hasFetchedApproachRoute &&
                trip.status.name != 'inTrip' &&
                trip.status.name != 'completed') {
              _hasFetchedApproachRoute = true;
              _fetchApproachRoute(
                accepted.pos,
                LatLng(trip.pickupLat, trip.pickupLng),
                trip.serviceType,
              );
            }

            final headingRad = heading * (pi / 180);
            _smoothMoveTo(accepted.pos, headingRad);
            _recalcEta();
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() => _error = 'Tidak bisa memuat perjalanan');
      },
    );
  }

  Future<void> _fetchDriverInfo(String driverId) async {
    try {
      final user = await FirestoreService.instance.getUser(driverId);
      if (mounted && user != null) {
        setState(() => _driverName = user.name);
      }
    } catch (_) {}
  }

  Future<void> _fetchMainRoute(LatLng pickup, LatLng dropoff, String? serviceType) async {
    try {
      final res = await RoutingService.instance.getRoute(pickup, dropoff, serviceType: serviceType);
      if (mounted && res.points.length >= 2) {
        setState(() => _routePath = res.points);
      } else if (mounted) {
        setState(() => _routePath = [pickup, dropoff]);
      }
    } catch (_) {}
  }

  Future<void> _fetchApproachRoute(LatLng driverPos, LatLng pickup, String? serviceType) async {
    try {
      final res = await RoutingService.instance.getRoute(driverPos, pickup, serviceType: serviceType);
      if (mounted && res.points.length >= 2) {
        setState(() => _approachPath = res.points);
      } else if (mounted) {
        setState(() => _approachPath = [driverPos, pickup]);
      }
    } catch (_) {}
  }

  void _recalcEta() {
    if (_trip == null || _driverPos == null) return;
    if (_trip!.status.name == 'completed' || _trip!.status.name == 'cancelled') return;

    final bool isInTrip = _trip!.status.name == 'inTrip';
    final path = isInTrip ? _routePath : _approachPath;

    if (path.length < 2) return;

    final gpsPos = _driverPos!;
    int closestIdx = 0;
    double minDist = double.infinity;

    for (int i = 0; i < path.length; i++) {
      final d = _kDistance.as(LengthUnit.Meter, gpsPos, path[i]);
      if (d < minDist) { minDist = d; closestIdx = i; }
    }

    double remainingMeters = 0;
    for (int i = closestIdx; i < path.length - 1; i++) {
      remainingMeters += _kDistance.as(LengthUnit.Meter, path[i], path[i + 1]);
    }

    const speedMs = 25.0 * 1000 / 3600;
    final seconds = (remainingMeters / speedMs).round();

    if (mounted) {
      setState(() {
        _etaSeconds = seconds.clamp(0, 9999);
        _remainingKm = remainingMeters / 1000;
      });
    }
  }

  void _smoothMoveTo(LatLng target, double newHeading) {
    if (_isFirstFix) {
      setState(() {
        _driverPos = target;
        _driverHeading = newHeading;
        _isFirstFix = false;
      });
      try { _mapController.move(target, 16); } catch (_) {}
      return;
    }

    final now = DateTime.now();
    final elapsedMs = _lastFixAt == null
        ? 800
        : now.difference(_lastFixAt!).inMilliseconds.clamp(400, 3000);
    _lastFixAt = now;

    _smoothCtrl ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addListener(() {
      if (!mounted) return;
      final t = _smoothCtrl!.value;

      final pos = LatLng(
        _smoothFrom.latitude  + (_smoothTo.latitude  - _smoothFrom.latitude)  * t,
        _smoothFrom.longitude + (_smoothTo.longitude - _smoothFrom.longitude) * t,
      );

      double currentHeading = _driverHeading;
      double targetHeading = _smoothHeadingTo;
      double diff = targetHeading - currentHeading;

      if (diff > pi) {
        currentHeading += 2 * pi;
      } else if (diff < -pi) {
        currentHeading -= 2 * pi;
      }

      setState(() {
        _driverPos = pos;
        _driverHeading = currentHeading + (targetHeading - currentHeading) * t;
      });

      try { _mapController.move(pos, 16); } catch (_) {}
    });

    _smoothFrom = _driverPos ?? target;
    _smoothTo   = target;
    _smoothHeadingTo = newHeading;

    _smoothCtrl!
      ..duration = Duration(milliseconds: elapsedMs)
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _tripSub?.cancel();
    _gpsSub?.cancel();
    _smoothCtrl?.dispose();
    super.dispose();
  }

  String get _statusLabel => switch (_trip?.status.name) {
    'searching' => 'Mencari driver…',
    'accepted'  => 'Menuju penjemputan',
    'arriving'  => 'Hampir sampai di penjemputan',
    'arrived'   => 'Tiba di penjemputan',
    'inTrip'    => 'Dalam perjalanan',
    'completed' => 'Perjalanan selesai',
    'cancelled' => 'Perjalanan dibatalkan',
    _           => 'Memuat…',
  };

  String get _etaFormat {
    if (_trip?.status.name == 'completed') return 'Tiba';
    if (_trip?.status.name == 'cancelled') return 'Batal';
    if (_etaSeconds <= 0 && _trip?.status.name != 'inTrip') return 'Tiba';
    final m = (_etaSeconds / 60).ceil();
    return '$m mnt';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lacak Perjalanan')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link_off_rounded, size: 40, color: cs.onSurfaceVariant),
                const SizedBox(height: AppSpacing.s12),
                Text(_error!, textAlign: TextAlign.center,
                    style: AppTypography.bodyMd.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      );
    }

    final trip = _trip;
    if (trip == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary500)),
      );
    }

    final pickup  = LatLng(trip.pickupLat, trip.pickupLng);
    final dropoff = LatLng(trip.dropoffLat, trip.dropoffLng);
    final center  = _driverPos ?? pickup;

    final bool isInTrip = trip.status.name == 'inTrip' || trip.status.name == 'completed';

    return Scaffold(
      body: Stack(
        children: [
          // ── MAP LAYER ──
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: center, initialZoom: 15),
              children: [
                RihlahCachedTileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.rihlah',
                ),

                if (_routePath.isNotEmpty || _approachPath.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      if (_routePath.isNotEmpty)
                        Polyline(
                          points: _routePath,
                          strokeWidth: 4,
                          color: AppColors.primary500.withValues(alpha: isInTrip ? 0.6 : 0.25),
                        ),
                      if (!isInTrip && _approachPath.isNotEmpty)
                        Polyline(
                          points: _approachPath,
                          strokeWidth: 4,
                          color: AppColors.primary500.withValues(alpha: 0.6),
                        ),
                    ],
                  ),

                MarkerLayer(markers: [
                  Marker(
                    point: pickup,
                    width: 24, height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary500,
                        border: Border.all(color: AppColors.ink0, width: 2.5),
                      ),
                    ),
                  ),
                  Marker(
                    point: dropoff,
                    width: 24, height: 24,
                    child: const Icon(Icons.location_on_rounded,
                        color: AppColors.danger500, size: 28),
                  ),
                  if (_driverPos != null)
                    Marker(
                      point: _driverPos!,
                      width: 44, height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary500,
                          border: Border.all(color: AppColors.ink0, width: 3),
                          boxShadow: AppElevation.floating,
                        ),
                        child: Transform.rotate(
                          angle: _driverHeading,
                          child: const Icon(Icons.directions_car_rounded,
                              color: AppColors.ink0, size: 20),
                        ),
                      ),
                    ),
                ]),
              ],
            ),
          ),

          // ── TOMBOL KEMBALI AMAN ──
          Positioned(
            top: MediaQuery.of(context).padding.top + AppSpacing.s8,
            left: AppSpacing.s16,
            child: GestureDetector(
              onTap: () {
                if (context.canPop()) {
                  // Jika ada history halaman (dibuka dari dalam app)
                  context.pop();
                } else {
                  // Fallback: Jika dibuka dari Link luar
                  final box = Hive.box('settings');
                  final isLoggedIn = box.get('is_logged_in', defaultValue: false);

                  if (isLoggedIn) {
                    // Jika pengguna ini memang punya akun di HP-nya
                    final role = box.get('user_role', defaultValue: 'passenger');
                    if (role == 'driver') {
                      context.go('/d/home');
                    } else {
                      context.go('/p/home');
                    }
                  } else {
                    // PENGUNJUNG ANONIM: Putus koneksi anonim dan tendang ke halaman Splash/Login
                    FirebaseAuth.instance.signOut();
                    context.go('/splash');
                  }
                }
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.surface,
                  shape: BoxShape.circle,
                  boxShadow: AppElevation.floating,
                ),
                child: Icon(Icons.arrow_back_rounded, color: cs.onSurface, size: 20),
              ),
            ),
          ),

          // ── TOP PANEL (Alamat) ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            left: AppSpacing.s16,
            right: AppSpacing.s16,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.95),
                borderRadius: AppRadius.lgAll,
                boxShadow: AppElevation.floating,
              ),
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary500)),
                      Container(width: 2, height: 16, color: cs.outlineVariant),
                      const Icon(Icons.location_on_rounded, color: AppColors.danger500, size: 12),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trip.pickupAddress, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface)),
                        const SizedBox(height: 8),
                        Text(trip.dropoffAddress, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── BOTTOM PANEL (Detail Lengkap) ──
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
                boxShadow: AppElevation.floating,
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outline, borderRadius: AppRadius.pillAll)),
                      const SizedBox(height: AppSpacing.s16),

                      // Status & ETA Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_statusLabel, style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant)),
                                const SizedBox(height: 2),
                                Text(
                                  trip.status.name == 'completed' ? 'Perjalanan Telah Selesai' :
                                  trip.status.name == 'cancelled' ? 'Perjalanan Dibatalkan' :
                                  '$_etaFormat  ·  ${_remainingKm.toStringAsFixed(1)} km',
                                  style: AppTypography.h2.copyWith(color: cs.onSurface),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.primary100, borderRadius: AppRadius.pillAll),
                            child: Text(trip.serviceType?.toUpperCase() ?? 'RIHLAH',
                                style: AppTypography.label.copyWith(color: AppColors.primary600)),
                          ),
                        ],
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.s16),
                        child: Divider(height: 1),
                      ),

                      // Person Cards
                      _PersonCard(name: _driverName, role: 'Driver', isDriver: true),
                      const SizedBox(height: AppSpacing.s12),
                      _PersonCard(name: trip.passengerName ?? 'Penumpang', role: 'Penumpang', isDriver: false),

                      const SizedBox(height: AppSpacing.s16),

                      // Footer info
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.s12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: AppRadius.mdAll,
                        ),
                        child: Row(
                          children: [
                            Icon(
                                trip.status.name == 'completed' ? Icons.check_circle_rounded : Icons.security_rounded,
                                size: 16, color: cs.onSurfaceVariant
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Expanded(
                              child: Text(
                                trip.status.name == 'completed'
                                    ? 'Perjalanan ini sudah selesai dan tidak lagi membagikan lokasi.'
                                    : 'Tracking ini dibagikan oleh penumpang. Diperbarui otomatis.',
                                style: AppTypography.label.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
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

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.name, required this.role, required this.isDriver});
  final String name;
  final String role;
  final bool isDriver;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isDriver ? AppColors.info500 : AppColors.accent500;
    final icon = isDriver ? Icons.local_taxi_rounded : Icons.person_rounded;

    return Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.15)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(role, style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}