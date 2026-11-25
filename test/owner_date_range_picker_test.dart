import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_state.dart';
import 'package:smart_horeca_owner/ui/owner_components.dart';
import 'package:smart_horeca_owner/ui/owner_date_range_picker.dart';

class _PeriodOwner extends OwnerState {
  @override
  void setCustomPeriod(DateTime from, DateTime to) {
    customFrom = from;
    customTo = to;
    period = 'Период';
    notifyListeners();
  }
}

void main() {
  testWidgets('date inputs start at today and accept historical sales periods',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final owner = _PeriodOwner();
    addTearDown(owner.dispose);
    await tester.pumpWidget(OwnerScope(
      state: owner,
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(body: OwnerPeriodPicker()),
      ),
    ));
    await tester.tap(find.text('Выбрать даты'));
    await tester.pumpAndSettle();

    final dialog = find.byType(DateRangePickerDialog);
    final fields =
        find.descendant(of: dialog, matching: find.byType(TextField));
    expect(fields, findsNWidgets(2));
    final today = DateUtils.dateOnly(DateTime.now());
    expect(find.text(ownerDisplayDate(today)), findsNWidgets(2));
    expect(find.text('Дата начала'), findsOneWidget);
    expect(find.text('Дата окончания'), findsOneWidget);

    final apply = find.descendant(of: dialog, matching: find.text('Применить'));
    await tester.enterText(fields.first, '31.02.2005');
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(dialog, findsOneWidget);
    expect(owner.customFrom, isNull);

    await tester.enterText(fields.first, '03.12.2005');
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(owner.customFrom, DateTime(2005, 12, 3));
    expect(owner.customTo, today);
    expect(
        find.text('03.12.2005 – ${ownerDisplayDate(today)}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
