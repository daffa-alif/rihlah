import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:latlong2/latlong.dart';
import '../../../core/core.dart';
import '../../../core/utils/gps_fix_filter.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/models/trip_model.dart';
import '../../../data/models/user_model.dart';
import '../../../router.dart';
import '../../../core/utils/permission_helper.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  bool   _isOnline      = false;
  int    _onlineSeconds = 0;
  TripModel? _incomingTrip;

  Timer? _onlineTimer;
  StreamSubscription? _pendingTripSub;

  final _mapController    = MapController();
  LatLng _driverPos       = const LatLng(-6.8750, 107.6175);
  bool   _mapCentered     = true;
  StreamSubscription<Position>? _gpsSub;
  final _gpsFilter = GpsFixFilter();
  late final ValueNotifier<LatLng> _driverPosNotifier;

  late AnimationController _smoothCtrl;
  LatLng _smoothFrom = const LatLng(-6.8750, 107.6175);
  LatLng _smoothTo   = const LatLng(-6.8750, 107.6175);

  late AnimationController _radarCtrl;

  int _tripCount     = 0;
  UserModel? _driverProfile;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _driverPosNotifier = ValueNotifier<LatLng>(_driverPos);

    _smoothCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _smoothCtrl.addListener(() {
      if (!mounted) return;
      final t = _smoothCtrl.value;
      _driverPos = LatLng(
        _smoothFrom.latitude  + (_smoothTo.latitude  - _smoothFrom.latitude)  * t,
        _smoothFrom.longitude + (_smoothTo.longitude - _smoothFrom.longitude) * t,
      );
      _driverPosNotifier.value = _driverPos;
      if (_mapCentered) {
        try { _mapController.move(_driverPos, 16); } catch (_) {}
      }
    });

    _radarCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

    _checkActiveTrip();
    _loadStats();
    _loadDriverProfile();
  }

  Future<void> _checkActiveTrip() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('trips')
          .where('driverId', isEqualTo: user.uid)
          .where('status', whereIn: ['accepted', 'arriving', 'arrived', 'inTrip'])
          .get();

      if (snapshot.docs.isNotEmpty && mounted) {
        final latestTrip = snapshot.docs.first;
        context.go('/d/trip/${latestTrip.id}');
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _radarCtrl.dispose();
    _smoothCtrl.dispose();
    _driverPosNotifier.dispose();
    _onlineTimer?.cancel();
    _gpsSub?.cancel();
    _pendingTripSub?.cancel();
    super.dispose();
  }

  void _loadStats() {
    final box     = Hive.box('settings');
    final history = (box.get('driver_history_$_uid') as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final wib = DateTime.now().toUtc().add(const Duration(hours: 7));
    final todayTrips = history.where((m) {
      final date = DateTime.tryParse(m['date']?.toString() ?? '');
      if (date == null) return false;
      final wibDate = date.toUtc().add(const Duration(hours: 7));
      return wibDate.year == wib.year && wibDate.month == wib.month && wibDate.day == wib.day;
    }).toList();

    setState(() {
      _tripCount = todayTrips.length;
    });
  }

  Future<void> _loadDriverProfile() async {
    if (_uid.isEmpty) return;
    final profile = await FirestoreService.instance.getUser(_uid);
    if (mounted && profile != null) setState(() => _driverProfile = profile);
  }

  Future<void> _initGps() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (!mounted) return;
    setState(() => _driverPos = pos);
    _driverPosNotifier.value = pos;
    try { _mapController.move(pos, 16); } catch (_) {}

    _gpsSub = LocationService.instance.rawPositionStream().listen((raw) {
      if (!mounted) return;
      final accepted = _gpsFilter.filter(LatLng(raw.latitude, raw.longitude));
      if (accepted == null) return;
      _smoothMoveTo(accepted.pos);

      if (_isOnline) {
        FirestoreService.instance.updateDriverLocation(
          driverId  : _uid,
          lat       : accepted.pos.latitude,
          lng       : accepted.pos.longitude,
          headingDeg: raw.heading,
        );
      }
    });
  }

  void _smoothMoveTo(LatLng target) {
    _smoothFrom = _driverPosNotifier.value;
    _smoothTo   = target;
    _smoothCtrl..duration = const Duration(milliseconds: 800)..forward(from: 0);
  }

  void _recenter() {
    setState(() => _mapCentered = true);
    try { _mapController.move(_driverPos, 16); } catch (_) {}
  }

  Future<void> _toggleOnline() async {
    if (!_isOnline) {
      final hasPermission = await handleLocationPermission(context);
      if (!hasPermission) return;
      _initGps();
      setState(() => _isOnline = true);
      _radarCtrl.repeat();
      _startOnlineTimer();
      _startPendingTripsListener();
      Toast.show(context, message: 'Kamu sekarang online', type: ToastType.success);
    } else {
      setState(() {
        _isOnline = false;
        _incomingTrip = null;
      });
      _radarCtrl.stop();
      _radarCtrl.reset();
      _onlineTimer?.cancel();
      _pendingTripSub?.cancel();
      _pendingTripSub = null;
      _gpsSub?.cancel();
      Toast.show(context, message: 'Kamu sekarang offline', type: ToastType.info);
    }
  }

  void _startOnlineTimer() {
    _onlineTimer?.cancel();
    _onlineTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _onlineSeconds++);
    });
  }

  Future<void> _startPendingTripsListener() async {
    _pendingTripSub?.cancel();
    final serviceType = Hive.box('settings').get('service_type', defaultValue: 'car') as String;

    _pendingTripSub = FirestoreService.instance
        .pendingTripsStream(serviceType, driverId: _uid)
        .listen((trips) async {
      if (!mounted || !_isOnline) return;

      if (trips.isEmpty) {
        if (_incomingTrip != null) setState(() => _incomingTrip = null);
        return;
      }

      final trip = trips.first;
      if (_incomingTrip?.tripId != trip.tripId) {
        HapticFeedback.heavyImpact();
        setState(() => _incomingTrip = trip);
      }
    });
  }

  Future<void> _acceptOrder() async {
    if (_incomingTrip == null) return;
    final tripId = _incomingTrip!.tripId;

    try {
      await FirebaseFirestore.instance.collection('trips').doc(tripId).update({
        'status': 'accepted',
        'driverId': _uid,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      setState(() => _incomingTrip = null);
      if (mounted) context.go('/d/trip/$tripId');
    } catch (e) {
      Toast.show(context, message: 'Gagal menerima pesanan', type: ToastType.danger);
    }
  }

  void _declineOrder() {
    setState(() => _incomingTrip = null);
  }

  String get _formattedOnlineTime {
    final h = _onlineSeconds ~/ 3600;
    final m = (_onlineSeconds % 3600) ~/ 60;
    final s = _onlineSeconds % 60;

    if (h > 0) return '${h}h ${m}m';
    return '${m}m ${s}s';
  }

  String _formatIdr(int v) {
    if (v == 0) return 'Rp 0';
    final s = v.toString();
    final buf = StringBuffer('Rp ');
    final offset = s.length % 3;
    for (int i = 0; i < s.length; i++) {
      if (i != 0 && (i - offset) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final hasIncomingOrder = _incomingTrip != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.ink0,
        body: Column(
          children: [
            // 1. HEADER
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                  color: AppColors.ink0,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))
                  ]
              ),
              child: Center(
                child: Text(
                  'RIHLAH Driver Console',
                  style: AppTypography.h3.copyWith(
                    color: const Color(0xFF1B6B4D),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            // 2. AREA PETA & KARTU OVERLAY
            Expanded(
              child: Stack(
                children: [
                  // Lapis Peta
                  Positioned.fill(child: _buildMap()),

                  // Toggle & Performance Card
                  Positioned(
                    top: 16, left: 16, right: 16,
                    child: _buildMergedPerformanceCard(),
                  ),

                  // 👇 PERBAIKAN: Tombol Re-center dinaikkan ke 180 agar tidak tertimpa
                  if (!_mapCentered && !hasIncomingOrder)
                    Positioned(
                      bottom: 180, right: 16,
                      child: GestureDetector(
                        onTap: _recenter,
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(color: AppColors.ink0, shape: BoxShape.circle, boxShadow: AppElevation.card),
                          child: const Icon(Icons.my_location_rounded, color: AppColors.primary500),
                        ),
                      ),
                    ),

                  // Area Indikator Status & Order (Bawah)
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasIncomingOrder)
                          _buildIncomingOrderCard()
                        else if (_isOnline)
                          _buildWaitingPill()
                        else
                          _buildOfflinePill(),

                        // Bottom Navigation
                        if (!hasIncomingOrder)
                          Container(
                            decoration: const BoxDecoration(
                              color: AppColors.ink0,
                              border: Border(top: BorderSide(color: Color(0xFFF1F3F5))),
                            ),
                            child: _DriverBottomNav(
                                currentIndex: 0,
                                onTap: (i) {
                                  if (i == 1) context.push(Routes.dEarnings);
                                  if (i == 2) context.push(Routes.dHistory);
                                  if (i == 3) context.push(Routes.dProfile);
                                }
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── WIDGETS BUILDERS ────────────────────────────────────────────────────────

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _driverPos,
        initialZoom: 16,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
        onPositionChanged: (_, hasGesture) {
          if (hasGesture && _mapCentered) setState(() => _mapCentered = false);
        },
      ),
      children: [
        RihlahCachedTileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.rihlah',
        ),
        ValueListenableBuilder<LatLng>(
          valueListenable: _driverPosNotifier,
          builder: (_, pos, __) => MarkerLayer(markers: [
            Marker(
              point: pos,
              width: 150, height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isOnline)
                    AnimatedBuilder(
                      animation: _radarCtrl,
                      builder: (context, child) {
                        return Container(
                          width: 150 * _radarCtrl.value,
                          height: 150 * _radarCtrl.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1B6B4D).withOpacity((1.0 - _radarCtrl.value) * 0.4),
                          ),
                        );
                      },
                    ),

                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.ink0,
                      border: Border.all(color: const Color(0xFF1B6B4D), width: 5),
                      boxShadow: AppElevation.floating,
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildMergedPerformanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.ink0,
          borderRadius: AppRadius.xlAll,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))
          ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("TODAY'S PERFORMANCE", style: AppTypography.label.copyWith(color: AppColors.ink500, letterSpacing: 1.2)),
              _buildTogglePill(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text('$_tripCount', style: AppTypography.h1.copyWith(fontSize: 24, color: AppColors.ink900)),
                    Text('Trips', style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: AppColors.ink300),
              Expanded(
                child: Column(
                  children: [
                    Text(_formattedOnlineTime, style: AppTypography.h1.copyWith(fontSize: 24, color: AppColors.ink900)),
                    Text('Online', style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTogglePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.ink0,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _toggleOnline,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42, height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _isOnline ? const Color(0xFF22C55E) : Colors.grey.shade300,
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: _isOnline ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(2),
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isOnline ? const Color(0xFF2563EB) : Colors.white,
                  ),
                  child: _isOnline ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: AppTypography.bodyMd.copyWith(
              fontWeight: FontWeight.w700,
              color: _isOnline ? const Color(0xFF1B6B4D) : AppColors.ink500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflinePill() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      child: ElevatedButton.icon(
        onPressed: _toggleOnline,
        icon: const Icon(Icons.power_settings_new_rounded),
        label: Text('Mulai Terima Pesanan', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B6B4D),
          foregroundColor: AppColors.ink0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
          elevation: 4,
          minimumSize: const Size.fromHeight(50),
        ),
      ),
    );
  }

  Widget _buildWaitingPill() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.ink0,
        borderRadius: AppRadius.pillAll,
        boxShadow: AppElevation.floating,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(color: const Color(0xFF1B6B4D).withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.radar_rounded, size: 14, color: Color(0xFF1B6B4D)),
          ),
          const SizedBox(width: 12),
          Text('Menunggu pesanan', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600, color: AppColors.ink900)),
          const SizedBox(width: 12),
          AnimatedBuilder(
            animation: _radarCtrl,
            builder: (context, child) {
              int dots = ((_radarCtrl.value % 1.0) * 4).floor();
              String dotStr = List.generate(dots, (_) => '.').join();
              return SizedBox(width: 20, child: Text(dotStr, style: AppTypography.bodyLg.copyWith(color: const Color(0xFF1B6B4D), fontWeight: FontWeight.w900)));
            },
          )
        ],
      ),
    );
  }

  Widget _buildIncomingOrderCard() {
    final trip = _incomingTrip!;
    final isBike = trip.serviceType == 'bike';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink0,
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: const Color(0xFF1B6B4D), width: 2),
        boxShadow: AppElevation.floating,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: AppRadius.pillAll),
                child: Row(
                  children: [
                    Icon(isBike ? Icons.motorcycle_rounded : Icons.directions_car_rounded, size: 16, color: AppColors.primary600),
                    const SizedBox(width: 6),
                    Text(isBike ? 'Ojek Ride' : 'Mobil Ride', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary600)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${trip.durationMin} min', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF1B6B4D))),
                  Text('${trip.distanceKm.toStringAsFixed(1)} km away', style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),

          Text(_formatIdr(trip.driverEarns), style: AppTypography.h1.copyWith(fontSize: 28, color: AppColors.ink900)),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const SizedBox(height: 4),
                  Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF1B6B4D), width: 3))),
                  Container(width: 1.5, height: 24, color: AppColors.ink300),
                  Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.danger500, width: 3))),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.pickupAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink900)),
                    const SizedBox(height: 14),
                    Text(trip.dropoffAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink900)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: _declineOrder,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger500),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                  ),
                  child: Text('Decline', style: AppTypography.bodyMd.copyWith(color: AppColors.danger500, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _acceptOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B6B4D),
                    foregroundColor: AppColors.ink0,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Accept Request', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.ink0.withOpacity(0.5), width: 2)),
                      )
                    ],
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

// ── BOTTOM NAV COMPONENT ───────────────────────────────────────────────────

class _DriverBottomNav extends StatelessWidget {
  const _DriverBottomNav({required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, 'Earnings'),
    (Icons.history_rounded, Icons.history_outlined, 'History'),
    (Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 64,
        child: Row(
          children: List.generate(_items.length, (i) {
            final (activeIcon, inactiveIcon, label) = _items[i];
            final isActive = i == currentIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: isActive ? BoxDecoration(color: const Color(0xFF22C55E), borderRadius: AppRadius.pillAll) : null,
                      child: Icon(isActive ? activeIcon : inactiveIcon, size: 24, color: isActive ? AppColors.ink0 : AppColors.ink500),
                    ),
                    const SizedBox(height: 4),
                    Text(label, style: AppTypography.bodySm.copyWith(fontSize: 10, color: isActive ? const Color(0xFF22C55E) : AppColors.ink500, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500)),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}