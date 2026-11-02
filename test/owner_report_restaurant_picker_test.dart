import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_state.dart';
import 'package:smart_horeca_owner/ui/owner_components.dart';

void main() {
  testWidgets('restaurant picker applies selection in a pushed P&L route',
      (tester) async {
    final owner = OwnerState()
      ..stage = OwnerStage.shell
      ..availableRestaurants = ['Alpha', 'Beta']
      ..selectedRestaurants = {'Alpha'};
    addTearDown(owner.dispose);

    await tester.pumpWidget(OwnerScope(
      state: owner,
      child: MaterialApp(home: Scaffold(
        body: Builder(builder: (context) => Center(
          child: FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('P&L')),
                body: const OwnerRestaurantPicker(),
              )),
            ),
            child: const Text('Open P&L'),
          ),
        )),
      )),
    ));

    await tester.tap(find.text('Open P&L'));
    await tester.pumpAndSettle();
    expect(find.text('P&L'), findsOneWidget);

    await tester.tap(find.byType(OwnerRestaurantPicker));
    await tester.pumpAndSettle();
    expect(find.text('Выбор ресторанов'), findsOneWidget);
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    // Dismissing must not persist any partial checkbox changes.
    expect(owner.selectedRestaurants, {'Alpha'});
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(owner.selectedRestaurants, {'Alpha'});
    expect(find.text('P&L'), findsOneWidget);

    await tester.tap(find.byType(OwnerRestaurantPicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Применить (2)'));
    await tester.pumpAndSettle();

    expect(owner.selectedRestaurants, {'Alpha', 'Beta'});
    expect(owner.stage, OwnerStage.shell);
    expect(find.text('P&L'), findsOneWidget);
    expect(find.text('Все рестораны (2)'), findsOneWidget);
  });

  test('scoped selection rejects empty and unauthorized departments', () {
    final owner = OwnerState()
      ..availableRestaurants = ['Alpha', 'Beta']
      ..selectedRestaurants = {'Alpha'};
    addTearDown(owner.dispose);

    owner.applyRestaurantSelection({});
    expect(owner.selectedRestaurants, {'Alpha'});
    owner.applyRestaurantSelection({'Beta', 'Other tenant'});
    expect(owner.selectedRestaurants, {'Beta'});
  });
}
