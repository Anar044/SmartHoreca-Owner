import 'package:flutter/material.dart';
import '../ui/owner_text.dart';
import '../core/owner_theme.dart';
import '../core/owner_state.dart';
import '../ui/owner_components.dart';
import 'live_cash_shifts.dart';
import '../core/owner_demo_data.dart';
import '../core/owner_demo_receipts.dart';
import '../core/owner_l10n.dart';

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
                Text(OwnerL10n.previewLabel(owner.language, item.name), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(item.restaurant, style: TextStyle(color: OwnerPalette.muted(context), fontSize: 12)),
                const SizedBox(height: 5),
                Text(OwnerL10n.previewLabel(owner.language,
                    item.open ? 'Открыта • 10:24' : 'Закрыта • 02:15'),
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
    final language = OwnerScope.of(context).language;
    final demo = OwnerDemoCash.find(widget.name);
    final payments = demo.payments(period);
    final checks = demo.checks(period);
    final revenue = demo.revenue(period);
    return Scaffold(
      appBar: AppBar(title: Text(OwnerL10n.previewLabel(language, widget.name))),
      body: OwnerScreenFrame(children: [
        OwnerCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.restaurant, style: TextStyle(color: OwnerPalette.muted(context))),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.circle, size: 11, color: widget.active ? OwnerPalette.green : OwnerPalette.error),
              const SizedBox(width: 6),
              Text(OwnerL10n.tr(language, widget.active ? 'Открыта' : 'Закрыта')),
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
              label: Text(OwnerL10n.tr(language, tabs[i])),
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
                  Text(OwnerL10n.tr(language,
                    ['Наличные', 'Карта', 'Безналичные', 'Другое'][i])),
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
          const OwnerHeading('История смен', caption: 'Пример последних смен выбранной кассы'),
          const SizedBox(height: 10),
          for (final shift in [
            (
              id: '№12548',
              label: demo.open ? 'Открыта • 14.10, 10:24'
                  : 'Закрыта • 14.10, 02:15',
              sum: demo.revenue('Сегодня'),
              checks: demo.checks('Сегодня'),
              day: 'Сегодня',
            ),
            (
              id: '№12547',
              label: 'Закрыта • 13.10, 23:45',
              sum: demo.revenue('Вчера'),
              checks: demo.checks('Вчера'),
              day: 'Вчера',
            ),
            (
              id: '№12546',
              label: 'Закрыта • 12.10, 23:50',
              sum: (demo.revenueToday * 0.8).round(),
              checks: (demo.checksToday * 0.8).round(),
              day: 'Ранее',
            ),
          ]) ...[
            if (period != 'Сегодня' && period != 'Вчера' ||
                period == shift.day)
              OwnerCard(
                onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                  builder: (_) => OwnerShiftDetail(
                    shift: shift.id,
                    cashName: widget.name,
                    amount: shift.sum,
                    checkCount: shift.checks,
                  ))),
                child: Row(children: [
                  const Icon(Icons.history),
                  const SizedBox(width: 9),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(OwnerL10n.previewLabel(language, 'Смена ${shift.id}'),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(OwnerL10n.previewLabel(language, shift.label), style: TextStyle(
                        color: OwnerPalette.muted(context), fontSize: 11)),
                    ],
                  )),
                  Text(OwnerDemoData.money(shift.sum),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Icon(Icons.chevron_right, size: 18),
                ]),
              ),
            const SizedBox(height: 8),
          ],
        ] else ...[
          const OwnerHeading('Список чеков', caption: 'Демо выбранной кассы'),
          const SizedBox(height: 10),
          for (final receipt in OwnerDemoReceipt.forCash(widget.name)) ...[
            OwnerCard(
              onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                builder: (_) => OwnerReceiptDetail(receipt: receipt))),
              child: Row(children: [
                const Icon(Icons.receipt_long_outlined),
                const SizedBox(width: 9),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(OwnerL10n.previewLabel(language, 'Чек ${receipt.number}'),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${receipt.time} • ${OwnerL10n.previewTender(language, receipt.paymentLabel)}',
                      style: TextStyle(color: OwnerPalette.muted(context),
                        fontSize: 12)),
                  ],
                )),
                Text(OwnerDemoData.money(receipt.amount, decimals: true),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
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
  final String cashName;
  final int amount;
  final int checkCount;

  const OwnerShiftDetail({
    super.key,
    required this.shift,
    required this.cashName,
    required this.amount,
    required this.checkCount,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(OwnerL10n.previewLabel(
      OwnerScope.of(context).language, 'Смена $shift'))),
    body: OwnerScreenFrame(children: [
      const OwnerHeading('Детали смены'),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OwnerMetric('Выручка', OwnerDemoData.money(amount))),
        const SizedBox(width: 10),
        Expanded(child: OwnerMetric('Чеки', checkCount.toString())),
      ]),
      const SizedBox(height: 12),
      OwnerCard(child: Column(children: [
        ListTile(title: const OwnerText('Касса'), trailing: Text(OwnerL10n.previewLabel(
        OwnerScope.of(context).language, cashName))),
        const Divider(height: 1),
        const ListTile(title: OwnerText('Начало смены'), trailing: Text('09:58')),
        const Divider(height: 1),
        const ListTile(title: OwnerText('Конец смены'), trailing: Text('23:45')),
      ])),
      const SizedBox(height: 14),
      FilledButton.tonalIcon(
        onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
          builder: (_) => OwnerReceiptList(cashName: cashName))),
        icon: const Icon(Icons.receipt_long_outlined),
        label: const OwnerText('Примеры чеков смены'),
      ),
    ]),
  );
}

