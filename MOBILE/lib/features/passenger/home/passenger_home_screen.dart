import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/core.dart';
import '../../../core/providers/saved_address_provider.dart';
import '../../../core/providers/trip_booking_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/services/location_service.dart';
import '../../../data/models/saved_address.dart';
import '../../../router.dart';
import '../booking/map_picker_screen.dart';

class PassengerHomeScreen extends ConsumerStatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  ConsumerState<PassengerHomeScreen> createState() =>
      _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends ConsumerState<PassengerHomeScreen> {
  int _navIndex = 0;

  LatLng _currentLocation = const LatLng(-6.9147, 107.6098); // Default: Bandung
  Map<String, dynamic>? _lastTrip;

  String get _passengerName {
    final profile = ref.watch(userProfileProvider).value;
    if (profile != null && profile.name.isNotEmpty) return profile.name.split(' ').first;
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user.displayName!.split(' ').first;
    }
    return 'Agus';
  }

  @override
  void initState() {
    super.initState();
    _checkActiveTrip();
    _initGpsBackground();
    _loadLastTrip();
  }

  Future<void> _initGpsBackground() async {
    try {
      final pos = await LocationService.instance.getCurrentPosition();
      if (mounted) setState(() => _currentLocation = pos);
    } catch (_) {}
  }

  // 👇 DIPERBARUI: Mencegah error Firebase Index dan memastikan fallback berjalan
  Future<void> _loadLastTrip() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      // Ambil data tanpa orderBy untuk menghindari error index di Firebase
      final snap = await FirebaseFirestore.instance
          .collection('trips')
          .where('passengerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .get();

      if (snap.docs.isNotEmpty && mounted) {
        // Urutkan secara lokal di memori aplikasi
        final docs = snap.docs;
        docs.sort((a, b) {
          final aTime = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bTime = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime); // descending (terbaru di atas)
        });
        setState(() => _lastTrip = docs.first.data());
      } else if (mounted) {
        _setFallbackRecentTrip();
      }
    } catch (e) {
      debugPrint('Error loading last trip: $e');
      // Jika terjadi error (misal index Firebase belum ada), tetap tampilkan dummy
      if (mounted) _setFallbackRecentTrip();
    }
  }

  void _setFallbackRecentTrip() {
    setState(() => _lastTrip = {
      'pickupLat': _currentLocation.latitude,
      'pickupLng': _currentLocation.longitude,
      'pickupAddress': 'Lokasi Anda Saat Ini',
      'dropoffLat': -6.8915,
      'dropoffLng': 107.6107,
      'dropoffAddress': 'Institut Teknologi Bandung',
    });
  }

  Future<void> _checkActiveTrip() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('trips')
          .where('passengerId', isEqualTo: user.uid)
          .where('status', whereIn: ['searching', 'accepted', 'arriving', 'arrived', 'inTrip'])
          .get();

      if (snapshot.docs.isNotEmpty && mounted) {
        final docs = snapshot.docs;
        docs.sort((a, b) {
          final aTime = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bTime = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime);
        });

        final latestTrip = docs.first;
        final createdAt = (latestTrip.data()['createdAt'] as Timestamp?)?.toDate();

        if (createdAt != null && DateTime.now().difference(createdAt).inHours > 12) {
          return;
        }

        final tripId = latestTrip.id;
        context.go('/p/trip/$tripId');
      }
    } catch (e) {
      debugPrint('Gagal memulihkan perjalanan: $e');
    }
  }

  void _onNavTap(int i) {
    if (i == _navIndex) return;
    setState(() => _navIndex = i);
    switch (i) {
      case 1:
        context.push(Routes.pActivity).then((_) {
          if (mounted) setState(() => _navIndex = 0);
        });
      case 2:
        context.push(Routes.pProfile).then((_) {
          if (mounted) setState(() => _navIndex = 0);
        });
    }
  }

  void _onBellTap() => Toast.show(context, message: 'Notifikasi segera hadir', type: ToastType.info);
  void _onWhereTap() => context.push(Routes.pSearch);

  void _onSavedAddressTap(SavedAddress addr) {
    ref.read(tripBookingProvider.notifier).setDropoffRaw(addr.latLng, addr.name);
    context.push(Routes.pConfirm);
  }

  void _onReorderRecentTrip() {
    if (_lastTrip == null) return;
    final notifier = ref.read(tripBookingProvider.notifier);

    final pickupLat = _lastTrip!['pickupLat'] as double? ?? _currentLocation.latitude;
    final pickupLng = _lastTrip!['pickupLng'] as double? ?? _currentLocation.longitude;
    notifier.setPickup(LatLng(pickupLat, pickupLng), _lastTrip!['pickupAddress'] ?? 'Lokasi Penjemputan');

    final dropoffLat = _lastTrip!['dropoffLat'] as double? ?? -6.8915;
    final dropoffLng = _lastTrip!['dropoffLng'] as double? ?? 107.6107;
    notifier.setDropoffRaw(LatLng(dropoffLat, dropoffLng), _lastTrip!['dropoffAddress'] ?? 'Tujuan');

    context.push(Routes.pConfirm);
  }

  Future<void> _onOpenMap() async {
    final result = await context.push<MapPickerResult>('/p/map-picker?title=Pilih+Tujuan');
    if (result != null && mounted) {
      ref.read(tripBookingProvider.notifier).setDropoffRaw(result.latLng, result.name);
      context.push(Routes.pConfirm);
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedAddrs = ref.watch(savedAddressProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.ink0,
        // 👇 DIPERBARUI: Memindahkan Navigasi ke bottomNavigationBar bawaan Scaffold agar scroll lancar
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppColors.ink0,
            border: Border(top: BorderSide(color: const Color(0xFFF1F3F5), width: 1.5)), // Membuang shadow mengganggu, diganti garis bersih
          ),
          child: _BottomNav(currentIndex: _navIndex, onTap: _onNavTap),
        ),
        body: SafeArea(
          // 👇 DIPERBARUI: Langsung membungkus halaman dengan SingleChildScrollView
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24, vertical: AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RIHLAH',
                  style: AppTypography.h3.copyWith(
                    color: AppColors.primary500,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Selamat pagi', style: AppTypography.bodyMd.copyWith(color: AppColors.ink500)),
                        const SizedBox(height: 2),
                        Text(_passengerName, style: AppTypography.h1.copyWith(color: AppColors.ink900, fontSize: 24)),
                      ],
                    ),
                    GestureDetector(
                      onTap: _onBellTap,
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Color(0xFFF8F9FA), shape: BoxShape.circle),
                            child: const Icon(Icons.notifications_none_rounded, color: AppColors.ink900, size: 24),
                          ),
                          Positioned(
                            top: 8, right: 10,
                            child: Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(color: const Color(0xFFF57C00), shape: BoxShape.circle, border: Border.all(color: AppColors.ink0, width: 1.5)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                GestureDetector(
                  onTap: _onWhereTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: AppRadius.mdAll,
                      border: Border.all(color: const Color(0xFFF1F3F5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: AppColors.ink300, size: 22),
                        const SizedBox(width: 12),
                        Text('Mau pergi ke mana?', style: AppTypography.bodyMd.copyWith(color: AppColors.ink300)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ServiceCard(icon: Icons.motorcycle_rounded, label: 'Motor', onTap: _onWhereTap),
                    const SizedBox(width: 16),
                    _ServiceCard(icon: Icons.directions_car_rounded, label: 'Mobil', onTap: _onWhereTap),
                    const SizedBox(width: 16),
                    _ServiceCard(icon: Icons.inventory_2_rounded, label: 'Kirim', onTap: _onWhereTap),
                  ],
                ),
                const SizedBox(height: 24),

                GestureDetector(
                  onTap: () => context.push(Routes.pPromos),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B6B4D),
                      borderRadius: AppRadius.lgAll,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Lihat promo Anda', style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink0)),
                            const SizedBox(height: 4),
                            Text('Temukan penawaran menarik di sini', style: AppTypography.bodySm.copyWith(color: Colors.white70)),
                          ],
                        ),
                        const Icon(Icons.local_activity_outlined, color: AppColors.ink0, size: 28),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                Text('Alamat tersimpan', style: AppTypography.bodyLg.copyWith(color: AppColors.ink900, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _SavedAddressChip(icon: Icons.home_outlined, label: 'Rumah', onTap: () {
                        if(savedAddrs.isNotEmpty) _onSavedAddressTap(savedAddrs.first);
                      }),
                      const SizedBox(width: 12),
                      _SavedAddressChip(icon: Icons.work_outline_rounded, label: 'Kantor', onTap: () {
                        if(savedAddrs.length > 1) _onSavedAddressTap(savedAddrs[1]);
                      }),
                      const SizedBox(width: 12),
                      _SavedAddressChip(icon: Icons.add, label: 'Tambah', isAdd: true, onTap: () {
                        context.push(Routes.pSavedAddresses);
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Pesan Lagi dijamin akan muncul sekarang
                if (_lastTrip != null) ...[
                  Text('Pesan lagi', style: AppTypography.bodyLg.copyWith(color: AppColors.ink900, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _onReorderRecentTrip,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: AppRadius.lgAll,
                        border: Border.all(color: const Color(0xFFF1F3F5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.motorcycle_rounded, color: Color(0xFF1B6B4D), size: 24),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_lastTrip!['dropoffAddress'] ?? 'Tujuan Terakhir', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink900)),
                                const SizedBox(height: 2),
                                Text('Ulangi rute sebelumnya', style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
                              ],
                            ),
                          ),
                          const Icon(Icons.sync_rounded, color: AppColors.ink500, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                GestureDetector(
                  onTap: _onOpenMap,
                  child: Container(
                    width: double.infinity,
                    height: 160,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: AppRadius.xlAll,
                      border: Border.all(color: const Color(0xFFF1F3F5)),
                    ),
                    child: ClipRRect(
                      borderRadius: AppRadius.xlAll,
                      child: Stack(
                        children: [
                          IgnorePointer(
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: _currentLocation,
                                initialZoom: 14.5,
                                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                              ),
                              children: [
                                RihlahCachedTileLayer(
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.example.rihlah',
                                ),
                              ],
                            ),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.white.withOpacity(0.9)],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 16, left: 16, right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(color: AppColors.ink0, borderRadius: AppRadius.pillAll, boxShadow: AppElevation.card),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.map_rounded, color: AppColors.primary500, size: 18),
                                      const SizedBox(width: 8),
                                      Text('Ketuk untuk buka peta', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink900)),
                                    ],
                                  ),
                                  const Icon(Icons.chevron_right_rounded, color: AppColors.ink500, size: 20),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Komponen UI Pendukung ───────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.ink0,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: const Color(0xFFF1F3F5)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF1B6B4D), size: 30),
              const SizedBox(height: 12),
              Text(label, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600, color: AppColors.ink900)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedAddressChip extends StatelessWidget {
  const _SavedAddressChip({required this.icon, required this.label, this.isAdd = false, required this.onTap});
  final IconData icon;
  final String label;
  final bool isAdd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.ink0,
          borderRadius: AppRadius.pillAll,
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.ink700, size: 18),
            const SizedBox(width: 8),
            Text(label, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w500, color: AppColors.ink900)),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;

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
              onTap: () => onTap(i),
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