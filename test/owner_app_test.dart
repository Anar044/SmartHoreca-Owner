import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/main.dart';

void main() {
  testWidgets('approved flow opens preview and keeps four bottom tabs', (tester) async {
    await tester.pumpWidget(const SmartHorecaOwnerApp());
    expect(find.text('SMART HORECA'), findsOneWidget);

    await tester.tap(find.text('Посмотреть утверждённый дизайн'));
    await tester.pumpAndSettle();
    expect(find.text('Выберите рестораны'), findsOneWidget);

    await tester.tap(find.text('Применить (3)'));
    await tester.pumpAndSettle();
    expect(find.text('Главная'), findsWidgets);

    await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('Кассы • список'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bar_chart_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('Отчёты'), findsWidgets);

    await tester.tap(find.byIcon(Icons.smart_toy_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('AI Smart Horeca Assistant'), findsOneWidget);
  });
}
