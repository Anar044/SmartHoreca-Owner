import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_olap_client.dart';
import 'package:smart_horeca_owner/core/owner_state.dart';
import 'package:smart_horeca_owner/screens/owner_olap_reports.dart';

class _Reports extends OwnerOlapClient {
  _Reports() : super('org');

  static const measure = OwnerOlapField(
    name: 'Net',
    title: 'Выручка',
    type: 'MONEY',
    measure: true,
  );
  static const grouping = OwnerOlapField(
    name: 'PayType',
    title: 'Способ оплаты',
    type: 'STRING',
    group: true,
    filter: true,
  );
  OwnerOlapTemplate? saved;
  final runs = <({String from, String to, Set<String> restaurants})>[];

  @override
  Future<List<OwnerOlapTemplate>> list() async => [if (saved != null) saved!];

  @override
  Future<List<OwnerOlapField>> fields() async => [measure, grouping];

  @override
  Future<OwnerOlapTemplate> save(OwnerOlapTemplate template) async {
    saved = OwnerOlapTemplate(
      id: template.id,
      version: 1,
      name: template.name,
      groups: template.groups,
      measures: template.measures,
      filters: template.filters,
    );
    return saved!;
  }

  @override
  Future<OwnerOlapTable> run(OwnerOlapTemplate template,
      Set<String> restaurants, String from, String to) async {
    runs.add((from: from, to: to, restaurants: restaurants));
    return const OwnerOlapTable([
      grouping,
      measure
    ], [
      ['Карта', 42.5]
    ]);
  }
}

void main() {
  testWidgets('creates a sales template and reruns it for a different period',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = OwnerState()
      ..live = true
      ..workspaceId = 'org'
      ..selectedRestaurants = {'Ресторан 1'}
      ..availableRestaurants = ['Ресторан 1']
      ..restaurantIdsByName = {'Ресторан 1': 'r1'};
    addTearDown(state.dispose);
    final client = _Reports();
    await tester.pumpWidget(OwnerScope(
      state: state,
      child: MaterialApp(home: OwnerOlapReportsScreen(client: client)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Создать отчёт'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Продажи по оплатам');
    await tester.tap(find.text('Добавить поле').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Способ оплаты'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить поле').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Выруч');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выручка'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Добавить фильтр'));
    await tester.tap(find.text('Добавить фильтр'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Способ оплаты').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextFormField)),
        'Карта');
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Сохранить отчёт'));
    await tester.tap(find.text('Сохранить отчёт'));
    await tester.pumpAndSettle();
    expect(client.saved!.groups, ['PayType']);
    expect(client.saved!.measures, ['Net']);
    expect(client.saved!.filters.single.values, ['Карта']);
    expect(find.text('Продажи по оплатам'), findsOneWidget);

    await tester.tap(find.text('Показать'));
    await tester.pumpAndSettle();
    expect(find.text('Карта'), findsOneWidget);
    expect(find.text('42.5'), findsOneWidget);
    await tester.tap(find.text('Прошлый месяц'));
    await tester.pumpAndSettle();
    expect(find.text('42.5'), findsNothing);
    await tester.tap(find.text('Показать'));
    await tester.pumpAndSettle();
    expect(client.runs, hasLength(2));
    expect(client.runs.first.from, isNot(client.runs.last.from));
    expect(client.runs.last.restaurants, {'r1'});
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Мои OLAP-отчёты'), findsOneWidget);
    expect(find.text('Продажи по оплатам'), findsOneWidget);
  });
}
