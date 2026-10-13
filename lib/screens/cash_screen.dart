import 'package:flutter/material.dart';
import '../core/owner_theme.dart';
import '../core/owner_state.dart';
import '../ui/owner_components.dart';
import 'live_cash_shifts.dart';
import '../core/owner_demo_data.dart';

class OwnerCashScreen extends StatelessWidget {
  const OwnerCashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (OwnerScope.of(context).live) {
      // IndexedStack builds offstage tabs; do not prefetch shifts offscreen.
      if (OwnerScope.of(context).tabIndex != 1) return const SizedBox.shrink();
      return const OwnerLiveCashShifts();
    }
    final owner = OwnerScope.of(context);
    final selected = owner.selectedRestaurants;
    return OwnerScreenFrame(children: [
      const OwnerHeading('Кассы', caption: 'Кассовые смены, выручка и чеки'),
      const SizedBox(height: 12),
      const OwnerRestaurantPicker(),
      const SizedBox(height: 13),
      const OwnerPeriodPicker(),
      const SizedBox(height: 13),
      const OwnerHeading('Кассы • список'),
      const SizedBox(height: 8),
      for (final item in OwnerDemoCash.registers) ...[
        if (selected.contains(item.restaurant)) OwnerCard(
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(
            builder: (_) => OwnerCashDetail(name: item.name, restaurant: item.restaurant, active: item.open),
          )),
          child: Row(children: [
            Icon(Icons.point_of_sale_outlined, color: OwnerPalette.accent(context), size: 27),
            const SizedBox(width: 13),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(item.restaurant, style: TextStyle(color: OwnerPalette.muted(context), fontSize: 12)),
                const SizedBox(height: 5),
                Text(item.open ? '● Открыта 10:24' : '● Закрыта 02:15',
                    style: TextStyle(fontSize: 12, color: item.open ? OwnerPalette.green : OwnerPalette.error)),
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(OwnerDemoData.money(item.revenue(owner.period)),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Icon(Icons.chevron_right, size: 19),
            ]),
          ]),
        ),
        const SizedBox(height: 10),
      ],
    ]);
  }
}

class OwnerCashDetail extends StatefulWidget {
  final String name;
  final String restaurant;
  final bool active;
  const OwnerCashDetail({
    super.key,
    required this.name,
    required this.restaurant,
    required this.active,
  });

  @override
  State<OwnerCashDetail> createState() => _OwnerCashDetailState();
}

class _OwnerCashDetailState extends State<OwnerCashDetail> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    const tabs = ['Обзор', 'Оплаты', 'Смены', 'Чеки'];
    final period = OwnerScope.of(context).period;
    final demo = OwnerDemoCash.find(widget.name);
    final payments = demo.payments(period);
    final checks = demo.checks(period);
    final revenue = demo.revenue(period);
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: OwnerScreenFrame(children: [
        OwnerCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.restaurant, style: TextStyle(color: OwnerPalette.muted(context))),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.circle, size: 11, color: widget.active ? OwnerPalette.green : OwnerPalette.error),
              const SizedBox(width: 6),
              Text(widget.active ? 'Открыта' : 'Закрыта'),
            ]),
          ],
        )),
        const SizedBox(height: 13),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: List.generate(tabs.length, (i) => Padding(
            padding: const EdgeInsets.only(right: 7),
            child: ChoiceChip(
              showCheckmark: false,
              selected: tab == i,
              label: Text(tabs[i]),
              onSelected: (_) => setState(() => tab = i),
            ),
          ))),
        ),
        const SizedBox(height: 15),
        if (tab == 0) ...[
          Row(children: [
            Expanded(child: OwnerMetric('Выручка', OwnerDemoData.money(revenue))),
            const SizedBox(width: 10),
            Expanded(child: OwnerMetric('Чеки', checks.toString())),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OwnerMetric('Наличные',
              OwnerDemoData.money(payments[0]))),
            const SizedBox(width: 10),
            Expanded(child: OwnerMetric('Карта',
              OwnerDemoData.money(payments[1]))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OwnerMetric('Возвраты',
              OwnerDemoData.money(demo.returns(period)))),
            const SizedBox(width: 10),
            Expanded(child: OwnerMetric('Средний чек',
              demo.averageCheck(period) == null ? '—'
                : OwnerDemoData.money(
                  demo.averageCheck(period)!, decimals: true))),
          ]),
          const SizedBox(height: 14),
          OwnerCard(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OwnerHeading(OwnerDemoData.chartTitle(period)),
              const SizedBox(height: 12),
              OwnerBars(
                values: OwnerDemoData.weights(period),
                labels: OwnerDemoData.labels(period),
              ),
            ],
          )),
        ] else if (tab == 1) ...[
          const OwnerHeading('Способы оплаты'),
          const SizedBox(height: 10),
          for (var i = 0; i < 4; i++) ...[
            OwnerCard(child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(['Наличные', 'Карта', 'Безналичные', 'Другое'][i]),
                  Text(OwnerDemoData.money(payments[i]),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 9),
              LinearProgressIndicator(
                value: revenue > 0 ? payments[i] / revenue : 0,
                minHeight: 7,
                borderRadius: BorderRadius.circular(5),
              ),
            ])),
            const SizedBox(height: 8),
          ],
          const OwnerDemoNotice(),
        ] else if (tab == 2) ...[
          const OwnerHeading('История смен'),
          const SizedBox(height: 10),
          for (final shift in const [
            ('№12548', 'Открыта • 14.10, 10:24', '12 450 AZN'),
            ('№12547', 'Закрыта • 13.10, 23:45', '8 230 AZN'),
            ('№12546', 'Закрыта • 12.10, 23:50', '6 780 AZN'),
          ]) ...[
            OwnerCard(onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => OwnerShiftDetail(shift: shift.$1))),
              child: Row(children: [
                const Icon(Icons.history),
                const SizedBox(width: 9),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Смена ${shift.$1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(shift.$2, style: TextStyle(color: OwnerPalette.muted(context), fontSize: 11)),
                ])),
                Text(shift.$3, style: const TextStyle(fontWeight: FontWeight.w600)),
                const Icon(Icons.chevron_right, size: 18),
              ]),
            ),
            const SizedBox(height: 8),
          ],
        ] else ...[
          const OwnerHeading('Список чеков'),
          const SizedBox(height: 10),
          for (final receipt in const [
            ('№25680', '14:32', '75,00 AZN', 'Карта'),
            ('№25679', '14:28', '24,30 AZN', 'Наличные'),
            ('№25678', '14:25', '18,00 AZN', 'Карта'),
          ]) ...[
            OwnerCard(onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => OwnerReceiptDetail(number: receipt.$1))),
              child: Row(children: [
                const Icon(Icons.receipt_long_outlined),
                const SizedBox(width: 9),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Чек ${receipt.$1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${receipt.$2} • ${receipt.$4}', style: TextStyle(color: OwnerPalette.muted(context), fontSize: 12)),
                ])),
                Text(receipt.$3, style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ]),
    );
  }
}

