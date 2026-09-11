// lib/core/utils/receipt_image.dart
//
// Render receipt widget ke PNG lalu share via share_plus.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core.dart';

// ── Public API ────────────────────────────────────────────────────────────────

class ReceiptImage {
  ReceiptImage._();

  static Future<void> shareReceipt({
    required BuildContext context,
    required String       tripId,
    required String       pickup,
    required String       dropoff,
    required int          fare,
    required int          discount,
    required int          tip,
    required String       service,
    required String       driver,
    required double       km,
    required int          durationMin,
    required DateTime     date,
  }) async {
    final driverShare  = (fare * 0.95).round();
    final platformFee  = fare - driverShare;
    final totalPayable = (fare - discount + tip).clamp(0, 999999);

    final bytes = await _captureWidget(
      context: context,
      widget: _ReceiptCard(
        tripId      : tripId,
        pickup      : pickup,
        dropoff     : dropoff,
        fare        : fare,
        discount    : discount,
        tip         : tip,
        totalPayable: totalPayable,
        driverShare : driverShare,
        platformFee : platformFee,
        service     : service,
        driver      : driver,
        km          : km,
        durationMin : durationMin,
        date        : date,
      ),
    );

    if (bytes == null) return;

    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/rihlah-receipt-$tripId.png');
    await file.writeAsBytes(bytes);

    final xFile = XFile(file.path, mimeType: 'image/png');
    await Share.shareXFiles(
      [xFile],
      text:
          '🚗 Struk Perjalanan RIHLAH\n'
          '📍 $pickup → $dropoff\n'
          '💰 Total: ${_fmtIdr(totalPayable)}\n\n'
          '#RIHLAH #Bandung',
    );
  }

  static Future<Uint8List?> _captureWidget({
    required BuildContext context,
    required Widget       widget,
  }) async {
    final key = GlobalKey();

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -4000, top: -4000,
        child: RepaintBoundary(
          key: key,
          child: SizedBox(width: 360, child: widget),
        ),
      ),
    );
    overlay.insert(entry);

    await Future.delayed(const Duration(milliseconds: 400));

    Uint8List? bytes;
    try {
      final boundary = key.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      final image    = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = byteData?.buffer.asUint8List();
    } catch (_) {}

    entry.remove();
    return bytes;
  }
}

