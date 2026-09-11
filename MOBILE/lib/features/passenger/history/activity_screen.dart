import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/core.dart';
import '../../../core/services/firestore_service.dart';
import '../../../data/models/trip_model.dart' hide TripStatus;
import '../../../router.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/receipt_image.dart';
import '../../../core/widgets/custom_avatar.dart';


// ── Model ─────────────────────────────────────────────────────────────────────

class _Trip {
  const _Trip({
    required this.id,
    required this.destination,
    required this.pickup,
    required this.time,
    required this.payment,
    required this.fare,
    required this.status,
    required this.serviceIcon,
    required this.serviceBg,
    required this.serviceColor,
    required this.rating,
    required this.date,
    required this.tip,
    required this.discount,
    required this.km,
    required this.durationMin,
    required this.service,
    required this.driver,
  });
  final String   id;
  final String   destination;
  final String   pickup;
  final String   time;
  final String   payment;
  final int      fare;
  final String   status;
  final IconData serviceIcon;
  final Color    serviceBg;
  final Color    serviceColor;
  final int      rating;
  final DateTime date;
  final int      tip;
  final int      discount;
  final double   km;
  final int      durationMin;
  final String   service;
  final String   driver;

  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
}

// ── Formatters & Grouping ─────────────────────────────────────────────────────

String _formatDateTime(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];
  final day = d.day.toString().padLeft(2, '0');
  final month = months[d.month - 1];
  final year = d.year;
  final hr = d.hour.toString().padLeft(2, '0');
  final min = d.minute.toString().padLeft(2, '0');
  return '$day $month $year, $hr:$min WIB';
}

String _formatShortDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];
  final day = d.day.toString().padLeft(2, '0');
  final month = months[d.month - 1];
  return '$day $month';
}

String _groupMonthLabel(DateTime d) {
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month) return 'Bulan Ini';

  const fullMonths = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
  return '${fullMonths[d.month - 1]} ${d.year}';
}

Map<String, List<_Trip>> _groupTripsByMonth(List<_Trip> trips) {
  final map = <String, List<_Trip>>{};
  for (final t in trips) {
    final label = _groupMonthLabel(t.date);
    map.putIfAbsent(label, () => []).add(t);
  }
  return map;
}

