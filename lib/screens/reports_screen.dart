import 'package:flutter/material.dart';
import '../core/owner_theme.dart';
import '../ui/owner_components.dart';

class OwnerReportsScreen extends StatelessWidget {
  const OwnerReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(
            builder: (_) => report.$1 == 'Остатки на складах'
                ? const OwnerInventoryScreen()
                : OwnerReportDetail(title: report.$1),
          )),
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
            Expanded(child: Text(report.$1, style: const TextStyle(fontWeight: FontWeight.w600))),
            const Icon(Icons.chevron_right),
          ]),
        ),
        const SizedBox(height: 9),
      ],
    ]);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 17)),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            tooltip: 'Фильтры',
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const OwnerReportFilters())),
          ),
        ],
      ),
      body: OwnerScreenFrame(children: [
        const OwnerRestaurantPicker(),
        const SizedBox(height: 13),
        const OwnerPeriodPicker(),
        const SizedBox(height: 15),
        const Row(children: [
          Expanded(child: OwnerMetric('Сумма', '124 520 AZN', trend: '↑ 12,5%')),
          SizedBox(width: 10),
          Expanded(child: OwnerMetric('Чеки', '1 482', trend: '↑ 8,3%')),
        ]),
        const SizedBox(height: 15),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('График'), icon: Icon(Icons.bar_chart)),
            ButtonSegment(value: true, label: Text('Таблица'), icon: Icon(Icons.table_chart_outlined)),
          ],
          selected: {table},
          onSelectionChanged: (v) => setState(() => table = v.first),
        ),
        const SizedBox(height: 12),
        if (!table) ...[
          const OwnerCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            OwnerHeading('Выручка по периодам'),
            SizedBox(height: 14),
            OwnerBars(values: [14, 18, 23, 16, 26, 28, 24], labels: ['01', '02', '03', '04', '05', '06', '07']),
          ])),
        ] else if (olap) ...[
          OwnerCard(child: Column(children: [
            const OwnerHeading('Касса → Блюдо'),
            const SizedBox(height: 12),
            for (final cash in const [
              ('Касса 1', '42 150 AZN'),
              ('Касса 2', '38 320 AZN'),
              ('Касса 3', '28 840 AZN'),
            ]) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(cash.$1),
                trailing: Text(cash.$2),
                leading: Icon(expanded.contains(cash.$1) ? Icons.expand_more : Icons.chevron_right),
                onTap: () => setState(() {
                  if (!expanded.add(cash.$1)) expanded.remove(cash.$1);
                }),
              ),
              if (expanded.contains(cash.$1))
                for (final dish in const [
                  ('Люля-кебаб', '2 450 AZN'),
                  ('Плов', '1 980 AZN'),
                  ('Куриный суп', '1 560 AZN'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(left: 22),
                    child: ListTile(dense: true, title: Text(dish.$1), trailing: Text(dish.$2)),
                  ),
              const Divider(height: 1),
            ],
          ])),
        ] else ...[
          OwnerCard(child: Column(children: [
            for (final item in const [
              ('01 октября', '16 420 AZN'),
              ('02 октября', '17 850 AZN'),
              ('03 октября', '18 230 AZN'),
              ('04 октября', '15 940 AZN'),
            ])
              ListTile(contentPadding: EdgeInsets.zero, title: Text(item.$1), trailing: Text(item.$2)),
          ])),
        ],
        const SizedBox(height: 13),
        Text('Экспорт и реальные OLAP поля будут подключены после серверного read-only API.',
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
      appBar: AppBar(title: const Text('Фильтры отчёта')),
      body: OwnerScreenFrame(children: [
        const OwnerHeading('Период и рестораны'),
        const SizedBox(height: 14),
        const OwnerPeriodPicker(),
        const SizedBox(height: 14),
        const OwnerRestaurantPicker(),
        const SizedBox(height: 14),
        const OwnerCard(child: Column(children: [
          ListTile(title: Text('Категории'), trailing: Text('Все категории')),
          Divider(),
          ListTile(title: Text('Блюда'), trailing: Text('Все блюда')),
        ])),
        const SizedBox(height: 20),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Применить')),
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
      appBar: AppBar(title: const Text('Остатки на складах')),
      body: OwnerScreenFrame(children: [
        const OwnerRestaurantPicker(),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: warehouse,
          decoration: const InputDecoration(labelText: 'Склад'),
          items: ['Все склады', 'Основной склад', 'Бар'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => warehouse = v ?? 'Все склады'),
        ),
        const SizedBox(height: 13),
        const Row(children: [
          Expanded(child: OwnerMetric('Стоимость запасов', '180 000 AZN')),
          SizedBox(width: 10),
          Expanded(child: OwnerMetric('Позиций', '157')),
        ]),
        const SizedBox(height: 10),
        const Row(children: [
          Expanded(child: OwnerMetric('Отрицательные', '4', trend: 'Требуют проверки', trendColor: OwnerPalette.error)),
          SizedBox(width: 10),
          Expanded(child: OwnerMetric('Ниже минимума', '9', trend: 'Порог настроен', trendColor: OwnerPalette.warning)),
        ]),
        const SizedBox(height: 13),
        TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Поиск товара, кода...'),
          onChanged: (v) => setState(() => search = v),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
          children: ['Все', 'В наличии', 'Ниже min', 'Отрицательные'].map((f) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              showCheckmark: false,
              selected: filter == f,
              label: Text(f),
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
                Text(p.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(p.$4, style: TextStyle(color: p.$4 == 'В наличии' ? OwnerPalette.green : OwnerPalette.error, fontSize: 11)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(p.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
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
    appBar: AppBar(title: Text(name)),
    body: OwnerScreenFrame(children: [
      OwnerHeading(name, caption: 'Овощи / Складской товар'),
      const SizedBox(height: 13),
      const Row(children: [
        Expanded(child: OwnerMetric('Остаток', '12,5 кг')),
        SizedBox(width: 10),
        Expanded(child: OwnerMetric('Стоимость', '225 AZN')),
      ]),
      const SizedBox(height: 10),
      const OwnerCard(child: Column(children: [
        ListTile(title: Text('Себестоимость / кг'), trailing: Text('18 AZN')),
        Divider(height: 1),
        ListTile(title: Text('Основной склад'), trailing: Text('8,0 кг')),
        Divider(height: 1),
        ListTile(title: Text('Бар'), trailing: Text('4,5 кг')),
        Divider(height: 1),
        ListTile(title: Text('Срез на дату'), trailing: Text('13.10.2026')),
      ])),
      const SizedBox(height: 14),
      const OwnerDemoNotice(),
    ]),
  );
}
