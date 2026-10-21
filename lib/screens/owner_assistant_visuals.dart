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
      OwnerCard(child: _OwnerChart(chart!, showNotes: report == null)),
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
  final bool showNotes;
  const _OwnerChart(this.data,{required this.showNotes});

  List<_PlotPoint> points() {
    final result=< _PlotPoint >[];
    final series=data['series'];
    if(series is! List)return result;
    for(final entry in series.take(4)){
      if(entry is! Map || entry['data'] is! List)continue;
      final prefix=series.length>1 ? '${entry['name'] ?? ''} • ' : '';
      for(final item in (entry['data'] as List).take(24)){
        if(item is! Map)continue;
        final value=item['value'];
        if(value is! num || !value.isFinite)continue;
        result.add(_PlotPoint('$prefix${item['label'] ?? '—'}',
          value.toDouble()));
      }
    }
    return result.take(24).toList(growable:false);
  }

  @override
  Widget build(BuildContext context){
    final pointsList=points();
    final muted=TextStyle(fontSize:11,color:OwnerPalette.muted(context));
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text((data['title']??'Диаграмма').toString(),
        style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),
      if((data['subtitle']??'').toString().trim().isNotEmpty) ...[
        const SizedBox(height:4),
        Text(data['subtitle'].toString(),style:muted),
      ],
      const SizedBox(height:12),
      if(pointsList.isEmpty)
        const Text('Сервер не вернул числовые точки для диаграммы.')
      else
        OwnerRevenueDiagram(
          labelWidth:112,
          values:pointsList.map((p)=>p.value).toList(),
          labels:pointsList.map((p)=>p.label).toList(),
          valueLabels:pointsList.map((p)=>p.value.toStringAsFixed(2)).toList(),
        ),
      for(final note in (showNotes && data['notes'] is List
        ?(data['notes'] as List).take(2):<dynamic>[])) ...[
        const SizedBox(height:4),
        Text(note.toString(),style:muted),
      ],
    ]);
  }
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
      if (notes.isNotEmpty) ...[
        const SizedBox(height: 7),
        Divider(color: Theme.of(context).dividerColor),
        for (final note in notes.toSet().take(3))
          Padding(padding: const EdgeInsets.only(top: 5),
            child: Text(note.toString(),
              style: TextStyle(fontSize: 12, height: 1.35,
                color: OwnerPalette.muted(context)))),
      ],
    ]);
  }
}
