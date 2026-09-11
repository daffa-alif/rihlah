import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/core.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/history_export_service.dart';
import '../../../data/models/trip_model.dart' hide TripStatus;
import '../../../router.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class _DriverTrip {
  const _DriverTrip({
    required this.id,
    required this.passenger,
    required this.pickup,
    required this.dropoff,
    required this.time,
    required this.date,
    required this.earn,
    required this.status,
    required this.service,
  });

  final String   id;
  final String   passenger;
  final String   pickup;
  final String   dropoff;
  final String   time;
  final DateTime date;
  final int      earn;
  final String   status;
  final String   service;

  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  IconData get serviceIcon => service == 'bike'
      ? Icons.motorcycle_rounded : (service == 'send' ? Icons.inventory_2_rounded : Icons.directions_car_rounded);

  String get serviceName => service == 'bike' ? 'Ojek Ride' : (service == 'send' ? 'Package Delivery' : 'Mobil Ride');
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtIdr(int v) {
  if (v == 0) return 'Rp 0';
  final s      = v.toString();
  final buf    = StringBuffer('Rp ');
  final offset = s.length % 3;
  for (int i = 0; i < s.length; i++) {
    if (i != 0 && (i - offset) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

// ── Screen ────────────────────────────────────────────────────────────────────

class DriverHistoryScreen extends StatefulWidget {
  const DriverHistoryScreen({super.key});

  @override
  State<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends State<DriverHistoryScreen> {
  List<_DriverTrip>  _all = [];
  List<TripModel>    _allTrips = [];

  StreamSubscription<List<TripModel>>? _tripsSub;

  DateTime? _selectedDate;
  String _selectedService = 'All';

  String get _driverId => FirebaseAuth.instance.currentUser?.uid ?? '';

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
    if (_driverId.isEmpty) return;
    _tripsSub = FirestoreService.instance
        .driverTripsStream(_driverId)
        .listen((trips) {
      if (!mounted) return;
      final completedOrCancelled = trips
          .where((t) => t.status.name == 'completed' || t.status.name == 'cancelled')
          .toList();

      final mapped = completedOrCancelled.map((t) {
        final date = (t.completedAt ?? t.cancelledAt ?? t.createdAt)?.toDate() ?? DateTime.now();
        return _DriverTrip(
          id       : t.tripId,
          // 👇 Menambahkan fallback khusus untuk passengerName agar tidak error
          passenger: t.passengerName ?? 'Penumpang',
          pickup   : t.pickupAddress,
          dropoff  : t.dropoffAddress,
          time     : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
          date     : date,
          earn     : t.driverEarns,
          status   : t.status.name,
          service  : t.serviceType,
        );
      }).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _allTrips = completedOrCancelled;
        _all      = mapped;
      });
    }, onError: (e) => debugPrint('driverTripsStream error: $e'));
  }

  int get _monthTrips {
    final now = DateTime.now();
    return _all.where((t) => t.date.month == now.month && t.date.year == now.year && t.isCompleted).length;
  }

  int get _monthEarns {
    final now = DateTime.now();
    return _all.where((t) => t.date.month == now.month && t.date.year == now.year && t.isCompleted).fold(0, (s, t) => s + t.earn);
  }

  List<_DriverTrip> get _filteredTrips {
    return _all.where((t) {
      bool matchDate = true;
      if (_selectedDate != null) {
        matchDate = t.date.year == _selectedDate!.year &&
            t.date.month == _selectedDate!.month &&
            t.date.day == _selectedDate!.day;
      }
      bool matchService = _selectedService == 'All' || t.service == _selectedService;
      return matchDate && matchService;
    }).toList();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: const Color(0xFF1B6B4D)),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _onExport() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.ink0,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (_) => _ExportSheet(
        onExport: (from, to, pdf) {
          Navigator.pop(context);
          _doExport(pdf: pdf, from: from, to: to);
        },
      ),
    );
  }

  Future<void> _doExport({required bool pdf, required DateTime? from, required DateTime? to}) async {
    final items = _allTrips.where((t) {
      if (t.status.name != 'completed') return false;
      if (from == null || to == null) return true;
      final date = (t.completedAt ?? t.createdAt)?.toDate() ?? DateTime.now();
      return !date.isBefore(from) && !date.isAfter(to);
    }).map((t) {
      final date = (t.completedAt ?? t.createdAt)?.toDate() ?? DateTime.now();
      return TripExportItem(
        date       : date,
        pickup     : t.pickupAddress,
        dropoff    : t.dropoffAddress,
        distanceKm : t.distanceKm,
        durationMin: t.durationMin,
        fare       : t.totalFare,
        platformFee: t.platformFee,
        earn       : t.driverEarns,
        service    : t.serviceType,
        status     : t.status.name,
      );
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final profile = await FirestoreService.instance.getUser(_driverId);
    final driverName = profile?.name ?? 'Driver';
    if (!mounted) return;

    if (pdf) {
      await HistoryExportService.instance.exportPdf(context: context, trips: items, driverName: driverName, from: from, to: to);
    } else {
      await HistoryExportService.instance.exportCsv(context: context, trips: items, driverName: driverName, from: from, to: to);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trips = _filteredTrips;
    final currentMonthStr = _months[DateTime.now().month - 1];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
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

              // Content Area
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // 1. Monthly Summary Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                          color: AppColors.ink0,
                          borderRadius: AppRadius.xlAll,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
                          ]
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$currentMonthStr Summary', style: AppTypography.h3.copyWith(color: const Color(0xFF0F172A))),
                          const SizedBox(height: 4),
                          Text('Your performance this month', style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('TOTAL TRIPS', style: AppTypography.label.copyWith(color: AppColors.ink500, letterSpacing: 1.2)),
                                    const SizedBox(height: 4),
                                    Text('$_monthTrips', style: AppTypography.h1.copyWith(color: const Color(0xFF1B6B4D), fontSize: 28)),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('TOTAL EARNINGS', style: AppTypography.label.copyWith(color: AppColors.ink500, letterSpacing: 1.2)),
                                    const SizedBox(height: 4),
                                    Text(_fmtIdr(_monthEarns).replaceAll('Rp ', 'Rp'), style: AppTypography.h1.copyWith(color: const Color(0xFF1B6B4D), fontSize: 28)),
                                  ],
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 2. Trip History Header & Export Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Trip History', style: AppTypography.h2.copyWith(color: const Color(0xFF0F172A))),
                        ElevatedButton.icon(
                          onPressed: _onExport,
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: Text('Export Report', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size.zero, // 👈 FIX Mencegah error RenderFlex
                            backgroundColor: const Color(0xFF475569),
                            foregroundColor: AppColors.ink0,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 3. Date Picker Field
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.ink0,
                          borderRadius: AppRadius.mdAll,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: 20, color: AppColors.ink500),
                                const SizedBox(width: 12),
                                Text(
                                  _selectedDate != null
                                      ? '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}'
                                      : 'All time',
                                  style: AppTypography.bodyMd.copyWith(color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            if (_selectedDate != null)
                              GestureDetector(
                                onTap: () => setState(() => _selectedDate = null),
                                child: const Icon(Icons.close_rounded, size: 20, color: AppColors.ink500),
                              )
                            else
                              const Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.ink900),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. Service Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(label: 'All', isSelected: _selectedService == 'All', onTap: () => setState(() => _selectedService = 'All')),
                          const SizedBox(width: 8),
                          _FilterChip(label: 'Motor', isSelected: _selectedService == 'bike', onTap: () => setState(() => _selectedService = 'bike')),
                          const SizedBox(width: 8),
                          _FilterChip(label: 'Mobil', isSelected: _selectedService == 'car', onTap: () => setState(() => _selectedService = 'car')),
                          const SizedBox(width: 8),
                          _FilterChip(label: 'Kirim', isSelected: _selectedService == 'send', onTap: () => setState(() => _selectedService = 'send')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 5. Trip Cards List
                    if (trips.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text('Belum ada riwayat perjalanan.', style: AppTypography.bodyMd.copyWith(color: AppColors.ink500)),
                        ),
                      )
                    else
                      ...trips.map((t) => _TripCard(trip: t)),

                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // Bottom nav
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.ink0,
                  border: Border(top: BorderSide(color: Color(0xFFF1F3F5))),
                ),
                child: _DriverBottomNav(
                    currentIndex: 2,
                    onTap: (i) {
                      if (i == 0) context.go(Routes.dHome);
                      if (i == 1) context.push(Routes.dEarnings);
                      if (i == 3) context.push(Routes.dProfile);
                    }
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Components ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.isSelected, required this.onTap});
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B6B4D) : AppColors.ink0,
          borderRadius: AppRadius.pillAll,
          border: Border.all(color: isSelected ? const Color(0xFF1B6B4D) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: AppTypography.bodyMd.copyWith(
            color: isSelected ? AppColors.ink0 : const Color(0xFF64748B),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});
  final _DriverTrip trip;

  String _formatMonthDay(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = trip.isCompleted;

    // 👇 LOGIKA BARU: Format Uang, Warna, dan Coretan
    final String earnText = isCompleted
        ? '+ ${_fmtIdr(trip.earn).replaceAll('Rp ', 'Rp')}'
        : _fmtIdr(trip.earn).replaceAll('Rp ', 'Rp');

    final Color earnColor = isCompleted
        ? const Color(0xFF2563EB) // Biru jika selesai
        : const Color(0xFF94A3B8); // Abu-abu jika batal

    final TextDecoration earnDecoration = isCompleted
        ? TextDecoration.none
        : TextDecoration.lineThrough; // Coret jika batal

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink0,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(trip.serviceIcon, size: 20, color: const Color(0xFF1B6B4D)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(trip.serviceName, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCompleted ? const Color(0xFF22C55E).withOpacity(0.15) : const Color(0xFFE2E8F0),
                        borderRadius: AppRadius.pillAll,
                      ),
                      child: Text(
                        isCompleted ? 'Completed' : 'Cancelled',
                        style: AppTypography.label.copyWith(
                            color: isCompleted ? const Color(0xFF166534) : const Color(0xFF475569),
                            fontWeight: FontWeight.w700
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 👇 LOGIKA BARU: Diterapkan pada teks nominal uang
                  Text(
                    earnText,
                    style: AppTypography.h3.copyWith(
                      color: earnColor,
                      decoration: earnDecoration,
                    ),
                  ),
                  Text('${_formatMonthDay(trip.date)}, ${trip.time}', style: AppTypography.bodySm.copyWith(color: const Color(0xFF64748B))),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const SizedBox(height: 4),
                  Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: isCompleted ? const Color(0xFF1B6B4D) : const Color(0xFF94A3B8))),
                  Container(width: 2, height: 24, color: const Color(0xFFE2E8F0)),
                  Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: isCompleted ? AppColors.danger500 : const Color(0xFF94A3B8))),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.pickup, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodyMd.copyWith(color: const Color(0xFF334155))),
                    const SizedBox(height: 14),
                    Text(trip.dropoff, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodyMd.copyWith(color: const Color(0xFF334155))),
                  ],
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}
// ── Export sheet ──────────────────────────────────────────────────────────────

