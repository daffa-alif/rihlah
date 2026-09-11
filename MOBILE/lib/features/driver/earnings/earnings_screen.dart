import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/core.dart';
import '../../../router.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../data/models/payout_model.dart';
import '../../../data/models/trip_model.dart' hide TripStatus;

// ── Model ─────────────────────────────────────────────────────────────────────

class _EarningEntry {
  const _EarningEntry({
    required this.id,
    required this.destination,
    required this.time,
    required this.duration,
    required this.earn,
    required this.service,
    required this.date,
    required this.km,
  });
  final String   id;
  final String   destination;
  final String   time;
  final int      duration;
  final int      earn;
  final String   service;
  final DateTime date;
  final double   km;

  IconData get icon => service == 'bike' ? Icons.motorcycle_rounded : (service == 'send' ? Icons.inventory_2_rounded : Icons.directions_car_rounded);
  String get serviceName => service == 'bike' ? 'Ojek Ride' : (service == 'send' ? 'Kurir Send' : 'Mobil Ride');
}

// ── Screen ────────────────────────────────────────────────────────────────────

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<_EarningEntry> _all = [];
  List<PayoutModel> _payouts = [];

  StreamSubscription<List<TripModel>>? _tripsSub;
  StreamSubscription<List<PayoutModel>>? _payoutsSub;

  String get _driverId => FirebaseAuth.instance.currentUser?.uid ?? '';
  String _driverName = 'Driver';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _loadDriverName();
    _startTripsListener();
    _startPayoutsListener();
  }

  Future<void> _loadDriverName() async {
    final uid = _driverId;
    if (uid.isEmpty) return;
    final profile = await FirestoreService.instance.getUser(uid);
    if (mounted && profile != null && profile.name.isNotEmpty) {
      setState(() => _driverName = profile.name);
    }
  }

  @override
  void dispose() {
    _tripsSub?.cancel();
    _payoutsSub?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _startTripsListener() {
    if (_driverId.isEmpty) return;
    _tripsSub = FirestoreService.instance.driverTripsStream(_driverId).listen((trips) {
      if (!mounted) return;
      final entries = trips
          .where((t) => t.status.name == 'completed')
          .map((t) {
        final date = (t.completedAt ?? t.createdAt)?.toDate() ?? DateTime.now();
        return _EarningEntry(
          id         : t.tripId,
          destination: t.dropoffAddress,
          time       : _formatTime(date),
          duration   : t.durationMin,
          earn       : t.driverEarns,
          service    : t.serviceType, // 👈 Diperbarui: Menghapus "?? 'bike'" yang menyebabkan dead code
          date       : date,
          km         : t.distanceKm,
        );
      }).toList();

      // Urutkan dari yang terbaru
      entries.sort((a, b) => b.date.compareTo(a.date));
      setState(() => _all = entries);
    }, onError: (e) => debugPrint('driverTripsStream error: $e'));
  }

  void _startPayoutsListener() {
    if (_driverId.isEmpty) return;
    _payoutsSub = FirestoreService.instance.payoutsStream(driverId: _driverId).listen((payouts) {
      if (!mounted) return;
      setState(() => _payouts = payouts);
    }, onError: (e) => debugPrint('payoutsStream error: $e'));
  }

  int get _walletBalance {
    final lifetimeEarn = _all.fold(0, (s, e) => s + e.earn);
    final withdrawn = _payouts
        .where((p) => p.status != PayoutStatus.failed)
        .fold(0, (s, p) => s + p.amountIdr + p.feeIdr);
    return (lifetimeEarn - withdrawn).clamp(0, 999999999);
  }

  String _formatTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _formatFullDate(DateTime d) {
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  DateTime get _wibNow => DateTime.now().toUtc().add(const Duration(hours: 7));

  List<_EarningEntry> get _todayEntries {
    final wib = _wibNow;
    return _all.where((e) {
      final d = e.date.toUtc().add(const Duration(hours: 7));
      return d.year == wib.year && d.month == wib.month && d.day == wib.day;
    }).toList();
  }

  List<_EarningEntry> get _weekEntries {
    final wib = _wibNow;
    final weekStart = wib.subtract(Duration(days: wib.weekday - 1));
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return _all.where((e) {
      final d = e.date.toUtc().add(const Duration(hours: 7));
      final dDay = DateTime(d.year, d.month, d.day);
      return !dDay.isBefore(start);
    }).toList();
  }

  List<_EarningEntry> get _currentEntries => switch (_tabCtrl.index) {
    1 => _weekEntries,
    2 => _all,
    _ => _todayEntries,
  };

  String _fmtFull(int v) {
    if (v == 0) return '0';
    final s = v.toString();
    final buf = StringBuffer('');
    final offset = s.length % 3;
    for (int i = 0; i < s.length; i++) {
      if (i != 0 && (i - offset) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  void _onWithdraw() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.ink0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (_) => _WithdrawSheet(
        available: _walletBalance,
        driverId: _driverId,
        driverName: _driverName,
        onSuccess: () {
          if (!mounted) return;
          Toast.show(context, message: 'Penarikan berhasil diproses!', type: ToastType.success);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.ink0,
        body: Column(
          children: [
            // 1. Header Putih
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

            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 2. Kartu Saldo Biru
                        Container(
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3EFFF),
                            borderRadius: AppRadius.xlAll,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 👈 Diperbarui: Menggunakan AppColors.ink500 karena ink600 tidak tersedia
                              Text('SALDO DOMPET', style: AppTypography.label.copyWith(color: AppColors.ink500, letterSpacing: 1.2)),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Rp ', style: AppTypography.h2.copyWith(color: AppColors.ink900)),
                                  Text(_fmtFull(_walletBalance), style: AppTypography.mono.copyWith(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.ink900, height: 1.1)),
                                ],
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _walletBalance > 0 ? _onWithdraw : null,
                                  icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
                                  label: Text('Tarik Tunai', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1B6B4D), // Hijau Tua
                                    foregroundColor: AppColors.ink0,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 3. TabBar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Color(0xFFF1F3F5), width: 1.5)),
                            ),
                            child: TabBar(
                              controller: _tabCtrl,
                              indicatorColor: const Color(0xFF1B6B4D),
                              indicatorWeight: 3,
                              labelColor: const Color(0xFF1B6B4D),
                              unselectedLabelColor: AppColors.ink500,
                              labelStyle: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700),
                              unselectedLabelStyle: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w500),
                              tabs: const [
                                Tab(text: 'Hari Ini'),
                                Tab(text: 'Minggu Ini'),
                                Tab(text: 'Semua'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 4. Daftar Riwayat
                  if (_currentEntries.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Text('Belum ada transaksi', style: AppTypography.bodyMd.copyWith(color: AppColors.ink500)),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            final entry = _currentEntries[index];
                            bool showHeader = false;
                            if (index == 0) {
                              showHeader = true;
                            } else {
                              final prevEntry = _currentEntries[index - 1];
                              final d1 = entry.date.toUtc().add(const Duration(hours: 7));
                              final d2 = prevEntry.date.toUtc().add(const Duration(hours: 7));
                              if (d1.day != d2.day || d1.month != d2.month || d1.year != d2.year) {
                                showHeader = true;
                              }
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showHeader) ...[
                                  // 👈 Diperbarui: Menghapus keyword 'const' karena index adalah dinamis
                                  Padding(
                                    padding: EdgeInsets.only(bottom: 12, top: index == 0 ? 0.0 : 16.0),
                                    child: Text(_formatFullDate(entry.date.toUtc().add(const Duration(hours: 7))),
                                        style: AppTypography.bodySm.copyWith(color: AppColors.ink500, fontWeight: FontWeight.w600)), // 👈 Mengubah ink600 ke ink500
                                  ),
                                ],
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.ink0,
                                    borderRadius: AppRadius.lgAll,
                                    border: Border.all(color: const Color(0xFFE5E7EB)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44, height: 44,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF0F5FF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(entry.icon, color: const Color(0xFF1B6B4D), size: 22),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(entry.serviceName, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                            const SizedBox(height: 4),
                                            Text('${entry.time} • ${entry.km.toStringAsFixed(1)} km', style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
                                          ],
                                        ),
                                      ),
                                      Text('+ Rp ${_fmtFull(entry.earn)}', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF1B6B4D))),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                          childCount: _currentEntries.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Navigation
            Container(
              decoration: const BoxDecoration(
                color: AppColors.ink0,
                border: Border(top: BorderSide(color: Color(0xFFF1F3F5))),
              ),
              child: _DriverBottomNav(
                  currentIndex: 1,
                  onTap: (i) {
                    if (i == 0) context.go(Routes.dHome);
                    if (i == 2) context.push(Routes.dHistory);
                    if (i == 3) context.push(Routes.dProfile);
                  }
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom nav ────────────────────────────────────────────────────────────

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
                      decoration: isActive ? BoxDecoration(color: AppColors.success500, borderRadius: AppRadius.pillAll) : null,
                      child: Icon(isActive ? activeIcon : inactiveIcon, size: 24, color: isActive ? AppColors.ink0 : AppColors.ink500),
                    ),
                    const SizedBox(height: 4),
                    Text(label, style: AppTypography.bodySm.copyWith(fontSize: 10, color: isActive ? AppColors.success500 : AppColors.ink500, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500)),
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

// ── Withdraw sheet ────────────────────────────────────────────────────────────

class _WithdrawSheet extends StatefulWidget {
  const _WithdrawSheet({
    required this.available,
    required this.driverId,
    required this.onSuccess,
    this.driverName = 'Driver',
  });
  final int          available;
  final String       driverId;
  final VoidCallback onSuccess;
  final String       driverName;

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  late final TextEditingController _amountCtrl;
  bool   _processing = false;
  String _statusMsg  = '';

  static const _minWithdraw = 20000;
  static const _withdrawFee = 1000;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: widget.available.toString());
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  bool get _isFreeWithdrawal {
    final box  = Hive.box('settings');
    final wib  = DateTime.now().toUtc().add(const Duration(hours: 7));
    final date = '${wib.year}-${wib.month.toString().padLeft(2, '0')}-${wib.day.toString().padLeft(2, '0')}';
    final key  = 'withdrawal_count_${widget.driverId}_$date';
    final count = (box.get(key) as num?)?.toInt() ?? 0;
    return count == 0;
  }

  int get _fee => _isFreeWithdrawal ? 0 : _withdrawFee;

  String _fmtFull(int v) {
    if (v == 0) return '0';
    final s = v.toString();
    final buf = StringBuffer('');
    final offset = s.length % 3;
    for (int i = 0; i < s.length; i++) {
      if (i != 0 && (i - offset) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Future<void> _onWithdraw() async {
    final raw    = _amountCtrl.text.replaceAll('.', '').trim();
    final amount = int.tryParse(raw) ?? 0;

    if (amount < _minWithdraw) {
      setState(() => _statusMsg = 'Minimum penarikan Rp ${_fmtFull(_minWithdraw)}');
      return;
    }
    if (amount > widget.available) {
      setState(() => _statusMsg = 'Jumlah melebihi saldo tersedia');
      return;
    }

    setState(() {
      _processing = true;
      _statusMsg  = 'Memproses penarikan…';
    });

    String? payoutId;
    try {
      payoutId = await FirestoreService.instance.createPayout(PayoutModel(
        payoutId: '',
        driverId: widget.driverId,
        amountIdr: amount - _fee,
        feeIdr: _fee,
        destination: 'BCA •••• 1234',
        status: PayoutStatus.processing,
      ));
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final success = DateTime.now().millisecond % 10 != 0;

    if (payoutId != null) {
      try {
        await FirestoreService.instance.updatePayoutStatus(
          payoutId,
          success ? PayoutStatus.success : PayoutStatus.failed,
          setPaidAt: success,
        );
      } catch (_) {}
    }

    if (success) {
      final box  = Hive.box('settings');
      final wib  = DateTime.now().toUtc().add(const Duration(hours: 7));
      final date = '${wib.year}-${wib.month.toString().padLeft(2, '0')}-${wib.day.toString().padLeft(2, '0')}';
      final key   = 'withdrawal_count_${widget.driverId}_$date';
      final count = (box.get(key) as num?)?.toInt() ?? 0;
      await box.put(key, count + 1);

      setState(() {
        _processing = false;
        _statusMsg  = '';
      });

      Navigator.pop(context);
      await NotificationService.instance.showPayoutStatus(driverId: widget.driverId, amount: amount - _fee, success: true);
      widget.onSuccess();
    } else {
      setState(() {
        _processing = false;
        _statusMsg  = 'Penarikan gagal. Dana akan dikembalikan dalam 1 hari kerja.';
      });
      await NotificationService.instance.showPayoutStatus(driverId: widget.driverId, amount: amount, success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final free = _isFreeWithdrawal;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left  : AppSpacing.s24,
        right : AppSpacing.s24,
        top   : AppSpacing.s24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: cs.outline, borderRadius: AppRadius.pillAll),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Text('Tarik ke rekening', style: AppTypography.h2),
          const SizedBox(height: AppSpacing.s24),

          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: cs.outline),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: AppColors.primary100, borderRadius: AppRadius.smAll),
                  child: const Icon(Icons.account_balance_rounded, size: 18, color: AppColors.primary500),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BCA', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700)),
                      Text('•••• •••• •••• 1234', style: AppTypography.mono.copyWith(fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Text('a.n ${widget.driverName}', style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
            decoration: BoxDecoration(
              color: free ? AppColors.primary500.withOpacity(0.08) : cs.surfaceContainerHighest,
              borderRadius: AppRadius.mdAll,
            ),
            child: Row(
              children: [
                Icon(
                  free ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  size: 16,
                  color: free ? AppColors.primary500 : cs.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    free ? 'Penarikan pertama hari ini — GRATIS' : 'Penarikan berikutnya dikenakan biaya Rp ${_fmtFull(_withdrawFee)}',
                    style: AppTypography.bodySm.copyWith(color: free ? AppColors.primary500 : cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          Text('Jumlah tarik', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: AppSpacing.s8),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            style: AppTypography.mono.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(prefixText: 'Rp '),
            onChanged: (_) => setState(() => _statusMsg = ''),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tersedia: Rp ${_fmtFull(widget.available)}', style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant)),
              Text('Min. Rp ${_fmtFull(_minWithdraw)}', style: AppTypography.bodySm.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),

          if (_statusMsg.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s8),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: _statusMsg.contains('gagal') ? AppColors.danger500.withOpacity(0.1) : const Color(0xFFF59E0B).withOpacity(0.1),
                borderRadius: AppRadius.mdAll,
              ),
              child: Row(
                children: [
                  Icon(
                    _statusMsg.contains('gagal') ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
                    size: 16,
                    color: _statusMsg.contains('gagal') ? AppColors.danger500 : const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(_statusMsg, style: AppTypography.bodySm.copyWith(color: _statusMsg.contains('gagal') ? AppColors.danger500 : const Color(0xFFF59E0B))),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s24),

          RihlahButton(
            label: _processing ? 'Memproses…' : 'Withdraw',
            isLoading: _processing,
            onPressed: _processing ? () {} : _onWithdraw,
          ),
          const SizedBox(height: AppSpacing.s24),
        ],
      ),
    );
  }
}