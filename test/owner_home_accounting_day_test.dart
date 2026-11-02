import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_state.dart';
import 'package:smart_horeca_owner/screens/home_screen.dart';

void main() {
  test('Home uses the web accounting-day mode for Today and every period', () {
    expect(OwnerState.dashboardDateMode, 'calendar');
  });

  testWidgets('Home has no outdated open-shift operational-day card',
      (tester) async {
    final owner = OwnerState()
      ..live = true
      ..availableRestaurants = ['RMS 1']
      ..selectedRestaurants = {'RMS 1'}
      ..restaurantIdsByName = {'RMS 1': 'rms1'}
      ..summary = {
        'success': true,
        'mode': 'calendar',
        'metrics': {
          'revenue': 120.0, 'checks': 3,
          'avgCheck': 40.0, 'grossProfit': 50.0,
          'discounts': 2.0, 'surcharges': 0.0, 'costOfGoods': 70.0
        },
        'daily': <Map<String, dynamic>>[]
      };
    addTearDown(owner.dispose);
    await tester.pumpWidget(OwnerScope(
      state: owner,
      child: const MaterialApp(home: Scaffold(body: OwnerHomeScreen())),
    ));
    await tester.pump();
    expect(find.text('Выручка'), findsWidgets);
    expect(find.text('Операционный день по кассовым сменам'), findsNothing);
    expect(find.textContaining('продолжившаяся после полуночи'), findsNothing);
  });
}
