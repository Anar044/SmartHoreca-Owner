import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/screens/owner_assistant_visuals.dart';

void main() {
  testWidgets('shows server-provided chart points and no invented data',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: OwnerAssistantVisuals(chart: {
            'title': 'Продажи ресторанов',
            'type': 'horizontal_bar',
            'series': [
              {
                'name': 'Продажи',
                'data': [
                  {'label': 'RMS 1', 'value': 31},
                  {'label': 'RMS 2', 'value': 0}
                ]
              }
            ],
            'notes': ['Источник: SH OLAP'],
          }),
        ),
      ),
    ));
    expect(find.text('Продажи ресторанов'), findsOneWidget);
    expect(find.text('RMS 1'), findsOneWidget);
    expect(find.text('31.00'), findsOneWidget);
    expect(find.text('Источник: SH OLAP'), findsOneWidget);
  });

  testWidgets('renders structured AI report with actual cells',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(
        child: OwnerAssistantVisuals(report: {
          'title': 'Отчёт по ресторанам',
          'columns': [{'label': 'Ресторан'}, {'label': 'Выручка'}],
          'rows': [['RMS 1', '31 AZN']],
          'kpis': [{'label': 'Всего', 'value': '31 AZN'}],
          'notes': <String>[],
        }),
      )),
    ));
    expect(find.text('Отчёт по ресторанам'), findsOneWidget);
    expect(find.text('RMS 1'), findsOneWidget);
    expect(find.text('31 AZN'), findsWidgets);
  });
}
