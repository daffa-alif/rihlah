// lib/core/utils/driver_receipt_share.dart
//
// Generate PNG receipt untuk driver dan share via WhatsApp.
// Template dioptimasi untuk WhatsApp: 1080×1080px, teks besar, kontras tinggi.

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'fare_calculator.dart';

class DriverReceiptShare {
  DriverReceiptShare._();

  /// Render receipt ke PNG lalu share via WhatsApp.
  /// Jika WhatsApp tidak tersedia, fallback ke share sheet biasa.
  static Future<void> share({
    required BuildContext context,
    required String       tripId,
    required String       pickup,
    required String       dropoff,
    required String       passengerName,
    required double       distanceKm,
    required int          durationMin,
    required int          fareAfterDiscount,
    required int          driverEarns,
    required int          platformCut,
    required String       service,
    required DateTime     date,
    int?                  discount,
  }) async {
    // Render widget off-screen
    final boundary = GlobalKey();
    final widget   = _buildReceiptWidget(
      boundary         : boundary,
      tripId           : tripId,
      pickup           : pickup,
      dropoff          : dropoff,
      passengerName    : passengerName,
      distanceKm       : distanceKm,
      durationMin      : durationMin,
      fareAfterDiscount: fareAfterDiscount,
      driverEarns      : driverEarns,
      platformCut      : platformCut,
      service          : service,
      date             : date,
      discount         : discount,
    );

    // Mount widget ke overlay
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -9999, top: -9999,
        child: widget,
      ),
    );
    overlay.insert(entry);

    // Tunggu frame render
    await Future.delayed(const Duration(milliseconds: 300));

    Uint8List? bytes;
    try {
      final renderBox = boundary.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (renderBox != null) {
        final image = await renderBox.toImage(pixelRatio: 3.0);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        bytes = byteData?.buffer.asUint8List();
      }
    } finally {
      entry.remove();
    }

    if (bytes == null) return;

    // Simpan ke temp file
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/rihlah_receipt_$tripId.png');
    await file.writeAsBytes(bytes);

    // Share — caption WhatsApp
    final caption = _buildCaption(
      driverEarns: driverEarns,
      pickup     : pickup,
      dropoff    : dropoff,
    );

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: caption,
    );
  }

  // ── Caption ───────────────────────────────────────────────────────────────

  static String _buildCaption({
    required int    driverEarns,
    required String pickup,
    required String dropoff,
  }) {
    final earn = FareCalculator.fmtIdr(driverEarns);
    return '🚗 Pendapatan trip RIHLAH: $earn\n'
        '📍 $pickup → $dropoff\n'
        '#RIHLAH #Driver #Bandung';
  }

  // ── Receipt widget ────────────────────────────────────────────────────────

  static Widget _buildReceiptWidget({
    required GlobalKey boundary,
    required String    tripId,
    required String    pickup,
    required String    dropoff,
    required String    passengerName,
    required double    distanceKm,
    required int       durationMin,
    required int       fareAfterDiscount,
    required int       driverEarns,
    required int       platformCut,
    required String    service,
    required DateTime  date,
    int?               discount,
  }) {
    final fmt = FareCalculator.fmtIdr;
    final serviceLabel = switch (service) {
      'bike' => '🏍️ RIHLAH Motor',
      'send' => '📦 RIHLAH Kurir',
      _      => '🚗 RIHLAH Mobil',
    };
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}  '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';

    return RepaintBoundary(
      key: boundary,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 360,
          color: const Color(0xFF0F172A), // dark navy
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ─────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: 24, horizontal: 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white24,
                          ),
                          child: const Center(
                            child: Text('R',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('RIHLAH',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2)),
                        const Spacer(),
                        Text(serviceLabel,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Pendapatan Trip',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 13)),
                    Text(fmt(driverEarns),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1)),
                    const SizedBox(height: 4),
                    Text(dateStr,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),

              // ── Route ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                    color: Color(0xFF1E293B)),
                child: Column(
                  children: [
                    _ReceiptRow(
                      icon : '🟢',
                      label: 'Jemput',
                      value: pickup,
                      light: true,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      margin: const EdgeInsets.only(left: 9),
                      width: 2, height: 16,
                      color: Colors.white24,
                    ),
                    const SizedBox(height: 4),
                    _ReceiptRow(
                      icon : '🔴',
                      label: 'Tujuan',
                      value: dropoff,
                      light: true,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _ReceiptChip(
                            '👤 $passengerName'),
                        const SizedBox(width: 8),
                        _ReceiptChip(
                            '${distanceKm.toStringAsFixed(1)} km'),
                        const SizedBox(width: 8),
                        _ReceiptChip('$durationMin min'),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Breakdown ───────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _ReceiptLine('Tarif penumpang',
                        fmt(fareAfterDiscount)),
                    if (discount != null && discount > 0) ...[
                      const SizedBox(height: 8),
                      _ReceiptLine('Diskon voucher',
                          '-${fmt(discount)}',
                          valueColor: const Color(0xFF4ADE80)),
                    ],
                    const SizedBox(height: 8),
                    _ReceiptLine('Potongan platform (20%)',
                        '-${fmt(platformCut)}',
                        valueColor: const Color(0xFFF87171)),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(
                          color: Colors.white24, height: 1),
                    ),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Kamu terima',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        Text(fmt(driverEarns),
                            style: const TextStyle(
                                color: Color(0xFF4ADE80),
                                fontSize: 18,
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Footer ──────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 20),
                decoration: const BoxDecoration(
                    color: Color(0xFF0F172A)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Trip ID: ',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 10)),
                    Text(tripId,
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            fontFamily: 'monospace')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Receipt sub-widgets ───────────────────────────────────────────────────────

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.icon,
    required this.label,
    required this.value,
    this.light = false,
  });
  final String icon, label, value;
  final bool   light;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(icon, style: const TextStyle(fontSize: 12)),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white38, fontSize: 10)),
            Text(value,
                style: TextStyle(
                    color: light ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ],
  );
}

class _ReceiptChip extends StatelessWidget {
  const _ReceiptChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
        horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white12,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label,
        style: const TextStyle(
            color: Colors.white70, fontSize: 11)),
  );
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine(this.label, this.value,
      {this.valueColor});
  final String label, value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
          style: const TextStyle(
              color: Colors.white54, fontSize: 12)),
      Text(value,
          style: TextStyle(
              color: valueColor ?? Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace')),
    ],
  );
}

class _CompRow extends StatelessWidget {
  const _CompRow(this.name, this.estimate, this.rihlahEarn);
  final String name, estimate;
  final int    rihlahEarn;

  @override
  Widget build(BuildContext context) {
    final estVal = int.tryParse(
        estimate.replaceAll('Rp ', '').replaceAll('.', '')) ?? 0;
    final diff   = rihlahEarn - estVal;
    final better = diff > 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(name,
            style: const TextStyle(
                color: Colors.white70, fontSize: 12)),
        Row(
          children: [
            Text(estimate,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'monospace')),
            if (diff != 0) ...[
              const SizedBox(width: 6),
              Text(
                better
                    ? '+${FareCalculator.fmtIdr(diff)}'
                    : FareCalculator.fmtIdr(diff),
                style: TextStyle(
                    color: better
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFFF87171),
                    fontSize: 10,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ],
    );
  }
}