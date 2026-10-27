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

  /// Copy both the answer and the numeric data represented by its graph(s).
  /// A platform clipboard image cannot be set by Flutter's text Clipboard API;
  /// the PDF action separately preserves an actual graphical visualization.
  static String answerWithVisualsText({
    required String answer,
    Map<String, dynamic>? report,
    List<Map<String, dynamic>> charts = const [],
    Map<String, dynamic>? chart,
  }) {
    final lines = <String>[answer.trim()];
    final graphList = charts.isNotEmpty
        ? charts.take(3).toList()
        : chart == null ? <Map<String, dynamic>>[] : [chart];
    if (report != null) {
      final title = _safe((report['title'] ?? '').toString());
      if (title.isNotEmpty) lines.add(title);
      for (final key in ['subtitle', 'periodLabel']) {
        final detail = _safe((report[key] ?? '').toString()).trim();
        if (detail.isNotEmpty) lines.add(detail);
      }
      final columns = report['columns'];
      final rows = report['rows'];
      if (columns is List && rows is List) {
        lines.add(columns.map((c) =>
            _safe((c is Map ? c['label'] : c).toString())).join(' | '));
        for (final row in rows.take(75)) {
          if (row is List) {
            lines.add(row.map((v) => _safe(v.toString())).join(' | '));
          }
        }
      }
    }
    for (final graph in graphList) {
      lines.add(_safe((graph['title'] ?? 'Chart').toString()));
      final subtitle = _safe((graph['subtitle'] ?? '').toString()).trim();
      if (subtitle.isNotEmpty) lines.add(subtitle);
      final series = graph['series'];
      if (series is! List) continue;
      for (final item in series.take(4)) {
        if (item is! Map || item['data'] is! List) continue;
        final name = _safe((item['name'] ?? '').toString()).trim();
        if (name.isNotEmpty && series.length > 1) lines.add(name);
        for (final point in (item['data'] as List).take(32)) {
          if (point is! Map || point['value'] is! num) continue;
          lines.add("${_safe((point['label'] ?? '').toString())}: ${point['value']}");
        }
      }
    }
    return lines.where((line) => line.isNotEmpty).join('\n\n');
  }

  static String _safe(String value) => value.replaceAll(
    RegExp(r'iiko(?:Chain|Front)?', caseSensitive: false), 'Smart Horeca');

  static Future<void> copyAnswerWithVisuals({
    required String answer,
    Map<String, dynamic>? report,
    List<Map<String, dynamic>> charts = const [],
    Map<String, dynamic>? chart,
  }) => copyAnswer(answerWithVisualsText(
    answer: answer, report: report, charts: charts, chart: chart,
  ));

  /// Print bar charts as vector rectangles + Unicode labels, rather than
  /// exporting only their underlying numbers as in the previous version.
  static List<pw.Widget> _pdfGraphs({
    required List<Map<String, dynamic>> charts,
    required pw.Font font,
    required pw.Font bold,
  }) {
    final result = <pw.Widget>[];
    final regular = pw.TextStyle(font: font, fontSize: 9);
    final heading = pw.TextStyle(
      font: bold, fontSize: 12, color: PdfColor.fromHex('#164775'));
    for (final chart in charts.take(3)) {
      final title = _safe((chart['title'] ?? 'Chart').toString());
      result.add(pw.SizedBox(height: 14));
      result.add(pw.Text(title, style: heading));
      final subtitle = _safe((chart['subtitle'] ?? '').toString());
      if (subtitle.isNotEmpty) {
        result.add(pw.Text(subtitle, style: regular));
      }
      final series = chart['series'];
      if (series is! List) continue;
      final points = <(String, double)>[];
      for (final row in series.take(4)) {
        if (row is! Map || row['data'] is! List) continue;
        final prefix = series.length > 1
            ? '${_safe((row['name'] ?? '').toString())} · ' : '';
        for (final item in (row['data'] as List).take(24)) {
          if (item is! Map || item['value'] is! num) continue;
          final number = item['value'] as num;
          if (!number.isFinite) continue;
          points.add((
            prefix + _safe((item['label'] ?? '—').toString()),
            number.toDouble(),
          ));
        }
      }
      if (points.isEmpty) continue;
      final maximum = points.fold<double>(
        0, (prev, entry) => entry.$2.abs() > prev ? entry.$2.abs() : prev);
      for (final point in points.take(36)) {
        final width = maximum > 0
            ? (point.$2.abs() / maximum * 215).clamp(0.0, 215.0)
            : 0.0;
        result.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.Row(children: [
            pw.SizedBox(
              width: 135,
              child: pw.Text(point.$1,
                maxLines: 2,
                style: regular)),
            pw.SizedBox(width: 8),
            pw.SizedBox(width: 215, height: 12,
              child: pw.Stack(children: [
                pw.Container(width: 215, height: 12,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#E8F0FA'))),
                pw.Container(width: width, height: 12,
                  decoration: pw.BoxDecoration(
                    color: point.$2 < 0
                      ? PdfColor.fromHex('#DD704A')
                      : PdfColor.fromHex('#2869E4'))),
              ]),
            ),
            pw.SizedBox(width: 9),
            pw.Expanded(child: pw.Text(
              point.$2.toStringAsFixed(2), style: regular)),
          ]),
        ));
      }
      final notes = chart['notes'];
      if (notes is List) {
        for (final note in notes.take(2)) {
          result.add(pw.Padding(
            padding: const pw.EdgeInsets.only(top: 5),
            child: pw.Text(_safe(note.toString()),
              style: pw.TextStyle(font: font, fontSize: 8)),
          ));
        }
      }
    }
    return result;
  }

  static Future<void> shareAnswerPdf({
    required String answer,
    Map<String, dynamic>? report,
    Map<String, dynamic>? chart,
    List<Map<String, dynamic>> charts = const [],
  }) async {
    final visibleCharts = charts.isNotEmpty
      ? charts.take(3).toList()
      : chart == null ? <Map<String, dynamic>>[] : [chart];
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
      pw.Text(_safe(answer.trim().isEmpty ? '—' : answer.trim()),
          style: style),
    ];

    if (report != null) {
      widgets.add(pw.SizedBox(height: 18));
      widgets.add(pw.Text(_safe((report['title'] ?? 'AI Report').toString()),
          style: subheading));
      for (final key in ['subtitle', 'periodLabel']) {
        final value = _safe((report[key] ?? '').toString()).trim();
        if (value.isNotEmpty) widgets.add(pw.Text(value, style: style));
      }
      final kpis = report['kpis'];
      if (kpis is List) {
        for (final item in kpis.take(12)) {
          if (item is Map) {
            widgets.add(pw.Padding(
              padding: const pw.EdgeInsets.only(top: 5),
              child: pw.Text(
                "${_safe((item['label'] ?? '').toString())}: ${_safe((item['value'] ?? '').toString())}",
                style: style),
            ));
          }
        }
      }
      final columns = report['columns'];
      final rows = report['rows'];
      if (columns is List && columns.isNotEmpty && rows is List) {
        final header = columns.take(10).map((item) => _safe(
            item is Map ? (item['label'] ?? '').toString()
                : item.toString())).toList();
        final tableRows = <List<String>>[header];
        for (final row in rows.take(75)) {
          if (row is List) {
            tableRows.add(List.generate(header.length,
              (index) => index < row.length
                ? _safe(row[index].toString()) : ''));
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
              child: pw.Text(_safe(note.toString()), style: style)));
        }
      }
    }
    widgets.addAll(_pdfGraphs(charts: visibleCharts, font: font, bold: bold));
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
      filename: 'SH-Owner-AI-Report.pdf',
    );
  }
}
