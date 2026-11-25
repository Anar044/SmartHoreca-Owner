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
  testWidgets('date segments select on a tap and accept historical periods',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final owner = _PeriodOwner();
    addTearDown(owner.dispose);
    await tester.pumpWidget(OwnerScope(
      state: owner,
      child: MaterialApp(
        theme: ThemeData.dark().copyWith(platform: TargetPlatform.iOS),
        home: const Scaffold(body: OwnerPeriodPicker()),
      ),
    ));
    await tester.tap(find.text('Выбрать даты'));
    await tester.pumpAndSettle();

    final dialog = find.byType(OwnerDateRangeDialog);
    final fields =
        find.descendant(of: dialog, matching: find.byType(TextField));
    expect(fields, findsNWidgets(6));
    final today = DateUtils.dateOnly(DateTime.now());
    final parts = ownerDisplayDate(today).split('.');
    final input = tester.widgetList<TextField>(fields).toList();
    expect(input.map((field) => field.controller!.text), [...parts, ...parts]);
    expect(input.every((field) => field.keyboardType == TextInputType.number),
        isTrue);
    expect(find.text('Дата начала'), findsOneWidget);
    expect(find.text('Дата окончания'), findsOneWidget);

    final apply = find.descendant(of: dialog, matching: find.text('Применить'));
    Future<void> replaceSegment(int i, String value) async {
      await tester.tap(fields.at(i));
      await tester.pump();
      final controller = input[i].controller!;
      expect(
          controller.selection,
          TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          ));
      expect(tester.testTextInput.isVisible, isTrue);
      tester.testTextInput.updateEditingValue(TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      ));
      await tester.pump();
    }

    await replaceSegment(0, '31');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await replaceSegment(1, '02');
    await replaceSegment(2, '2005');
    await tester.longPress(fields.at(2));
    await tester.pumpAndSettle();
    expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);

    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(dialog, findsOneWidget);
    expect(find.text('Неверная дата'), findsOneWidget);
    expect(owner.customFrom, isNull);

    await replaceSegment(0, '03');
    await replaceSegment(0, '03');
    await replaceSegment(1, '12');
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(owner.customFrom, DateTime(2005, 12, 3));
    expect(owner.customTo, today);
    expect(
        find.text('03.12.2005 – ${ownerDisplayDate(today)}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar opens on the entered dates and can return to editing',
      (tester) async {
    final owner = _PeriodOwner()
      ..period = 'Период'
      ..customFrom = DateTime(2005, 12, 3)
      ..customTo = DateTime(2005, 12, 15);
    addTearDown(owner.dispose);
    await tester.pumpWidget(OwnerScope(
      state: owner,
      child: const MaterialApp(home: Scaffold(body: OwnerPeriodPicker())),
    ));
    await tester.tap(find.text('03.12.2005 – 15.12.2005'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '04');
    await tester.tap(find.byTooltip('Календарь'));
    await tester.pumpAndSettle();
    final calendar = find.byType(DateRangePickerDialog);
    expect(calendar, findsOneWidget);
    final picker = tester.widget<DateRangePickerDialog>(calendar);
    expect(picker.initialDateRange?.start, DateTime(2005, 12, 4));
    expect(picker.initialEntryMode, DatePickerEntryMode.calendarOnly);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(OwnerDateRangeDialog), findsOneWidget);
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '04');
    expect(tester.takeException(), isNull);
  });
}
