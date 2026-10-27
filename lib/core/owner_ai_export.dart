import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Export only the answer the user is currently authorized to see.
/// No additional server request or cross-restaurant data lookup is performed.
class OwnerAiExport {
  const OwnerAiExport._();

  static Future<void> copyAnswer(String answer) =>
      Clipboard.setData(ClipboardData(text: answer));

  static Future<void> shareAnswerPdf({
    required String answer,
    Map<String, dynamic>? report,
    Map<String, dynamic>? chart,
  }) async {
    // Noto Sans supports Azerbaijani Latin and Russian Cyrillic text.
    // The printing package caches the font after its initial download.
    final font = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final document = pw.Document();
    final style = pw.TextStyle(font: font, fontSize: 10.5, lineSpacing: 3);
    final subheading = pw.TextStyle(font: bold, fontSize: 13,
        color: PdfColor.fromHex('#164775'));
    final widgets = <pw.Widget>[
      pw.Text('SH Owner · AI Smart Horeca Assistant',
          style: pw.TextStyle(font: bold, fontSize: 16,
              color: PdfColor.fromHex('#123A60'))),
      pw.SizedBox(height: 8),
      pw.Divider(color: PdfColor.fromHex('#B6D8E7')),
      pw.SizedBox(height: 12),
      pw.Text(answer.trim().isEmpty ? '—' : answer.trim(),
          style: style),
    ];

    if (report != null) {
      widgets.add(pw.SizedBox(height: 18));
      widgets.add(pw.Text((report['title'] ?? 'AI Report').toString(),
          style: subheading));
      for (final key in ['subtitle', 'periodLabel']) {
        final value = (report[key] ?? '').toString().trim();
        if (value.isNotEmpty) widgets.add(pw.Text(value, style: style));
      }
      final kpis = report['kpis'];
      if (kpis is List) {
        for (final item in kpis.take(12)) {
          if (item is Map) {
            widgets.add(pw.Padding(
              padding: const pw.EdgeInsets.only(top: 5),
              child: pw.Text(
                (item['label'] ?? '').toString() + ': ' +
                    (item['value'] ?? '').toString(),
                style: style),
            ));
          }
        }
      }
      final columns = report['columns'];
      final rows = report['rows'];
      if (columns is List && columns.isNotEmpty && rows is List) {
        final header = columns.take(10).map((item) =>
            item is Map ? (item['label'] ?? '').toString()
                : item.toString()).toList();
        final tableRows = <List<String>>[header];
        for (final row in rows.take(75)) {
          if (row is List) {
            tableRows.add(List.generate(header.length,
              (index) => index < row.length ? row[index].toString() : ''));
          }
        }
        if (tableRows.length > 1) {
          widgets.add(pw.SizedBox(height: 10));
          widgets.add(pw.TableHelper.fromTextArray(
            data: tableRows,
            headerStyle: pw.TextStyle(font: bold, fontSize: 8),
            cellStyle: pw.TextStyle(font: font, fontSize: 8),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#E6F3FA')),
            cellPadding: const pw.EdgeInsets.all(5),
          ));
        }
      }
      final notes = report['notes'];
      if (notes is List) {
        for (final note in notes.take(6)) {
          widgets.add(pw.Padding(
              padding: const pw.EdgeInsets.only(top: 5),
              child: pw.Text(note.toString(), style: style)));
        }
      }
    }
    if (chart != null) {
      widgets.add(pw.SizedBox(height: 16));
      widgets.add(pw.Text((chart['title'] ?? 'Chart').toString(),
          style: subheading));
      // Preserve chart data as numbers in the PDF even when the
      // platform-specific chart painter is not available to dart_pdf.
      final series = chart['series'];
      if (series is List) {
        for (final seriesItem in series.take(4)) {
          if (seriesItem is! Map) continue;
          widgets.add(pw.Text((seriesItem['name'] ?? '').toString(),
            style: pw.TextStyle(font: bold, fontSize: 10)));
          final points = seriesItem['data'];
          if (points is List) {
            for (final point in points.take(32)) {
              if (point is Map) {
                widgets.add(pw.Text(
                  (point['label'] ?? '').toString() + ': ' +
                      (point['value'] ?? '').toString(),
                  style: style));
              }
            }
          }
        }
      }
    }

    document.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(38),
      build: (_) => widgets,
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(context.pageNumber.toString(),
          style: pw.TextStyle(font: font, fontSize: 9)),
      ),
    ));
    await Printing.sharePdf(
      bytes: await document.save(),
      filename: 'SH-Owner-AI-Answer.pdf',
    );
  }
}
