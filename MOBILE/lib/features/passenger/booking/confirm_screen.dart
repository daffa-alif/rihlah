import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/core.dart';
import '../../../core/providers/trip_booking_provider.dart';
import '../../../core/utils/fare_calculator.dart';
import '../../../router.dart';
import 'package:rihlah/l10n/app_localizations.dart';

class _PaymentOption {
  const _PaymentOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    this.connected = true,
  });
  final String    id;
  final String    label;
  final IconData  icon;
  final Color     color;
  final bool      connected;
}

const _paymentOptions = [
  _PaymentOption(id: 'cash', label: 'Tunai', icon: Icons.payments_rounded, color: AppColors.success500),
  _PaymentOption(id: 'qris', label: 'QRIS', icon: Icons.qr_code_scanner_rounded, color: Color(0xFF7B1FA2)),
  _PaymentOption(id: 'gopay', label: 'GoPay', icon: Icons.account_balance_wallet_rounded, color: Color(0xFF00AED6)),
  _PaymentOption(id: 'ovo', label: 'OVO', icon: Icons.account_balance_wallet_rounded, color: Color(0xFF4C3494), connected: false),
  _PaymentOption(id: 'dana', label: 'DANA', icon: Icons.account_balance_wallet_rounded, color: Color(0xFF118EEA), connected: false),
  _PaymentOption(id: 'shopee', label: 'Shopee', icon: Icons.account_balance_wallet_rounded, color: Color(0xFFEE4D2D), connected: false),
];

_PaymentOption _paymentOptionFor(String id) => _paymentOptions.firstWhere((o) => o.id == id, orElse: () => _paymentOptions.first);

