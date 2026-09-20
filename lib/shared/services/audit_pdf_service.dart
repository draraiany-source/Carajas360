import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';

/// Gera e compartilha relatorio de auditoria (PDF / CSV).
abstract final class AuditPdfService {
  static String _pad2(int n) => n.toString().padLeft(2, '0');

  static String formatDateTime(DateTime dt) =>
      '${_pad2(dt.day)}/${_pad2(dt.month)}/${dt.year} ${_pad2(dt.hour)}:${_pad2(dt.minute)}';

  static String detailsText(Map<String, dynamic>? details) {
    if (details == null || details.isEmpty) return '-';
    try {
      return jsonEncode(details);
    } catch (_) {
      return details.toString();
    }
  }

  static String buildCsv(List<AuditLogModel> logs) {
    final buffer = StringBuffer(
        'Data/Hora,Acao,Admin,AdminId,Alvo,Detalhes\n');
    for (final l in logs) {
      final details = detailsText(l.details).replaceAll('"', '""');
      buffer.writeln(
        '"${formatDateTime(l.timestamp)}",'
        '"${l.action.replaceAll('"', '""')}",'
        '"${l.adminName.replaceAll('"', '""')}",'
        '"${l.adminId}",'
        '"${l.target.replaceAll('"', '""')}",'
        '"$details"',
      );
    }
    return buffer.toString();
  }

  static Future<Uint8List> buildPdf(List<AuditLogModel> logs) async {
    final now = DateTime.now();
    final generatedAt = formatDateTime(now);
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Relatorio de Auditoria',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Carajas 360 — gerado em $generatedAt — ${logs.length} registro(s)',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 12),
          ],
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Pagina ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
        ),
        build: (ctx) => [
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.2),
              1: const pw.FlexColumnWidth(2.8),
              2: const pw.FlexColumnWidth(2.0),
              3: const pw.FlexColumnWidth(2.2),
              4: const pw.FlexColumnWidth(3.0),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                children: [
                  _headerCell('Data/Hora'),
                  _headerCell('Acao'),
                  _headerCell('Admin'),
                  _headerCell('Alvo'),
                  _headerCell('Detalhes'),
                ],
              ),
              for (final l in logs)
                pw.TableRow(
                  children: [
                    _bodyCell(formatDateTime(l.timestamp)),
                    _bodyCell(l.action),
                    _bodyCell(l.adminName),
                    _bodyCell(l.target),
                    _bodyCell(detailsText(l.details), small: true),
                  ],
                ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _headerCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
        ),
      );

  static pw.Widget _bodyCell(String text, {bool small = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: small ? 7.5 : 8.5),
        ),
      );

  static Future<void> share({
    required List<AuditLogModel> logs,
    required bool csv,
  }) async {
    if (logs.isEmpty) {
      throw StateError('Nenhum registro de auditoria para exportar.');
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    if (csv) {
      final bytes = utf8.encode(buildCsv(logs));
      final name = 'auditoria_carajas360_$timestamp.csv';
      await SharePlus.instance.share(ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(bytes),
            name: name,
            mimeType: 'text/csv',
          ),
        ],
        text: 'Auditoria — Carajas 360',
      ));
      return;
    }

    final pdfBytes = await buildPdf(logs);
    final name = 'auditoria_carajas360_$timestamp.pdf';
    await SharePlus.instance.share(ShareParams(
      files: [
        XFile.fromData(pdfBytes, name: name, mimeType: 'application/pdf'),
      ],
      text: 'Auditoria — Carajas 360',
    ));
  }
}