import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/main.dart';

void main() {
  testWidgets('approved flow opens preview and keeps four bottom tabs', (tester) async {
    await tester.pumpWidget(const SmartHorecaOwnerApp());
    // Allow the new branded splash to finish restoring local preferences.
    await tester.pumpAndSettle();
    expect(find.text('SMART HORECA'), findsOneWidget);

    // The larger approved logo extends the sign-in page on short devices.
    await tester.ensureVisible(find.text('Посмотреть утверждённый дизайн'));
    await tester.pumpAndSettle();
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
