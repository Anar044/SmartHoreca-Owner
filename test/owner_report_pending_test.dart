import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_state.dart';
import 'package:smart_horeca_owner/screens/reports_screen.dart';

void main() {
  testWidgets('P&L shows honest unavailable state instead of sales KPI',
      (tester) async {
    final owner = OwnerState();
    addTearDown(owner.dispose);
    await tester.pumpWidget(
      OwnerScope(
        state: owner,
        child: const MaterialApp(
          home: OwnerReportPendingScreen(title: 'P&L'),
        ),
      ),
    );
    expect(find.text('Отчёт пока не подключён'), findsOneWidget);
    expect(find.text('Выручка'), findsNothing);
    expect(find.text('Чеков'), findsNothing);
  });

  testWidgets('stock movements never reuse cash-revenue chart',
      (tester) async {
    final owner = OwnerState();
    addTearDown(owner.dispose);
    await tester.pumpWidget(
      OwnerScope(
        state: owner,
        child: const MaterialApp(
          home: OwnerReportPendingScreen(title: 'Движение товаров'),
        ),
      ),
    );
    expect(find.text('Движение товаров'), findsOneWidget);
    expect(find.text('Отчёт пока не подключён'), findsOneWidget);
    expect(find.text('Выручка'), findsNothing);
  });
}
