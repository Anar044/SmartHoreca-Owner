import 'package:flutter/material.dart';
import '../ui/owner_text.dart';
import '../core/owner_theme.dart';
import '../core/owner_state.dart';
import '../core/owner_demo_data.dart';
import '../core/owner_l10n.dart';
import '../ui/owner_components.dart';
import 'owner_live_reports.dart';

class OwnerReportsScreen extends StatelessWidget {
  const OwnerReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLive = OwnerScope.of(context).live;
    const reports = [
      ('Продажи и выручка', Icons.bar_chart),
      ('Блюда и категории', Icons.restaurant_menu),
      ('Скидки и наценки', Icons.percent),
      ('Себестоимость', Icons.calculate_outlined),
      ('P&L', Icons.account_balance_wallet_outlined),
      ('OLAP — продажи по кассам', Icons.account_tree_outlined),
      ('Остатки на складах', Icons.warehouse_outlined),
      ('Движение товаров', Icons.swap_horiz),
    ];
    return OwnerScreenFrame(children: [
      const OwnerHeading('Отчёты', caption: 'Аналитика и остатки на складах'),
      const SizedBox(height: 14),
      const OwnerRestaurantPicker(),
      const SizedBox(height: 12),
      const OwnerPeriodPicker(),
      const SizedBox(height: 15),
      for (final report in reports) ...[
        OwnerCard(
          onTap: () {
            if (isLive) {
              final kind = switch (report.$1) {
                'Продажи и выручка' => 'sales',
                'Блюда и категории' => 'categories',
                'Скидки и наценки' => 'discounts',
                'Себестоимость' => 'foodCost',
                'P&L' => 'pnl',
                'OLAP — продажи по кассам' => 'cash',
                'Остатки на складах' => 'inventory',
                'Движение товаров' => 'movements',
                _ => 'sales',
              };
              Navigator.push(context, MaterialPageRoute<void>(
                builder: (_) => OwnerLiveReportScreen(
                  title: report.$1, kind: kind,
                ),
              ));
              return;
            }
            Navigator.push(context, MaterialPageRoute<void>(
            builder: (_) => report.$1 == 'Остатки на складах'
                ? const OwnerInventoryScreen()
                : (report.$1 == 'Продажи и выручка' ||
                        report.$1 == 'OLAP — продажи по кассам')
                    ? OwnerReportDetail(title: report.$1)
                    : OwnerReportPendingScreen(title: report.$1),
          ));
          },
          child: Row(children: [
            Container(
              decoration: BoxDecoration(
                color: OwnerPalette.raised(context),
                borderRadius: BorderRadius.circular(12),
              ),
              width: 42,
              height: 42,
              child: Icon(report.$2, color: OwnerPalette.accent(context)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(OwnerL10n.tr(OwnerScope.of(context).language, report.$1), style: const TextStyle(fontWeight: FontWeight.w600))),
            const Icon(Icons.chevron_right),
          ]),
        ),
        const SizedBox(height: 9),
      ],
    ]);
  }
}

/// Explicitly unavailable report type: never reuse sales numbers as
/// invented P&L, food cost, discount or warehouse movement figures.
class OwnerReportPendingScreen extends StatelessWidget {
  final String title;
  const OwnerReportPendingScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final language = OwnerScope.of(context).language;
    return Scaffold(
      appBar: AppBar(
        title: Text(OwnerL10n.tr(language, title),
          style: const TextStyle(fontSize: 17)),
      ),
      body: OwnerScreenFrame(children: [
        const OwnerRestaurantPicker(),
        const SizedBox(height: 12),
        const OwnerPeriodPicker(),
        const SizedBox(height: 16),
        OwnerCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.query_stats_outlined,
              color: OwnerPalette.accent(context), size: 32),
            const SizedBox(height: 12),
            const OwnerHeading('Отчёт пока не подключён'),
            const SizedBox(height: 10),
            const OwnerText(
              'Для этого раздела ещё нет отдельного мобильного API. Вместо чужих показателей здесь будут настоящие данные после подключения.'),
          ],
        )),
      ]),
    );
  }
}

class OwnerReportDetail extends StatefulWidget {
  final String title;
  const OwnerReportDetail({super.key, required this.title});

  @override
  State<OwnerReportDetail> createState() => _OwnerReportDetailState();
}

class _OwnerReportDetailState extends State<OwnerReportDetail> {
  bool table = false;
  final Set<String> expanded = {'Касса 1'};

