import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_olap_client.dart';
import 'package:smart_horeca_owner/core/owner_state.dart';
import 'package:smart_horeca_owner/screens/owner_olap_reports.dart';

class _Reports extends OwnerOlapClient {
  _Reports({this.result}) : super('org');
  final OwnerOlapTable? result;

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
    valueChoices: true,
  );
  OwnerOlapTemplate? saved;
  final runs = <({String from, String to, Set<String> restaurants})>[];

  @override
  Future<List<OwnerOlapTemplate>> list() async => [if (saved != null) saved!];

  @override
  Future<List<OwnerOlapField>> fields() async => [measure, grouping];

  @override
  Future<List<OwnerOlapChoice>> filterValues(
      String field, Set<String> restaurants, String from, String to) async {
    expect(field, grouping.name);
    expect(restaurants, {'r1'});
    expect(from.compareTo(to), lessThan(0));
    return const [
      OwnerOlapChoice('Карта', 'Карта'),
      OwnerOlapChoice('Наличные', 'Наличные'),
    ];
  }

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
    return result ??
        const OwnerOlapTable([
          grouping,
          measure
        ], [
          ['Карта', 42.5]
        ]);
  }
}

void main() {
  testWidgets('shows all rows of a short two-column report without scrolling',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(384, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = OwnerState()
      ..live = true
      ..workspaceId = 'org'
      ..selectedRestaurants = {'Ресторан 1', 'Ресторан 2'}
      ..availableRestaurants = ['Ресторан 1', 'Ресторан 2']
      ..restaurantIdsByName = {'Ресторан 1': 'r1', 'Ресторан 2': 'r2'};
    addTearDown(state.dispose);
    const longRegister = 'Третья касса торгового центра, внутренний номер 120';
    final client = _Reports(
        result: const OwnerOlapTable([
      OwnerOlapField(
          name: 'Department.Id',
          title: 'Ресторан',
          type: 'ID',
          restaurant: true),
      OwnerOlapField(name: 'CashRegisterName', title: 'Касса', type: 'STRING'),
      OwnerOlapField(
          name: 'DishDiscountSumInt',
          title: 'Сумма со скидкой',
          type: 'MONEY',
          measure: true),
    ], [
      [
        'Ресторан 1',
        'Первая касса торгового центра, внутренний номер 101',
        1851.1
      ],
      [
        'Ресторан 2',
        'Вторая касса торгового центра, внутренний номер 107',
        2997.4
      ],
      ['Ресторан 2', longRegister, 5985.2],
    ]))
      ..saved = const OwnerOlapTemplate(
        id: 'test',
        version: 1,
        name: 'Тест касса',
        groups: ['CashRegisterName'],
        measures: ['DishDiscountSumInt'],
        filters: [],
      );
    await tester.pumpWidget(OwnerScope(
        state: state,
        child: MaterialApp(home: OwnerOlapReportsScreen(client: client))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Тест касса'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Показать'));
    await tester.pumpAndSettle();
    expect(find.text('Ресторан'), findsNothing);
    expect(find.text('Касса'), findsOneWidget);
    expect(find.text('Сумма со скидкой'), findsOneWidget);
    expect(find.text(longRegister).hitTestable(), findsOneWidget);
    expect(find.text('5985.2').hitTestable(), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position
            .maxScrollExtent,
        0);
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(220, 560));
    await tester.pumpAndSettle();
    final horizontal = find.byType(SingleChildScrollView);
    expect(horizontal, findsOneWidget);
    final scroll = tester.state<ScrollableState>(
      find.descendant(of: horizontal, matching: find.byType(Scrollable)).first,
    );
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

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
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    await tester.tap(find.text('Исключить'));
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Карта'));
    await tester.enterText(find.byType(TextField).last, 'Налич');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(CheckboxListTile, 'Карта'), findsNothing);
    expect(find.widgetWithText(CheckboxListTile, 'Наличные'), findsOneWidget);
    expect(find.text('Выбрано 1'), findsOneWidget);
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Сохранить отчёт'));
    await tester.tap(find.text('Сохранить отчёт'));
    await tester.pumpAndSettle();
    expect(client.saved!.groups, ['PayType']);
    expect(client.saved!.measures, ['Net']);
    expect(client.saved!.filters.single.values, ['Карта']);
    expect(client.saved!.filters.single.exclude, isTrue);
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
    await tester.tap(find.byTooltip('Действия с отчётом'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Изменить'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Исключить · Карта'));
    await tester.tap(find.text('Исключить · Карта'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<CheckboxListTile>(
                find.widgetWithText(CheckboxListTile, 'Карта'))
            .value,
        isTrue);
  });
}
