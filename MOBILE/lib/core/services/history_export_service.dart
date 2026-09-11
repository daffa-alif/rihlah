// lib/core/services/history_export_service.dart
//
// Export riwayat trip driver ke PDF dan CSV.
// Business rule: nama passenger dianonimkan → "Penumpang Anonim"

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

class TripExportItem {
  const TripExportItem({
    required this.date,
    required this.pickup,
    required this.dropoff,
    required this.distanceKm,
    required this.durationMin,
    required this.fare,
    required this.platformFee,
    required this.earn,
    required this.service,
    required this.status,
  });
  final DateTime date;
  final String   pickup, dropoff;
  final double   distanceKm;
  final int      durationMin;
  final int      fare, platformFee, earn;
  final String   service, status;

  // Nama passenger sengaja tidak ada — dianonimkan per business rule
  static const anonName = 'Penumpang Anonim';
}

class HistoryExportService {
  HistoryExportService._();
  static final instance = HistoryExportService._();

  static final _idr = NumberFormat.currency(
      locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  static final _dtFmt = DateFormat('dd/MM/yyyy HH:mm', 'id_ID');
  static final _dateFmt = DateFormat('dd MMM yyyy', 'id_ID');

  String _fmtIdr(int v) => _idr.format(v);

  // ── CSV ──────────────────────────────────────────────────────────────────

  Future<void> exportCsv({
    required BuildContext context,
    required List<TripExportItem> trips,
    required String       driverName,
    required DateTime?    from,
    required DateTime?    to,
  }) async {
    if (trips.isEmpty) {
      _showEmpty(context);
      return;
    }

    final buf = StringBuffer();

    // Header baris info
    buf.writeln('RIHLAH - Riwayat Pendapatan Driver');
    buf.writeln('Driver,${_sanitize(driverName)}');
    buf.writeln('Periode,${_periodLabel(from, to)}');
    buf.writeln('Total Trip,${trips.length}');
    buf.writeln('Total Pendapatan,${_fmtIdr(trips.fold(0, (s, t) => s + t.earn))}');
    buf.writeln('');

    // Header kolom
    buf.writeln([
      'Tanggal', 'Waktu', 'Pickup', 'Tujuan',
      'Jarak (km)', 'Durasi (min)', 'Layanan',
      'Tarif', 'Potongan Platform', 'Pendapatan',
    ].join(','));

    // Baris data
    for (final t in trips) {
      buf.writeln([
        DateFormat('dd/MM/yyyy').format(t.date),
        DateFormat('HH:mm').format(t.date),
        _sanitize(t.pickup),
        _sanitize(t.dropoff),
        t.distanceKm.toStringAsFixed(1),
        t.durationMin.toString(),
        _serviceLabel(t.service),
        t.fare.toString(),
        t.platformFee.toString(),
        t.earn.toString(),
      ].join(','));
    }

    // Simpan ke file
    final dir  = await getTemporaryDirectory();
    final ts   = DateFormat('yyyyMMdd').format(DateTime.now());
    final file = File('${dir.path}/rihlah_history_$ts.csv');
    await file.writeAsString(buf.toString(), encoding: utf8);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      text: 'Riwayat perjalanan RIHLAH — ${_periodLabel(from, to)}',
    );
  }

  // ── PDF ──────────────────────────────────────────────────────────────────

