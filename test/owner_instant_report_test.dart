import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_state.dart';
import 'package:smart_horeca_owner/screens/owner_live_reports.dart';

void main() {
  test('report dates roll over at midnight and keys bind exact scope and mode', () {
    final state = OwnerState()..period = 'Сегодня'
      ..workspaceId = 'one'..restaurantIdsByName = {'A': 'a', 'B': 'b'}
      ..selectedRestaurants = {'A'};
    addTearDown(state.dispose);
    expect(state.reportDates(now: DateTime(2026, 11, 12))['to'], '2026-11-12');
    expect(state.reportDates(now: DateTime(2026, 11, 13))['to'], '2026-11-13');
    final key = state.reportCacheKey('foodCost');
    state.selectedRestaurants = {'B'};
    expect(state.reportCacheKey('foodCost'), isNot(key));
    state.selectedRestaurants = {'A'};
    state.workspaceId = 'two';
    expect(state.reportCacheKey('foodCost'), isNot(key));
  });

  testWidgets('report renders cached values immediately and retains them after failed refresh', (tester) async {
    final state = OwnerState()..live = true..workspaceId = 'one'
      ..restaurantIdsByName = {'A': 'a'}..availableRestaurants = ['A']
      ..selectedRestaurants = {'A'};
    addTearDown(state.dispose);
    state.rememberResponse(state.reportCacheKey('foodCost'), {
      'success': true, 'kind': 'foodCost', 'updatedAt': DateTime.now().toIso8601String(),
      'totalValue': 123.0, 'rows': [{'label': 'Soup', 'value': 123.0}],
    });
    await tester.pumpWidget(OwnerScope(state: state, child: const MaterialApp(
      home: OwnerLiveReportScreen(title: 'Себестоимость', kind: 'foodCost'))));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('123.00'), findsWidgets);
    await tester.tap(find.byTooltip('Обновить'));
    await tester.pumpAndSettle(); // Unconfigured network fails; snapshot must remain.
    expect(find.textContaining('123.00'), findsWidgets);
    expect(find.textContaining('Показаны сохранённые результаты'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    state.discardUnauthorizedSnapshots();
    await tester.pumpAndSettle();
    expect(find.textContaining('123.00'), findsNothing);
  });
}