class _ExportSheet extends StatelessWidget {
  const _ExportSheet({required this.onExport});
  final void Function(DateTime? from, DateTime? to, bool pdf) onExport;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSpacing.s24, right: AppSpacing.s24,
        top: AppSpacing.s24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outline, borderRadius: AppRadius.pillAll)),
          ),
          const SizedBox(height: AppSpacing.s16),
          Text('Export Riwayat', style: AppTypography.h2),
          const SizedBox(height: AppSpacing.s4),
          Text('Pilih format laporan riwayat perjalananmu.', style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: _ExportOption(
                icon     : Icons.picture_as_pdf_rounded,
                iconBg   : AppColors.danger500.withOpacity(0.1),
                iconColor: AppColors.danger500,
                title    : 'PDF',
                subtitle : 'Siap cetak',
                onTap    : () => onExport(null, null, true),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: _ExportOption(
                icon     : Icons.table_chart_rounded,
                iconBg   : AppColors.success500.withOpacity(0.1),
                iconColor: AppColors.success500,
                title    : 'CSV',
                subtitle : 'Excel / Sheets',
                onTap    : () => onExport(null, null, false),
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.s32),
        ],
      ),
    );
  }
}

class _ExportOption extends StatelessWidget {
  const _ExportOption({required this.icon, required this.iconBg, required this.iconColor, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final Color iconBg, iconColor;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.lgAll,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(color: AppColors.ink0, borderRadius: AppRadius.lgAll, border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: iconBg, borderRadius: AppRadius.mdAll), child: Icon(icon, size: 24, color: iconColor)),
            const SizedBox(height: AppSpacing.s8),
            Text(title, style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w700)),
            Text(subtitle, style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
          ],
        ),
      ),
    );
  }
}

// ── Bottom nav ────────────────────────────────────────────────────────────────

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