  @override
  Widget build(BuildContext context) {
    final olap = widget.title.contains('OLAP');
    final state = OwnerScope.of(context);
    final demo = OwnerDemoData.snapshot(state.selectedRestaurants, state.period);
    final groupNames = [
      for (final name in state.selectedRestaurants)
        if (OwnerDemoData.restaurants.any((r) => r.name == name)) name,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(OwnerL10n.tr(state.language, widget.title), style: const TextStyle(fontSize: 17)),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            tooltip: OwnerL10n.tr(state.language, 'Фильтры'),
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const OwnerReportFilters())),
          ),
        ],
      ),
      body: OwnerScreenFrame(children: [
        const OwnerRestaurantPicker(),
        const SizedBox(height: 13),
        const OwnerPeriodPicker(),
        const SizedBox(height: 15),
        Row(children: [
          Expanded(child: OwnerMetric('Выручка',
            OwnerDemoData.money(demo.revenue), trend: '↑ 12,5%')),
          const SizedBox(width: 10),
          Expanded(child: OwnerMetric('Чеки',
            demo.checks.toString(), trend: '↑ 8,3%')),
        ]),
        const SizedBox(height: 15),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: OwnerText('График'), icon: Icon(Icons.bar_chart)),
            ButtonSegment(value: true, label: OwnerText('Таблица'), icon: Icon(Icons.table_chart_outlined)),
          ],
          selected: {table},
          onSelectionChanged: (v) => setState(() => table = v.first),
        ),
        const SizedBox(height: 12),
        if (!table) ...[
          OwnerCard(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OwnerHeading(demo.chartTitle),
              const SizedBox(height: 14),
              OwnerBars(values: demo.chartValues, labels: demo.chartLabels),
              const SizedBox(height: 7),
              Text('${OwnerL10n.tr(state.language, 'Демонстрация')} • ${OwnerL10n.tr(state.language, state.period)}',
                style: TextStyle(color: OwnerPalette.muted(context),
                  fontSize: 11)),
            ],
          )),
        ] else if (olap) ...[
          OwnerCard(child: Column(
            children: [
              const OwnerHeading('Касса → Блюдо'),
              const SizedBox(height: 12),
              for (var idx = 0; idx < groupNames.length; idx++) ...[
                Builder(builder: (context) {
                  final name = groupNames[idx];
                  final restaurant = OwnerDemoData.restaurants.firstWhere(
                    (r) => r.name == name);
                  final total = OwnerDemoData.restaurantRevenue(
                    restaurant, state.period);
                  final items = [
                    (total * 0.50).round(),
                    (total * 0.30).round(),
                    total - (total * 0.50).round() -
                        (total * 0.30).round(),
                  ];
                  final groupName = 'Касса ${idx + 1} — $name';
                  return Column(children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(OwnerL10n.previewLabel(state.language, groupName)),
                      trailing: Text(OwnerDemoData.money(total)),
                      leading: Icon(expanded.contains(groupName)
                          ? Icons.expand_more : Icons.chevron_right),
                      onTap: () => setState(() {
                        if (!expanded.add(groupName)) {
                          expanded.remove(groupName);
                        }
                      }),
                    ),
                    if (expanded.contains(groupName))
                      for (var i = 0; i < items.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(left: 22),
                          child: ListTile(
                            dense: true,
                            title: Text(OwnerL10n.tr(state.language, OwnerDemoData.dishNames[i])),
                            trailing: Text(OwnerDemoData.money(items[i])),
                          ),
                        ),
                    const Divider(height: 1),
                  ]);
                }),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const OwnerText('Всего',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text(OwnerDemoData.money(demo.revenue),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          )),
        ] else ...[
          OwnerCard(child: Column(
            children: [
              for (var i = 0; i < demo.chartValues.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(demo.chartLabels[i]),
                  trailing: Text(OwnerDemoData.money(
                    demo.chartValues[i], decimals: true)),
                ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const OwnerText('Всего',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text(OwnerDemoData.money(demo.revenue),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          )),
        ],
        const SizedBox(height: 13),
        OwnerText('Экспорт и реальные OLAP поля будут подключены после серверного read-only API.',
          style: TextStyle(color: OwnerPalette.muted(context), fontSize: 12)),
      ]),
    );
  }
}

class OwnerReportFilters extends StatelessWidget {
  const OwnerReportFilters({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const OwnerText('Фильтры отчёта')),
      body: OwnerScreenFrame(children: [
        const OwnerHeading('Период и рестораны'),
        const SizedBox(height: 14),
        const OwnerPeriodPicker(),
        const SizedBox(height: 14),
        const OwnerRestaurantPicker(),
        const SizedBox(height: 14),
        const OwnerCard(child: Column(children: [
          ListTile(title: OwnerText('Категории'), trailing: OwnerText('Все категории')),
          Divider(),
          ListTile(title: OwnerText('Блюда'), trailing: OwnerText('Все блюда')),
        ])),
        const SizedBox(height: 20),
        FilledButton(onPressed: () => Navigator.pop(context), child: const OwnerText('Применить')),
      ]),
    );
  }
}

class OwnerInventoryScreen extends StatefulWidget {
  const OwnerInventoryScreen({super.key});

  @override
  State<OwnerInventoryScreen> createState() => _OwnerInventoryScreenState();
}

class _OwnerInventoryScreenState extends State<OwnerInventoryScreen> {
  String warehouse = 'Все склады';
  String filter = 'Все';
  String search = '';

