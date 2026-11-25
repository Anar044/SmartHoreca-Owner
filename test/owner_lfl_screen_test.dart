import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_state.dart';
import 'package:smart_horeca_owner/screens/owner_lfl_screen.dart';

void main() {
  testWidgets(
      'LFL loads two periods for selected restaurants and switches metrics',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final owner = OwnerState()
      ..live = true
      ..workspaceId = 'ws'
      ..period = 'Период'
      ..customFrom = DateTime(2024, 2, 29)
      ..customTo = DateTime(2024, 2, 29)
      ..availableRestaurants = ['Центр', 'Новая точка']
      ..selectedRestaurants = {'Центр', 'Новая точка'}
      ..restaurantIdsByName = {'Центр': 'dept1', 'Новая точка': 'dept2'};
    addTearDown(owner.dispose);
    final money = {
      'current': 120,
      'comparison': 100,
      'change': 20,
      'percent': 20
    };
    final checks = {
      'current': 8,
      'comparison': 10,
      'change': -2,
      'percent': -20
    };
    Map<String, dynamic> metric(Map<String, int> total) => {
          'total': total,
          'comparableCount': 1,
          'rows': [
            {'name': 'Центр', ...total},
            {'name': 'Новая точка', 'current': 2, 'comparison': null},
          ],
        };
    var calls = 0;
    await tester.pumpWidget(OwnerScope(
      state: owner,
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: OwnerLflScreen(load: (workspace, ids, query) async {
          calls++;
          expect(workspace, 'ws');
          expect(ids, {'dept1', 'dept2'});
          expect(query, {
            'from': '2024-02-29',
            'to': '2024-02-29',
            'compareFrom': '2023-02-28',
            'compareTo': '2023-02-28',
          });
          return {
            'currency': 'AZN',
            'metrics': {'revenue': metric(money), 'checks': metric(checks)},
          };
        }),
      ),
    ));
    expect(find.text('29.02.2024'), findsOneWidget);
    expect(find.text('28.02.2023'), findsOneWidget);
    expect(calls, 0);
    await tester.tap(find.text('Сравнить'));
    await tester.pumpAndSettle();
    expect(find.text('Итого по сопоставимым точкам'), findsOneWidget);
    expect(find.text('+20.00 AZN (+20.0%)'), findsWidgets);
    await tester.tap(find.text('Чеки'));
    await tester.pumpAndSettle();
    expect(find.text('-2 (-20.0%)'), findsWidgets);
    expect(calls, 1);
    await tester.scrollUntilVisible(find.text('Вне сравнения'), 250);
    expect(find.text('Вне сравнения'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