// ── Receipt card ──────────────────────────────────────────────────────────────

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({
    required this.tripId,
    required this.pickup,
    required this.dropoff,
    required this.fare,
    required this.discount,
    required this.tip,
    required this.totalPayable,
    required this.driverShare,
    required this.platformFee,
    required this.service,
    required this.driver,
    required this.km,
    required this.durationMin,
    required this.date,
  });

  final String   tripId;
  final String   pickup;
  final String   dropoff;
  final int      fare;
  final int      discount;
  final int      tip;
  final int      totalPayable;
  final int      driverShare;
  final int      platformFee;
  final String   service;
  final String   driver;
  final double   km;
  final int      durationMin;
  final DateTime date;

  // Colour palette
  static const _bg      = Color(0xFF0F1923);
  static const _card    = Color(0xFF1A2535);
  static const _primary = Color(0xFF4CA66E);
  static const _white   = Color(0xFFFFFFFF);
  static const _muted   = Color(0xFF8A9BB0);
  static const _danger  = Color(0xFFEF4444);

  String get _serviceLabel => switch (service) {
    'bike' => 'Motor',
    'send' => 'Kurir',
    _      => 'Mobil',
  };

  @override
  Widget build(BuildContext context) {
    const months = [
      'Jan','Feb','Mar','Apr','Mei','Jun',
      'Jul','Agu','Sep','Okt','Nov','Des',
    ];
    final dateStr =
        '${date.day} ${months[date.month - 1]} ${date.year}  '
        '${date.hour.toString().padLeft(2,'0')}:'
        '${date.minute.toString().padLeft(2,'0')}';

    return Material(
      color: _bg,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Header ────────────────────────────────
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text('R',
                        style: TextStyle(
                            color: _white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('RIHLAH',
                    style: TextStyle(
                        color: _white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2)),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(dateStr,
                        style: const TextStyle(
                            color: _muted, fontSize: 10)),
                    Text(_serviceLabel,
                        style: const TextStyle(
                            color: _primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Total ─────────────────────────────────
            _Card(
              child: Column(
                children: [
                  const Text('TOTAL DIBAYAR',
                      style: TextStyle(
                          color: _muted,
                          fontSize: 10,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 6),
                  Text(_fmtIdr(totalPayable),
                      style: const TextStyle(
                          color: _white,
                          fontSize: 36,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Tunai kepada $driver',
                      style: const TextStyle(
                          color: _muted, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Rute ──────────────────────────────────
            _Card(
              child: Column(
                children: [
                  _RouteRow(
                      dot: _primary,
                      label: 'JEMPUT',
                      value: pickup),
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 6, top: 4, bottom: 4),
                    child: Container(
                        width: 1, height: 14,
                        color: _muted.withOpacity(0.3)),
                  ),
                  _RouteRow(
                      dot: _danger,
                      label: 'TUJUAN',
                      value: dropoff),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceAround,
                    children: [
                      _StatChip(label: 'Jarak',
                          value: '${km.toStringAsFixed(1)} km'),
                      _StatChip(label: 'Waktu',
                          value: '$durationMin min'),
                      _StatChip(label: 'Driver',
                          value: driver.split(' ')
                              .take(2).join(' ')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Detail tarif ───────────────────────────
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Trip ID
                  _DetailRow(
                    label: 'ID Perjalanan',
                    value: tripId,
                    valueSize: 9,
                  ),
                  const SizedBox(height: 8),
                  _DetailRow(
                    label: 'Layanan',
                    value: _serviceLabel,
                  ),
                  const SizedBox(height: 8),

                  // Tarif breakdown
                  if (discount > 0) ...[
                    _DetailRow(
                      label: 'Tarif',
                      value: _fmtIdr(fare + discount),
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      label: 'Diskon voucher',
                      value: '-${_fmtIdr(discount)}',
                      valueColor: _primary,
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      label: 'Tarif bersih',
                      value: _fmtIdr(fare),
                      bold: true,
                    ),
                  ] else
                    _DetailRow(
                      label: 'Tarif perjalanan',
                      value: _fmtIdr(fare),
                      bold: true,
                    ),

                  if (tip > 0) ...[
                    const SizedBox(height: 8),
                    _DetailRow(
                      label: 'Tip driver',
                      value: _fmtIdr(tip),
                    ),
                  ],

                  // Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12),
                    child: Divider(
                        height: 1,
                        color: _white.withOpacity(0.08)),
                  ),

                  // Transparansi
                  const Text('TRANSPARANSI PEMBAYARAN',
                      style: TextStyle(
                          color: _muted,
                          fontSize: 9,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text('Driver (95%)',
                                style: TextStyle(
                                    color: _muted,
                                    fontSize: 10)),
                            Text(_fmtIdr(driverShare),
                                style: const TextStyle(
                                    color: _white,
                                    fontSize: 14,
                                    fontWeight:
                                        FontWeight.w700)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.end,
                        children: [
                          const Text('Platform (5%)',
                              style: TextStyle(
                                  color: _muted,
                                  fontSize: 10)),
                          Text(_fmtIdr(platformFee),
                              style: const TextStyle(
                                  color: _muted,
                                  fontSize: 14,
                                  fontWeight:
                                      FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0.95,
                      minHeight: 6,
                      backgroundColor: _white.withOpacity(0.15),
                      valueColor: const AlwaysStoppedAnimation(
                          _primary),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Footer ────────────────────────────────
            const Center(
              child: Text(
                'rihlah.id  •  Terima kasih telah berkendara '
                'bersama kami',
                style: TextStyle(
                    color: Color(0xFF4A5568), fontSize: 9),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Card container ────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2535),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

// ── Route row ─────────────────────────────────────────────────────────────────

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.dot,
    required this.label,
    required this.value,
  });
  final Color  dot;
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12, height: 12,
          margin: const EdgeInsets.only(top: 2),
          decoration:
              BoxDecoration(shape: BoxShape.circle, color: dot),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF8A9BB0),
                      fontSize: 8,
                      letterSpacing: 1)),
              Text(value,
                  style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Stat chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF8A9BB0), fontSize: 9)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Detail row ────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold      = false,
    this.valueSize = 12.0,
  });
  final String label, value;
  final Color? valueColor;
  final bool   bold;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF8A9BB0), fontSize: 11)),
        Flexible(
          child: Text(value,
              style: TextStyle(
                  color: valueColor ?? const Color(0xFFFFFFFF),
                  fontSize: valueSize,
                  fontWeight: bold
                      ? FontWeight.w700
                      : FontWeight.w500),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────

String _fmtIdr(int v) {
  if (v == 0) return 'Rp 0';
  final s   = v.toString();
  final buf = StringBuffer('Rp ');
  final off = s.length % 3;
  for (int i = 0; i < s.length; i++) {
    if (i != 0 && (i - off) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}