class OwnerReceiptList extends StatelessWidget {
  final String cashName;
  const OwnerReceiptList({super.key, required this.cashName});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const OwnerText('Чеки смены')),
    body: OwnerScreenFrame(children: [
      for (final receipt in OwnerDemoReceipt.forCash(cashName))
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: OwnerCard(
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(
              builder: (_) => OwnerReceiptDetail(receipt: receipt))),
            child: ListTile(
              title: Text(OwnerL10n.previewLabel(
                OwnerScope.of(context).language, 'Чек ${receipt.number}')),
              subtitle: Text('${receipt.time} • ${OwnerL10n.previewTender(
                OwnerScope.of(context).language, receipt.paymentLabel)}'),
              trailing: Text(OwnerDemoData.money(
                receipt.amount, decimals: true)),
            ),
          ),
        ),
    ]),
  );
}

class OwnerReceiptDetail extends StatelessWidget {
  final OwnerDemoReceipt receipt;
  const OwnerReceiptDetail({super.key, required this.receipt});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(OwnerL10n.previewLabel(
      OwnerScope.of(context).language, 'Чек ${receipt.number}'))),
    body: OwnerScreenFrame(children: [
      OwnerCard(child: Column(children: [
        ListTile(title: const OwnerText('Касса'),
          trailing: Text(OwnerL10n.previewLabel(
            OwnerScope.of(context).language, receipt.cashName))),
        const Divider(height: 1),
        ListTile(title: const OwnerText('Оплата'),
          trailing: Text(OwnerL10n.previewTender(
            OwnerScope.of(context).language, receipt.paymentLabel))),
        const Divider(height: 1),
        const ListTile(title: OwnerText('Статус'), trailing: OwnerText('Закрыт')),
      ])),
      const SizedBox(height: 13),
      const OwnerHeading('Состав чека'),
      const SizedBox(height: 9),
      OwnerCard(child: Column(children: [
        for (final line in receipt.lines)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(OwnerL10n.tr(OwnerScope.of(context).language, line.name)),
            trailing: Text(OwnerDemoData.money(
                line.amount, decimals: true)),
          ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const OwnerText('Итого',
            style: TextStyle(fontWeight: FontWeight.bold)),
          trailing: Text(OwnerDemoData.money(
            receipt.amount, decimals: true)),
        ),
      ])),
      const SizedBox(height: 13),
      const OwnerHeading('Способы оплаты'),
      const SizedBox(height: 9),
      OwnerCard(child: Column(children: [
        for (final tender in receipt.tenders)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(OwnerL10n.tr(OwnerScope.of(context).language, tender.name)),
            trailing: Text(OwnerDemoData.money(
              tender.amount, decimals: true)),
          ),
      ])),
      const SizedBox(height: 12),
      const OwnerDemoNotice(),
    ]),
  );
}
