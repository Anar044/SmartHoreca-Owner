import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/owner_theme.dart';
import '../ui/owner_components.dart';

/// Server-grounded chart + report, rendered ONLY from a structured
/// authenticated AI response. No data is parsed or invented from prose.
class OwnerAssistantVisuals extends StatelessWidget {
  final Map<String, dynamic>? chart;
  final Map<String, dynamic>? report;
  const OwnerAssistantVisuals({super.key, this.chart, this.report});

  static Map<String, dynamic>? structured(dynamic value) {
    if (value is! Map) return null;
    return Map<String, dynamic>.from(value);
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    if (chart != null) ...[
      const SizedBox(height: 9),
      OwnerCard(child: _OwnerChart(chart!)),
    ],
    if (report != null) ...[
      const SizedBox(height: 9),
      OwnerCard(child: _OwnerReport(report!)),
    ],
  ]);
}

class _PlotPoint {
  final String label;
  final double value;
  const _PlotPoint(this.label, this.value);
}

class _OwnerChart extends StatelessWidget {
  final Map<String, dynamic> data;
  const _OwnerChart(this.data);

  List<_PlotPoint> points() {
    final items = <_PlotPoint>[];
    final series = data['series'];
    if (series is! List) return items;
    for (final entry in series.take(4)) {
      if (entry is! Map || entry['data'] is! List) continue;
      final prefix = series.length > 1 ? '${entry['name'] ?? ''} • ' : '';
      for (final raw in (entry['data'] as List).take(24)) {
        if (raw is! Map) continue;
        final value = raw['value'];
        if (value is! num || !value.isFinite) continue;
        items.add(_PlotPoint('$prefix${raw['label'] ?? '—'}',
            value.toDouble()));
      }
    }
    return items.take(28).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final values = points();
    final kind = (data['type'] ?? 'bar').toString();
    final accent = OwnerPalette.accent(context);
    final labelStyle = TextStyle(
      fontSize: 11, color: OwnerPalette.muted(context));
    final maxAbs = values.fold<double>(0,
      (maxV, point) => math.max(maxV, point.value.abs()));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text((data['title'] ?? 'Диаграмма').toString(),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      if ((data['subtitle'] ?? '').toString().trim().isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(data['subtitle'].toString(), style: labelStyle),
      ],
      const SizedBox(height: 14),
      if (values.isEmpty)
        const Text('Сервер не вернул числовые точки для диаграммы.')
      else if (kind == 'pie') ...[
        Center(child: CustomPaint(size: const Size(170, 170),
          painter: _PiePainter(values, accent))),
        const SizedBox(height: 8),
        ...values.take(12).map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text('${p.label}: ${p.value.toStringAsFixed(2)}',
              style: labelStyle),
        )),
      ] else if (kind == 'line') ...[
        SizedBox(height: 155, width: double.infinity,
          child: CustomPaint(painter: _LinePainter(values, accent))),
        const SizedBox(height: 8),
        Text(values.map((p) =>
          '${p.label}: ${p.value.toStringAsFixed(2)}').join('   ·   '),
          style: labelStyle),
      ] else ...[
        for (final point in values) ...[
          Row(children: [
            Expanded(child: Text(point.label, maxLines: 2,
              overflow: TextOverflow.ellipsis, style: labelStyle)),
            const SizedBox(width: 6),
            Text(point.value.toStringAsFixed(2),
              style: const TextStyle(fontWeight: FontWeight.w600,
                fontSize: 12)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: maxAbs > 0 ? point.value.abs() / maxAbs : 0,
              color: point.value < 0 ? OwnerPalette.error : accent,
              backgroundColor: accent.withValues(alpha: .12),
            ),
          ),
          const SizedBox(height: 11),
        ],
      ],
      for (final note in (data['notes'] is List
          ? (data['notes'] as List).take(4) : <dynamic>[])) ...[
        const SizedBox(height: 4),
        Text(note.toString(), style: labelStyle),
      ],
    ]);
  }
}