String _formatIdr(int v) {
  final s = v.toString();
  final buf = StringBuffer('Rp ');
  final offset = s.length % 3;
  for (int i = 0; i < s.length; i++) {
    if (i != 0 && (i - offset) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<_Trip> _trips = [];
  List<TripModel> _completedTrips = [];
  final Map<String, String> _driverNameCache = {};
  StreamSubscription<List<TripModel>>? _tripsSub;

  String get _passengerId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _startTripsListener();
  }

  @override
  void dispose() {
    _tripsSub?.cancel();
    super.dispose();
  }

  void _startTripsListener() {
    if (_passengerId.isEmpty) return;
    _tripsSub = FirestoreService.instance.passengerTripsStream(_passengerId).listen((trips) {
      if (!mounted) return;
      _completedTrips = trips
          .where((t) => t.status.name == 'completed' || t.status.name == 'cancelled')
          .toList();

      _completedTrips.sort((a, b) {
        final aDate = (a.completedAt ?? a.cancelledAt ?? a.createdAt)?.toDate() ?? DateTime.now();
        final bDate = (b.completedAt ?? b.cancelledAt ?? b.createdAt)?.toDate() ?? DateTime.now();
        return bDate.compareTo(aDate);
      });

      setState(() => _trips = _completedTrips.map(_toTrip).toList());
      _resolveDriverNames();
    }, onError: (e) => debugPrint('passengerTripsStream error: $e'));
  }

  void _resolveDriverNames() {
    final missing = _completedTrips
        .where((t) => t.driverId != null && !_driverNameCache.containsKey(t.driverId))
        .map((t) => t.driverId!)
        .toSet();
    for (final id in missing) {
      FirestoreService.instance.getUser(id).then((profile) {
        if (!mounted) return;
        _driverNameCache[id] = profile?.name ?? 'Budi Santoso';
        setState(() => _trips = _completedTrips.map(_toTrip).toList());
      });
    }
  }

  _Trip _toTrip(TripModel t) {
    final date = (t.completedAt ?? t.cancelledAt ?? t.createdAt)?.toDate() ?? DateTime.now();
    return _Trip(
      id: t.tripId.isNotEmpty ? t.tripId.substring(0, t.tripId.length >= 8 ? 8 : t.tripId.length).toUpperCase() : '89472A',
      destination: t.dropoffAddress,
      pickup: t.pickupAddress,
      time: '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} WIB',
      payment: 'Cash',
      fare: t.totalFare,
      status: t.status.name,
      serviceIcon: _serviceIcon(t.serviceType),
      serviceBg: _serviceBg(t.serviceType),
      serviceColor: _serviceColor(t.serviceType),
      rating: t.passengerRating ?? 5,
      date: date,
      tip: t.passengerTip ?? 0,
      discount: t.appliedDiscount ?? 0,
      km: t.distanceKm,
      durationMin: t.durationMin,
      service: t.serviceType ?? 'car',
      driver: t.driverId != null ? (_driverNameCache[t.driverId] ?? 'Budi Santoso') : 'Budi Santoso',
    );
  }

  IconData _serviceIcon(String? service) => switch (service) {
    'bike' => Icons.motorcycle_rounded,
    'send' => Icons.inventory_2_rounded,
    _      => Icons.directions_car_rounded,
  };

  Color _serviceBg(String? service) => const Color(0xFFE3F2FD);

  Color _serviceColor(String? service) => switch (service) {
    'bike' => AppColors.success500,
    _      => AppColors.info500,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary500),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(Routes.pHome);
            }
          },
        ),
        title: Text(
          'Riwayat Perjalanan',
          style: AppTypography.h3.copyWith(color: AppColors.ink900, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _trips.isEmpty
                  ? _EmptyTrips(onOrder: () => context.push(Routes.pHome))
                  : _ActivityContent(trips: _trips),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.ink0,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))
                ],
              ),
              child: const _BottomNav(currentIndex: 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityContent extends StatelessWidget {
  const _ActivityContent({required this.trips});
  final List<_Trip> trips;

  @override
  Widget build(BuildContext context) {
    final latestTrip = trips.first;
    final groupedHistory = _groupTripsByMonth(trips.skip(1).toList());

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20, vertical: AppSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroTripCard(trip: latestTrip),
          const SizedBox(height: AppSpacing.s32),

          if (groupedHistory.isNotEmpty)
            for (final entry in groupedHistory.entries) ...[
              Text(entry.key, style: AppTypography.h3.copyWith(color: AppColors.ink900)),
              const SizedBox(height: AppSpacing.s16),
              ...entry.value.map((trip) => _HistoryListCard(trip: trip)),
              const SizedBox(height: AppSpacing.s24),
            ],
        ],
      ),
    );
  }
}

class _HeroTripCard extends StatelessWidget {
  const _HeroTripCard({required this.trip});
  final _Trip trip;

  void _shareReceipt(BuildContext context) async {
    await ReceiptImage.shareReceipt(
      context: context,
      tripId: trip.id,
      pickup: trip.pickup,
      dropoff: trip.destination,
      fare: trip.fare,
      discount: trip.discount,
      tip: trip.tip,
      service: trip.service,
      driver: trip.driver,
      km: trip.km,
      durationMin: trip.durationMin,
      date: trip.date,
    );
  }

