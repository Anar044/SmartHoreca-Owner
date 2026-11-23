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
    final period = find.byKey(const ValueKey('olap-period'));
    await tester.tap(period);
    await tester.pumpAndSettle();
    expect(find.text('Вчера'), findsOneWidget);
    expect(find.text('7 дней'), findsOneWidget);
    expect(find.text('Этот месяц'), findsOneWidget);
    await tester.tap(find.text('Выбрать даты'));
    await tester.pumpAndSettle();
    expect(find.byType(DateRangePickerDialog), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('42.5'), findsOneWidget);
    await tester.tap(period);
    await tester.pumpAndSettle();
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

  testWidgets(
      'folds independent grouping levels and keeps source totals visible',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final state = OwnerState()
      ..live = true
      ..workspaceId = 'org'
      ..selectedRestaurants = {'Ресторан 1'}
      ..availableRestaurants = ['Ресторан 1']
      ..restaurantIdsByName = {'Ресторан 1': 'r1'};
    addTearDown(state.dispose);

    final client = _Reports(
      result: OwnerOlapTable.fromJson({
        'columns': <Map<String, dynamic>>[
          {'name': 'Register', 'title': 'Касса', 'type': 'STRING'},
          {'name': 'Payment', 'title': 'Тип оплаты', 'type': 'STRING'},
          {'name': 'Dish', 'title': 'Блюдо', 'type': 'STRING'},
          {
            'name': 'Total',
            'title': 'Сумма со скидкой',
            'type': 'MONEY',
            'measure': true
          },
          {
            'name': 'Count',
            'title': 'Количество блюд',
            'type': 'INTEGER',
            'measure': true
          },
        ],
        'rows': [
          ['Касса Север', 'Карта', 'Чай', 10.25, 3],
          ['Касса Север', 'Наличные', 'Чай', 20, 5],
          ['Касса Юг', 'Карта', 'Кофе', 41, 7],
        ],
        'groupKeys': [
          ['"north"', '"card"', '"tea"'],
          ['"north"', '"cash"', '"tea"'],
          ['"south"', '"card"', '"coffee"'],
        ],
        'subtotals': [
          {
            'keys': ['"north"'],
            'values': [30.25, 6]
          },
          {
            'keys': ['"south"'],
            'values': [41, 7]
          },
          {
            'keys': ['"north"', '"card"'],
            'values': [10.25, 3]
          },
          {
            'keys': ['"north"', '"cash"'],
            'values': [20, 5]
          },
          {
            'keys': ['"south"', '"card"'],
            'values': [41, 7]
          },
        ],
        'totals': [71.25, 12],
      }),
    )..saved = const OwnerOlapTemplate(
        id: 'test',
        version: 1,
        name: 'Кассы по оплате и блюдам',
        groups: ['Register', 'Payment', 'Dish'],
        measures: ['Total', 'Count'],
        filters: [],
      );
    await tester.pumpWidget(OwnerScope(
      state: state,
      child: MaterialApp(
        darkTheme: ThemeData.dark(useMaterial3: true),
        home: OwnerOlapReportsScreen(client: client),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Кассы по оплате и блюдам'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Показать'));
    await tester.pumpAndSettle();

    expect(find.text('Касса → Тип оплаты → Блюдо'), findsOneWidget);
    expect(find.text('Касса Север').hitTestable(), findsOneWidget);
    expect(find.text('Касса Юг').hitTestable(), findsOneWidget);
    expect(find.text('30.25'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('Карта'), findsNothing);
    expect(find.text('Итого').hitTestable(), findsOneWidget);
    expect(find.text('71.25').hitTestable(), findsOneWidget);
    expect(find.text('12').hitTestable(), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);

    await tester.tap(find.text('Касса Север'));
    await tester.pumpAndSettle();
    expect(find.text('Карта').hitTestable(), findsOneWidget);
    expect(find.text('Наличные').hitTestable(), findsOneWidget);
    expect(find.text('Чай'), findsNothing);
    await tester.tap(find.text('Карта'));
    await tester.pumpAndSettle();
    expect(find.text('Чай').hitTestable(), findsOneWidget);
    expect(find.text('Кофе'), findsNothing);
    await tester.tap(find.text('Касса Север'));
    await tester.pumpAndSettle();
    expect(find.text('Чай'), findsNothing);
    expect(find.text('12').hitTestable(), findsOneWidget);

    await tester.tap(find.text('Развернуть всё'));
    await tester.pumpAndSettle();
    expect(find.text('Чай'), findsNWidgets(2));
    final scrollable = find.byType(Scrollable);
    expect(scrollable, findsOneWidget);
    await tester.scrollUntilVisible(find.text('Кофе'), 180,
        scrollable: scrollable);
    expect(find.text('Кофе').hitTestable(), findsOneWidget);
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Свернуть всё'));
    await tester.pumpAndSettle();
    expect(find.text('Кофе'), findsNothing);
    await tester.tap(find.text('Развернуть всё'));
    await tester.pumpAndSettle();
    expect(client.runs, hasLength(1));

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    await tester.binding.setSurfaceSize(const Size(820, 390));
    await tester.pumpAndSettle();
    expect(scrollable, findsOneWidget);
    final position = tester.state<ScrollableState>(scrollable).position;
    for (var attempt = 0; attempt < 5; attempt++) {
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
    }
    expect(find.text('Итого').hitTestable(), findsOneWidget);
    expect(find.text('71.25').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