  Future<void> exportPdf({
    required BuildContext context,
    required List<TripExportItem> trips,
    required String       driverName,
    required DateTime?    from,
    required DateTime?    to,
  }) async {
    if (trips.isEmpty) {
      _showEmpty(context);
      return;
    }

    final totalEarn   = trips.fold(0, (s, t) => s + t.earn);
    final totalFare   = trips.fold(0, (s, t) => s + t.fare);
    final totalFee    = trips.fold(0, (s, t) => s + t.platformFee);

    // Load font (fallback ke Helvetica jika gagal)
    pw.Font? fontRegular;
    pw.Font? fontBold;
    try {
      final regData  = await rootBundle.load(
          'assets/fonts/Inter-Regular.ttf');
      final boldData = await rootBundle.load(
          'assets/fonts/Inter-Bold.ttf');
      fontRegular = pw.Font.ttf(regData);
      fontBold    = pw.Font.ttf(boldData);
    } catch (_) {
      // Gunakan font bawaan pdf package
    }

    final pdf  = pw.Document();
    final green = PdfColor.fromHex('#16A34A');
    final gray  = PdfColor.fromHex('#6B7280');
    final light = PdfColor.fromHex('#F9FAFB');
    final dark  = PdfColor.fromHex('#111827');

    pw.TextStyle style(
            {double size = 10,
            pw.Font? font,
            PdfColor? color}) =>
        pw.TextStyle(
          fontSize: size,
          font    : font ?? fontRegular,
          color   : color ?? dark,
        );

    pw.TextStyle bold({double size = 10, PdfColor? color}) =>
        style(
            size: size,
            font: fontBold ?? fontRegular,
            color: color);

    // Split ke halaman (max 25 baris/halaman)
    const rowsPerPage = 25;
    final pages       = <List<TripExportItem>>[];
    for (int i = 0; i < trips.length; i += rowsPerPage) {
      pages.add(trips.sublist(
          i, (i + rowsPerPage).clamp(0, trips.length)));
    }

    for (int pi = 0; pi < pages.length; pi++) {
      final pagTrips = pages[pi];
      final isFirst  = pi == 0;

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin    : const pw.EdgeInsets.all(32),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────
            if (isFirst) ...[
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment:
                        pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('RIHLAH',
                          style: bold(size: 24, color: green)),
                      pw.Text('Laporan Riwayat Pendapatan Driver',
                          style: style(size: 11, color: gray)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(_sanitize(driverName),
                          style: bold(size: 12)),
                      pw.Text('Periode: ${_periodLabel(from, to)}',
                          style: style(size: 9, color: gray)),
                      pw.Text(
                          'Dicetak: ${_dateFmt.format(DateTime.now())}',
                          style: style(size: 9, color: gray)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: green, thickness: 1.5),
              pw.SizedBox(height: 12),

              // Summary boxes
              pw.Row(children: [
                _summaryBox('Total Trip',
                    '${trips.length}', green, bold, style),
                pw.SizedBox(width: 8),
                _summaryBox('Total Tarif',
                    _fmtIdr(totalFare), gray, bold, style),
                pw.SizedBox(width: 8),
                _summaryBox('Potongan Platform',
                    _fmtIdr(totalFee), gray, bold, style),
                pw.SizedBox(width: 8),
                _summaryBox('Total Pendapatan',
                    _fmtIdr(totalEarn), green, bold, style),
              ]),
              pw.SizedBox(height: 16),
            ],

            if (!isFirst)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Text(
                    'Riwayat Perjalanan (lanjutan halaman ${pi + 1})',
                    style: bold(size: 12)),
              ),

            // ── Tabel ────────────────────────────────────
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2), // Tanggal
                1: const pw.FlexColumnWidth(2.0), // Pickup
                2: const pw.FlexColumnWidth(2.0), // Tujuan
                3: const pw.FlexColumnWidth(0.7), // Km
                4: const pw.FlexColumnWidth(1.0), // Tarif
                5: const pw.FlexColumnWidth(1.2), // Pendapatan
              },
              border: pw.TableBorder.symmetric(
                inside: pw.BorderSide(
                    color: PdfColor.fromHex('#E5E7EB'),
                    width: 0.5),
              ),
              children: [
                // Header row
                pw.TableRow(
                  decoration:
                      pw.BoxDecoration(color: green),
                  children: [
                    'Tanggal', 'Pickup', 'Tujuan',
                    'Km', 'Tarif', 'Pendapatan',
                  ].map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6, vertical: 5),
                    child: pw.Text(h,
                        style: bold(
                            size: 8,
                            color: PdfColors.white)),
                  )).toList(),
                ),

                // Data rows
                ...pagTrips.asMap().entries.map((entry) {
                  final i = entry.key;
                  final t = entry.value;
                  final bg = i.isEven ? light : PdfColors.white;
                  return pw.TableRow(
                    decoration:
                        pw.BoxDecoration(color: bg),
                    children: [
                      _cell(DateFormat('dd/MM/yy HH:mm')
                          .format(t.date), style),
                      _cell(t.pickup, style, maxLen: 28),
                      _cell(t.dropoff, style, maxLen: 28),
                      _cell('${t.distanceKm.toStringAsFixed(1)}', style),
                      _cell(_fmtIdr(t.fare), style),
                      _cell(_fmtIdr(t.earn),
                          (
                              {double size = 10,
                              pw.Font? font,
                              PdfColor? color}) =>
                              bold(size: size, color: green)),
                    ],
                  );
                }),
              ],
            ),

            pw.Spacer(),

            // Footer
            pw.Divider(
                color: PdfColor.fromHex('#E5E7EB'),
                thickness: 0.5),
            pw.Row(
              mainAxisAlignment:
                  pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                    'Nama penumpang dirahasiakan sesuai kebijakan privasi RIHLAH',
                    style: style(size: 7, color: gray)),
                pw.Text(
                    'Halaman ${pi + 1} dari ${pages.length}',
                    style: style(size: 7, color: gray)),
              ],
            ),
          ],
        ),
      ));
    }

    // Share/print
    await Printing.sharePdf(
      bytes   : await pdf.save(),
      filename: 'rihlah_history_'
          '${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  pw.Widget _summaryBox(
    String label,
    String value,
    PdfColor color,
    pw.TextStyle Function({double size, PdfColor? color}) boldFn,
    pw.TextStyle Function({double size, pw.Font? font, PdfColor? color}) styleFn,
  ) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color : color.shade(0.08),
            border: pw.Border.all(
                color: color.shade(0.3), width: 0.5),
            borderRadius: const pw.BorderRadius.all(
                pw.Radius.circular(4)),
          ),
          child: pw.Column(
            crossAxisAlignment:
                pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: styleFn(
                      size: 7,
                      color: color.shade(0.6))),
              pw.SizedBox(height: 3),
              pw.Text(value,
                  style: boldFn(size: 10, color: color)),
            ],
          ),
        ),
      );

  pw.Widget _cell(
    String text,
    pw.TextStyle Function({double size, pw.Font? font, PdfColor? color}) styleFn, {
    int? maxLen,
  }) {
    final display = maxLen != null && text.length > maxLen
        ? '${text.substring(0, maxLen)}…'
        : text;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
          horizontal: 6, vertical: 4),
      child: pw.Text(display, style: styleFn(size: 8)),
    );
  }

  String _sanitize(String s) {
    // Escape koma untuk CSV
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  String _serviceLabel(String s) => switch (s) {
    'bike' => 'Motor',
    'send' => 'Kurir',
    _      => 'Mobil',
  };

  String _periodLabel(DateTime? from, DateTime? to) {
    if (from == null || to == null) return 'Semua waktu';
    return '${_dateFmt.format(from)} — ${_dateFmt.format(to)}';
  }

  void _showEmpty(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Tidak ada data untuk diekspor')),
    );
  }
}