  @override
  Widget build(BuildContext context) {
    int serviceFee = 2000;
    int baseFare = 12000;
    int distanceFare = trip.fare - baseFare - serviceFee;
    if (distanceFare < 0) {
      baseFare = trip.fare;
      distanceFare = 0;
      serviceFee = 0;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.ink0,
        borderRadius: AppRadius.xlAll,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_formatDateTime(trip.date), style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink900)),
                    const SizedBox(height: 2),
                    Text('ID: T-${trip.id}', style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.success500.withOpacity(0.15), borderRadius: AppRadius.pillAll),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(trip.isCompleted ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                          size: 14, color: trip.isCompleted ? AppColors.success500 : AppColors.danger500),
                      const SizedBox(width: 4),
                      Text(trip.isCompleted ? 'Selesai' : 'Batal',
                          style: AppTypography.label.copyWith(color: trip.isCompleted ? AppColors.success500 : AppColors.danger500, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s20),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.success500, width: 3))),
                    Container(width: 2, height: 28, color: AppColors.ink300),
                    const Icon(Icons.location_on_rounded, color: AppColors.danger500, size: 18),
                  ],
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trip.pickup, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodyMd.copyWith(color: AppColors.ink900)),
                      const SizedBox(height: 18),
                      Text(trip.destination, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodyMd.copyWith(color: AppColors.ink900)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s20),

            Container(
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(color: const Color(0xFFF4F7FC), borderRadius: AppRadius.lgAll),
              child: Column(
                children: [
                  _FareRow(label: 'Tarif Dasar', value: _formatIdr(baseFare)),
                  const SizedBox(height: 8),
                  _FareRow(label: 'Jarak (${trip.km.toStringAsFixed(1)} km)', value: _formatIdr(distanceFare)),
                  const SizedBox(height: 8),
                  _FareRow(label: 'Biaya Layanan', value: _formatIdr(serviceFee)),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: AppColors.ink300)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Biaya', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink900)),
                      Text(_formatIdr(trip.fare), style: AppTypography.h3.copyWith(color: AppColors.ink900)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s20),

            Row(
              children: [
                CustomAvatar(
                  name: trip.driver, // Ini variabel nama driver yang ada di bawahnya
                  imageUrl: null,    // Ubah jadi null dulu agar langsung tampil inisial nama
                  size: 40.0,
                  fontSize: 16.0,
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trip.driver, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink900)),
                      Text('Toyota Avanza • B 1234 XYZ', style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFF5A623), size: 18),
                    const SizedBox(width: 4),
                    Text(trip.rating > 0 ? trip.rating.toStringAsFixed(1) : '4.8', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s24),

            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE3F2FD),
                      foregroundColor: AppColors.info500,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.help_outline_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text('Bantuan', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: ElevatedButton(
                    onPressed: () => _shareReceipt(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      foregroundColor: AppColors.ink0,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.share_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text('Bagikan Resi', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FareRow extends StatelessWidget {
  const _FareRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    // Diubah dari ink600 ke ink500 agar valid
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
        Text(value, style: AppTypography.bodySm.copyWith(color: AppColors.ink900, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _HistoryListCard extends StatelessWidget {
  const _HistoryListCard({required this.trip});
  final _Trip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.ink0,
        borderRadius: AppRadius.lgAll,
        // Diubah dari ink200 ke ink300 agar valid
        border: Border.all(color: AppColors.ink300),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: trip.serviceBg, borderRadius: AppRadius.mdAll),
            child: Icon(trip.serviceIcon, size: 24, color: trip.serviceColor),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trip.destination, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink900), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${_formatShortDate(trip.date)} • ${trip.time}', style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_formatIdr(trip.fare), style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink900)),
              const SizedBox(height: 2),
              Text(
                trip.isCompleted ? 'Selesai' : 'Batal',
                style: AppTypography.bodySm.copyWith(
                  color: trip.isCompleted ? AppColors.success500 : AppColors.danger500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyTrips extends StatelessWidget {
  const _EmptyTrips({required this.onOrder});
  final VoidCallback onOrder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: AppColors.ink100, borderRadius: AppRadius.lgAll),
            child: const Icon(Icons.directions_car_rounded, size: 40, color: AppColors.ink500),
          ),
          const SizedBox(height: AppSpacing.s24),
          Text('Belum ada perjalanan', style: AppTypography.h2, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.s8),
          Text('Perjalananmu akan muncul di sini', style: AppTypography.bodyMd.copyWith(color: AppColors.ink500), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.s24),
          SizedBox(width: 200, child: RihlahButton(label: 'Order a ride', onPressed: onOrder)),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex});
  final int currentIndex;

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Activity'),
    (Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 70,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (i) {
            final (activeIcon, inactiveIcon, label) = _items[i];
            final isActive = i == currentIndex;

            return GestureDetector(
              onTap: () {
                if (i == currentIndex) return;
                switch (i) {
                  case 0:
                    while (context.canPop()) { context.pop(); }
                    context.go(Routes.pHome);
                  case 2:
                    context.pushReplacement(Routes.pProfile);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: isActive ? BoxDecoration(
                  color: AppColors.success500,
                  borderRadius: AppRadius.pillAll,
                ) : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive ? activeIcon : inactiveIcon,
                      size: 24,
                      color: isActive ? AppColors.ink0 : AppColors.ink500,
                    ),
                    const SizedBox(height: 4),
                    Text(label,
                        style: AppTypography.bodySm.copyWith(
                          fontSize: 11,
                          color: isActive ? AppColors.ink0 : AppColors.ink500,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        )),
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