class _LinePainter extends CustomPainter {
  final List<_PlotPoint> points;
  final Color color;
  const _LinePainter(this.points, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final low = points.map((p) => p.value).reduce(math.min);
    final high = points.map((p) => p.value).reduce(math.max);
    final spread = high - low;
    const pad = 8.0;
    final coords = List.generate(points.length, (i) {
      final x = points.length == 1 ? size.width / 2 :
        pad + (size.width - pad * 2) * i / (points.length - 1);
      final y = spread == 0 ? size.height / 2 :
        pad + (size.height - pad * 2) *
          (1 - ((points[i].value - low) / spread));
      return Offset(x, y);
    });
    final p = Paint()..color = color..strokeWidth = 2.8
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final line = Path()..moveTo(coords.first.dx, coords.first.dy);
    for (final point in coords.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(line, p);
    final dot = Paint()..color = color;
    for (final pt in coords) canvas.drawCircle(pt, 3.8, dot);
  }
  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.points != points || old.color != color;
}

class _PiePainter extends CustomPainter {
  final List<_PlotPoint> values;
  final Color accent;
  const _PiePainter(this.values, this.accent);
  @override
  void paint(Canvas canvas, Size size) {
    final usable = values.where((p) => p.value > 0).toList();
    final total = usable.fold<double>(0, (s, p) => s + p.value);
    if (total <= 0) return;
    final palette = <Color>[
      accent, Colors.teal, Colors.orange, Colors.purple,
      Colors.indigo, Colors.cyan, Colors.amber, Colors.pink,
    ];
    final square = Rect.fromLTWH(0, 0, size.width, size.height);
    var begin = -math.pi / 2;
    for (var i = 0; i < usable.length; i++) {
      final sweep = usable[i].value / total * math.pi * 2;
      canvas.drawArc(square, begin, sweep, true,
        Paint()..color = palette[i % palette.length]);
      begin += sweep;
    }
  }
  @override
  bool shouldRepaint(covariant _PiePainter old) =>
      old.values != values || old.accent != accent;
}

class _OwnerReport extends StatelessWidget {
  final Map<String, dynamic> data;
  const _OwnerReport(this.data);
  @override
  Widget build(BuildContext context) {
    final cols = data['columns'] is List
        ? (data['columns'] as List).take(12).toList()
        : <dynamic>[];
    final rows = data['rows'] is List
        ? (data['rows'] as List).take(45).toList()
        : <dynamic>[];
    final notes = data['notes'] is List
        ? (data['notes'] as List).take(6).toList()
        : <dynamic>[];
    final kpis = data['kpis'] is List
        ? (data['kpis'] as List).take(8).toList()
        : <dynamic>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text((data['title'] ?? 'AI Report').toString(),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      if ((data['subtitle'] ?? '').toString().trim().isNotEmpty) ...[
        const SizedBox(height: 5),
        Text(data['subtitle'].toString(),
          style: TextStyle(color: OwnerPalette.muted(context))),
      ],
      const SizedBox(height: 10),
      for (final kpi in kpis)
        if (kpi is Map)
          Padding(padding: const EdgeInsets.only(bottom: 7),
            child: Row(children: [
              Expanded(child: Text((kpi['label'] ?? '').toString())),
              Text((kpi['value'] ?? '').toString(),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            ])),
      if (cols.isNotEmpty) ...[
        const SizedBox(height: 8),
        SingleChildScrollView(scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              for (final col in cols)
                DataColumn(label: Text(
                  col is Map ? (col['label'] ?? '').toString() :
                      col.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: [
              for (final row in rows)
                if (row is List)
                  DataRow(cells: [
                    for (var i = 0; i < cols.length; i++)
                      DataCell(Text(i < row.length ? row[i].toString() : '')),
                  ]),
            ],
          ),
        ),
      ],
      for (final note in notes)
        Padding(padding: const EdgeInsets.only(top: 5),
          child: Text(note.toString(),
            style: TextStyle(fontSize: 11,
              color: OwnerPalette.muted(context)))),
    ]);
  }
}
