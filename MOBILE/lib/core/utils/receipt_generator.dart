// lib/core/utils/receipt_generator.dart

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptGenerator {
  ReceiptGenerator._();

  static Future<void> generate({
    required String tripId,
    required String pickup,
    required String dropoff,
    required int    fare,
    required int    tip,
    required int    discount,
    required String service,
    required String driver,
    required DateTime date,
  }) async {
    final pdf     = pw.Document();
    final primary = PdfColor.fromHex('4CA66E');
    final ink900  = PdfColor.fromHex('1A1A2E');
    final ink500  = PdfColor.fromHex('6B7280');
    final ink200  = PdfColor.fromHex('E5E7EB');
    final ink100  = PdfColor.fromHex('F3F4F6');
    final white   = PdfColors.white;

    const months = [
      'Jan','Feb','Mar','Apr','Mei','Jun',
      'Jul','Agu','Sep','Okt','Nov','Des',
    ];
    final dateLabel =
        '${date.day} ${months[date.month - 1]} ${date.year}  '
        '${date.hour.toString().padLeft(2,'0')}:'
        '${date.minute.toString().padLeft(2,'0')}';

    final total = (fare + tip).clamp(0, 999999);

    String fmtIdr(int v) {
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

    String serviceLabel(String s) => switch (s) {
      'bike' => 'Motor',
      'send' => 'Kurir',
      _      => 'Mobil',
    };

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(0),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [

            // ── Header hijau ──────────────────────────
            pw.Container(
              color: primary,
              padding: const pw.EdgeInsets.fromLTRB(32, 36, 32, 28),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 32, height: 32,
                        decoration: pw.BoxDecoration(
                          color: white,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Center(
                          child: pw.Text('R',
                              style: pw.TextStyle(
                                  color: primary,
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold)),
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Text('RIHLAH',
                          style: pw.TextStyle(
                              color: white,
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 2)),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text('Struk Perjalanan',
                      style: pw.TextStyle(
                          color: const PdfColor(1, 1, 1, 0.8),
                          fontSize: 11)),
                  pw.SizedBox(height: 4),
                  pw.Text(fmtIdr(total),
                      style: pw.TextStyle(
                          color: white,
                          fontSize: 34,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(dateLabel,
                      style: pw.TextStyle(
                          color: const PdfColor(1, 1, 1, 0.75),
                          fontSize: 10)),
                ],
              ),
            ),

            // ── Status bar ────────────────────────────
            pw.Container(
              color: ink100,
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 32, vertical: 10),
              child: pw.Row(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('D4EDDA'),
                      borderRadius: pw.BorderRadius.circular(20),
                    ),
                    child: pw.Text('SELESAI',
                        style: pw.TextStyle(
                            color: primary,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Spacer(),
                  pw.Text('Bayar Tunai',
                      style: pw.TextStyle(
                          color: ink500, fontSize: 10)),
                ],
              ),
            ),

            // ── Rute ─────────────────────────────────
            pw.Container(
              color: white,
              padding: const pw.EdgeInsets.fromLTRB(32, 20, 32, 20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Column(children: [
                        pw.Container(
                          width: 10, height: 10,
                          decoration: pw.BoxDecoration(
                              color: primary,
                              shape: pw.BoxShape.circle),
                        ),
                        pw.Container(
                            width: 2, height: 28, color: ink200),
                      ]),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment:
                              pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('JEMPUT',
                                style: pw.TextStyle(
                                    color: ink500,
                                    fontSize: 8,
                                    letterSpacing: 1)),
                            pw.SizedBox(height: 2),
                            pw.Text(pickup,
                                style: pw.TextStyle(
                                    color: ink900,
                                    fontSize: 11,
                                    fontWeight:
                                        pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 10, height: 10,
                        decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('EF4444'),
                            shape: pw.BoxShape.circle),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment:
                              pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('TUJUAN',
                                style: pw.TextStyle(
                                    color: ink500,
                                    fontSize: 8,
                                    letterSpacing: 1)),
                            pw.SizedBox(height: 2),
                            pw.Text(dropoff,
                                style: pw.TextStyle(
                                    color: ink900,
                                    fontSize: 11,
                                    fontWeight:
                                        pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.Divider(color: ink200, thickness: 1),

            // ── Detail rows ───────────────────────────
            pw.Container(
              color: white,
              padding: const pw.EdgeInsets.fromLTRB(32, 16, 32, 16),
              child: pw.Column(
                children: [
                  _row('ID Perjalanan', tripId,
                      ink900, ink500, valueSize: 8),
                  pw.SizedBox(height: 10),
                  _row('Driver', driver, ink900, ink500),
                  pw.SizedBox(height: 10),
                  _row('Layanan', serviceLabel(service),
                      ink900, ink500),
                  pw.SizedBox(height: 10),
                  if (discount > 0) ...[
                    _row('Tarif',
                        fmtIdr(fare + discount), ink900, ink500),
                    pw.SizedBox(height: 10),
                    _row('Diskon', '-${fmtIdr(discount)}',
                        PdfColor.fromHex('4CA66E'), ink500),
                    pw.SizedBox(height: 10),
                  ],
                  if (tip > 0) ...[
                    _row('Tip', fmtIdr(tip), ink900, ink500),
                    pw.SizedBox(height: 10),
                  ],
                  _row('Tarif bersih', fmtIdr(fare),
                      ink900, ink500, bold: true),
                ],
              ),
            ),

            pw.Divider(color: ink200, thickness: 1),

            // ── Total ─────────────────────────────────
            pw.Container(
              color: white,
              padding: const pw.EdgeInsets.fromLTRB(32, 16, 32, 16),
              child: pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL',
                      style: pw.TextStyle(
                          color: ink500,
                          fontSize: 10,
                          letterSpacing: 1)),
                  pw.Text(fmtIdr(total),
                      style: pw.TextStyle(
                          color: ink900,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),

            pw.Spacer(),

            // ── Footer ────────────────────────────────
            pw.Container(
              color: ink100,
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 32, vertical: 16),
              child: pw.Center(
                child: pw.Text(
                  'Terima kasih telah menggunakan RIHLAH  •  rihlah.id',
                  style: pw.TextStyle(
                      color: ink500, fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'rihlah-receipt-$tripId.pdf',
    );
  }

  static pw.Widget _row(
    String label,
    String value,
    PdfColor valueColor,
    PdfColor labelColor, {
    bool   bold      = false,
    double valueSize = 11,
  }) =>
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  color: labelColor, fontSize: 10)),
          pw.Text(value,
              style: pw.TextStyle(
                  color: valueColor,
                  fontSize: valueSize,
                  fontWeight: bold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal)),
        ],
      );
}