  @override
  Widget build(BuildContext context) {
    const products = [
      ('Помидоры', '12,5 кг', '225 AZN', 'В наличии'),
      ('Огурцы', '8,0 кг', '76 AZN', 'В наличии'),
      ('Картофель', '20,0 кг', '70 AZN', 'Ниже min'),
      ('Сыр Моцарелла', '-1,0 кг', '-22 AZN', 'Отрицательные'),
    ];
    final shown = products.where((p) {
      final matchesSearch = p.$1.toLowerCase().contains(search.toLowerCase());
      final status = filter == 'Все' || filter == p.$4;
      return matchesSearch && status;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const OwnerText('Остатки на складах')),
      body: OwnerScreenFrame(children: [
        const OwnerRestaurantPicker(),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: warehouse,
          decoration: InputDecoration(labelText: OwnerL10n.tr(
            OwnerScope.of(context).language, 'Склад')),
          items: ['Все склады', 'Основной склад', 'Бар'].map((e) => DropdownMenuItem(value: e, child: Text(OwnerL10n.tr(OwnerScope.of(context).language, e)))).toList(),
          onChanged: (v) => setState(() => warehouse = v ?? 'Все склады'),
        ),
        const SizedBox(height: 13),
        const Row(children: [
          Expanded(child: OwnerMetric('Стоимость запасов', '180 000 AZN')),
          SizedBox(width: 10),
          Expanded(child: OwnerMetric('Позиций', '157')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OwnerMetric('Отрицательные', '4',
            trend: OwnerL10n.tr(OwnerScope.of(context).language,
              'Требуют проверки'), trendColor: OwnerPalette.error)),
          const SizedBox(width: 10),
          Expanded(child: OwnerMetric('Ниже минимума', '9',
            trend: OwnerL10n.tr(OwnerScope.of(context).language,
              'Порог настроен'), trendColor: OwnerPalette.warning)),
        ]),
        const SizedBox(height: 13),
        TextField(
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search),
            hintText: OwnerL10n.tr(OwnerScope.of(context).language,
              'Поиск товара, кода...')),
          onChanged: (v) => setState(() => search = v),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
          children: ['Все', 'В наличии', 'Ниже min', 'Отрицательные'].map((f) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              showCheckmark: false,
              selected: filter == f,
              label: Text(OwnerL10n.tr(OwnerScope.of(context).language, f)),
              onSelected: (_) => setState(() => filter = f),
            ),
          )).toList(),
        )),
        const SizedBox(height: 12),
        for (final p in shown) ...[
          OwnerCard(onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => OwnerProductDetail(name: p.$1))),
            child: Row(children: [
              Icon(Icons.inventory_2_outlined, color: OwnerPalette.accent(context)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(OwnerL10n.tr(OwnerScope.of(context).language, p.$1), style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(OwnerL10n.tr(OwnerScope.of(context).language, p.$4), style: TextStyle(color: p.$4 == 'В наличии' ? OwnerPalette.green : OwnerPalette.error, fontSize: 11)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(OwnerL10n.previewQuantity(
                  OwnerScope.of(context).language, p.$2),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(p.$3, style: TextStyle(color: OwnerPalette.muted(context), fontSize: 11)),
              ]),
            ]),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 6),
        const OwnerDemoNotice(),
      ]),
    );
  }
}

class OwnerProductDetail extends StatelessWidget {
  final String name;
  const OwnerProductDetail({super.key, required this.name});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(OwnerL10n.tr(OwnerScope.of(context).language, name))),
    body: OwnerScreenFrame(children: [
      OwnerHeading(OwnerL10n.tr(OwnerScope.of(context).language, name),
        caption: 'Овощи / Складской товар'),
      const SizedBox(height: 13),
      Row(children: [
        Expanded(child: OwnerMetric('Остаток', OwnerL10n.previewQuantity(
          OwnerScope.of(context).language, '12,5 кг'))),
        const SizedBox(width: 10),
        const Expanded(child: OwnerMetric('Стоимость', '225 AZN')),
      ]),
      const SizedBox(height: 10),
      OwnerCard(child: Column(children: [
        const ListTile(title: OwnerText('Себестоимость / кг'), trailing: Text('18 AZN')),
        const Divider(height: 1),
        ListTile(title: const OwnerText('Основной склад'),
          trailing: Text(OwnerL10n.previewQuantity(
            OwnerScope.of(context).language, '8,0 кг'))),
        const Divider(height: 1),
        ListTile(title: const OwnerText('Бар'),
          trailing: Text(OwnerL10n.previewQuantity(
            OwnerScope.of(context).language, '4,5 кг'))),
        const Divider(height: 1),
        const ListTile(title: OwnerText('Срез на дату'), trailing: Text('13.10.2026')),
      ])),
      const SizedBox(height: 14),
      const OwnerDemoNotice(),
    ]),
  );
}