class OwnerShiftDetail extends StatelessWidget {
  final String shift;
  const OwnerShiftDetail({super.key, required this.shift});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Смена $shift')),
      body: OwnerScreenFrame(children: [
        const OwnerHeading('Детали смены'),
        const SizedBox(height: 12),
        const Row(children: [
          Expanded(child: OwnerMetric('Выручка', '11 320 AZN')),
          SizedBox(width: 10),
          Expanded(child: OwnerMetric('Чеки', '172')),
        ]),
        const SizedBox(height: 12),
        const OwnerCard(child: Column(children: [
          ListTile(title: Text('Начало смены'), trailing: Text('09:58')),
          Divider(height: 1),
          ListTile(title: Text('Конец смены'), trailing: Text('23:45')),
          Divider(height: 1),
          ListTile(title: Text('Возвраты'), trailing: Text('180 AZN')),
        ])),
        const SizedBox(height: 14),
        FilledButton.tonalIcon(
          onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const OwnerReceiptList())),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Просмотреть чеки смены'),
        ),
      ]),
    );
  }
}

class OwnerReceiptList extends StatelessWidget {
  const OwnerReceiptList({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Чеки смены')),
    body: OwnerScreenFrame(children: [
      for (final n in ['№25680', '№25679', '№25678'])
        Padding(padding: const EdgeInsets.only(bottom: 9),
          child: OwnerCard(
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => OwnerReceiptDetail(number: n))),
            child: ListTile(title: Text('Чек $n'), subtitle: const Text('Карта • 14:32'), trailing: const Icon(Icons.chevron_right)),
          ),
        ),
    ]),
  );
}

class OwnerReceiptDetail extends StatelessWidget {
  final String number;
  const OwnerReceiptDetail({super.key, required this.number});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Чек $number')),
    body: OwnerScreenFrame(children: [
      const OwnerCard(child: Column(children: [
        ListTile(title: Text('Касса'), trailing: Text('Касса 1')),
        Divider(height: 1),
        ListTile(title: Text('Оплата'), trailing: Text('Карта')),
        Divider(height: 1),
        ListTile(title: Text('Статус'), trailing: Text('Закрыт')),
      ])),
      const SizedBox(height: 13),
      const OwnerHeading('Состав чека'),
      const SizedBox(height: 9),
      OwnerCard(child: Column(children: [
        for (final item in const [
          ('Стейк Рибай', '42,00 AZN'),
          ('Салат Цезарь', '12,00 AZN'),
          ('Лимонад', '12,00 AZN'),
          ('Хлеб', '3,00 AZN'),
        ])
          ListTile(contentPadding: EdgeInsets.zero, title: Text(item.$1), trailing: Text(item.$2)),
        const Divider(),
        const ListTile(contentPadding: EdgeInsets.zero, title: Text('Итого', style: TextStyle(fontWeight: FontWeight.bold)), trailing: Text('75,00 AZN')),
      ])),
    ]),
  );
}