class ConfirmScreen extends ConsumerStatefulWidget {
  const ConfirmScreen({super.key});
  @override
  ConsumerState<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends ConsumerState<ConfirmScreen> {
  bool _ordering = false;
  bool _mapCentered = true;
  final _mapCtrl = MapController();

  @override
  void initState() {
    super.initState();
    final defaultPayment = Hive.box('settings').get('default_payment', defaultValue: 'cash') as String;
    Future(() {
      if (!mounted) return;
      ref.read(tripBookingProvider.notifier).setPaymentMethod(defaultPayment);
    });
  }

  FareResult _fareResult(RihlahService service, double km) {
    final devSurge = ref.read(devSettingsProvider).surgePricing;
    final rcEnabled = FirebaseRemoteConfig.instance.getBool('enable_surge');
    return FareCalculator.calculate(
      distanceKm: km,
      service: service,
      surge: FareCalculator.surgeMultiplier(devSurgeEnabled: devSurge, remoteConfigEnabled: rcEnabled),
    );
  }

  String _fmt(int v) => FareCalculator.fmtIdr(v);

  double _fitZoom(double km) {
    if (km < 1)  return 15.5;
    if (km < 3)  return 14.0;
    if (km < 8)  return 13.0;
    if (km < 20) return 12.0;
    return 11.0;
  }

  void _recenter(LatLng mid, double km) {
    _mapCtrl.move(mid, _fitZoom(km));
    setState(() => _mapCentered = true);
  }

  void _showPaymentSheet() {
    final current = ref.read(tripBookingProvider).paymentMethod;
    RihlahSheet.show(
      context,
      title: 'Metode Pembayaran',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _paymentOptions.map((opt) {
          final isSelected = current == opt.id;
          return ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: opt.color.withOpacity(0.12), borderRadius: AppRadius.mdAll),
              child: Icon(opt.icon, color: opt.color, size: 20),
            ),
            title: Text(opt.label, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600)),
            subtitle: !opt.connected ? Text('Belum terhubung', style: AppTypography.bodySm.copyWith(color: AppColors.ink500)) : null,
            trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.primary500) : const Icon(Icons.radio_button_unchecked_rounded, color: AppColors.ink300),
            onTap: () {
              if (!opt.connected) {
                Toast.show(context, message: '${opt.label} akan tersedia segera', type: ToastType.info);
                return;
              }
              ref.read(tripBookingProvider.notifier).setPaymentMethod(opt.id);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  Future<void> _onOrder() async {
    if (_ordering) return;
    setState(() => _ordering = true);

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _ordering = false);
    context.push(Routes.pSearching);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final trip = ref.watch(tripBookingProvider);
    final selectedPayment = _paymentOptionFor(trip.paymentMethod);
    final currentService = trip.service;

    final km = trip.hasRoute ? trip.route.distanceKm : 5.5;

    // Perhitungan Tarif & Durasi untuk ke-3 layanan
    final bikeFare = _fareResult(RihlahService.bike, km);
    final carFare  = _fareResult(RihlahService.car, km);
    final sendFare = _fareResult(RihlahService.send, km);

    final from = trip.pickupLatLng ?? const LatLng(-6.8750, 107.6175);
    final to = trip.dropoffLatLng ?? const LatLng(-6.9200, 107.6070);
    final mid = LatLng((from.latitude + to.latitude) / 2, (from.longitude + to.longitude) / 2);
    final routePoints = trip.route.points.isNotEmpty ? trip.route.points : [from, to];

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: mid,
                initialZoom: _fitZoom(km),
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                onPositionChanged: (_, hasGesture) {
                  if (hasGesture && _mapCentered) setState(() => _mapCentered = false);
                },
              ),
              children: [
                RihlahCachedTileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.rihlah',
                  tileBuilder: _tintTile,
                ),
                if (routePoints.length > 1)
                  PolylineLayer(polylines: [
                    Polyline(points: routePoints, strokeWidth: 4, color: AppColors.primary500),
                  ]),
                MarkerLayer(markers: [
                  Marker(
                    point: from, width: 24, height: 24,
                    child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary500, border: Border.all(color: AppColors.ink0, width: 3), boxShadow: AppElevation.floating)),
                  ),
                  Marker(
                    point: to, width: 36, height: 44,
                    child: Column(children: [
                      Container(
                        width: 28, height: 28,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.danger500),
                        child: const Icon(Icons.location_on_rounded, color: AppColors.ink0, size: 16),
                      ),
                      Container(width: 2, height: 8, color: AppColors.danger500),
                    ]),
                  ),
                ]),
              ],
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppColors.ink0, shape: BoxShape.circle, boxShadow: AppElevation.floating),
                child: const Icon(Icons.arrow_back_rounded, color: AppColors.ink900, size: 24),
              ),
            ),
          ),

          if (!_mapCentered)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: GestureDetector(
                onTap: () => _recenter(mid, km),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: AppColors.ink0, shape: BoxShape.circle, boxShadow: AppElevation.floating),
                  child: const Icon(Icons.my_location_rounded, color: AppColors.primary500, size: 24),
                ),
              ),
            ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.ink300, borderRadius: AppRadius.pillAll)),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: AppRadius.lgAll, border: Border.all(color: AppColors.ink300)),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.my_location_rounded, color: AppColors.primary500, size: 18),
                              const SizedBox(width: 12),
                              Expanded(child: Text(trip.pickupName.isNotEmpty ? trip.pickupName : 'Lokasi Penjemputan', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodyMd)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, color: AppColors.danger500, size: 18),
                              const SizedBox(width: 12),
                              Expanded(child: Text(trip.dropoffName.isNotEmpty ? trip.dropoffName : 'Tujuan', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodyMd)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Karena sekarang ada 3 kartu, kita batasi tingginya agar tidak overflow di layar kecil
                    SizedBox(
                      height: 180, // Tinggi maksimal yang dialokasikan untuk list layanan
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _ServiceSelectionCard(
                              isSelected: currentService == RihlahService.bike,
                              icon: Icons.motorcycle_rounded,
                              title: 'Motor',
                              details: '1 Orang • ${km.toStringAsFixed(1)} km • ${bikeFare.durationMin} mnt',
                              price: _fmt(bikeFare.totalFare),
                              onTap: () => ref.read(tripBookingProvider.notifier).setService(RihlahService.bike),
                            ),
                            const SizedBox(height: 8),
                            _ServiceSelectionCard(
                              isSelected: currentService == RihlahService.car,
                              icon: Icons.directions_car_rounded,
                              title: 'Mobil',
                              details: '4 Orang • ${km.toStringAsFixed(1)} km • ${carFare.durationMin} mnt',
                              price: _fmt(carFare.totalFare),
                              onTap: () => ref.read(tripBookingProvider.notifier).setService(RihlahService.car),
                            ),
                            const SizedBox(height: 8),
                            _ServiceSelectionCard(
                              isSelected: currentService == RihlahService.send,
                              icon: Icons.inventory_2_rounded,
                              title: 'Kirim Barang',
                              details: 'Maks 20kg • ${km.toStringAsFixed(1)} km • ${sendFare.durationMin} mnt',
                              price: _fmt(sendFare.totalFare),
                              onTap: () => ref.read(tripBookingProvider.notifier).setService(RihlahService.send),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: OutlinedButton(
                            onPressed: _showPaymentSheet,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: AppColors.ink300),
                              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(selectedPayment.icon, size: 18, color: selectedPayment.color),
                                const SizedBox(width: 6),
                                Flexible(child: Text(selectedPayment.label, overflow: TextOverflow.ellipsis, style: AppTypography.bodyMd.copyWith(color: AppColors.ink900))),
                                const SizedBox(width: 2),
                                const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.ink500),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 4,
                          child: ElevatedButton(
                            onPressed: _ordering ? null : _onOrder,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: AppColors.primary500,
                              foregroundColor: AppColors.ink0,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                            ),
                            child: _ordering
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.ink0, strokeWidth: 2))
                                : Text(currentService == RihlahService.send ? 'Pesan Kurir' : 'Pesan Ojek', style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink0)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceSelectionCard extends StatelessWidget {
  const _ServiceSelectionCard({
    required this.isSelected,
    required this.icon,
    required this.title,
    required this.details,
    required this.price,
    required this.onTap,
  });

  final bool isSelected;
  final IconData icon;
  final String title;
  final String details;
  final String price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F5E9) : AppColors.ink0,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: isSelected ? AppColors.success500 : AppColors.ink300, width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.ink0,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.ink300),
              ),
              child: Icon(icon, color: AppColors.primary500, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.bodyMd.copyWith(color: AppColors.ink900, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  // Menampilkan detail kombinasi (Orang/Barang, Jarak km, dan Waktu)
                  Text(details, style: AppTypography.bodySm.copyWith(color: AppColors.ink500)),
                ],
              ),
            ),
            Text(price, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600, color: AppColors.ink900)),
          ],
        ),
      ),
    );
  }
}

Widget _tintTile(BuildContext ctx, Widget tile, TileImage ti) => ColorFiltered(
  colorFilter: const ColorFilter.matrix([
    0.85, 0.02, 0.02, 0, 5,
    0.00, 0.90, 0.02, 0, 5,
    0.00, 0.04, 0.78, 0, 8,
    0.00, 0.00, 0.00, 1, 0,
  ]),
  child: tile,
);