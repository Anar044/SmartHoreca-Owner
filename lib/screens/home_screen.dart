import 'package:flutter/material.dart';
import '../ui/owner_components.dart';
import '../core/owner_theme.dart';
import '../core/owner_state.dart';
import '../core/owner_demo_data.dart';
import '../core/owner_l10n.dart';
import '../core/owner_finance_validation.dart';
import 'owner_live_reports.dart';

class OwnerHomeScreen extends StatelessWidget {
  const OwnerHomeScreen({super.key});

  String _money(dynamic value) {
    if (value is! num) return '—';
    return '${value.toStringAsFixed(2)} AZN';
  }
  String _count(dynamic value) {
    if (value is! num) return '—';
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final state = OwnerScope.of(context);
    final selected = state.selectedRestaurants;
    final demo = OwnerDemoData.snapshot(selected, state.period);
    final data = state.summary;
    final metrics = data?['metrics'] is Map ? data!['metrics'] as Map : const {};
    final daily = (data?['daily'] is List ? data!['daily'] as List : const [])
        .whereType<Map<String, dynamic>>()
        .where((e) => e['revenue'] is num)
        .toList()
      ..sort((a, b) => (b['date'] ?? '').toString()
          .compareTo((a['date'] ?? '').toString()));

    return OwnerScreenFrame(onRefresh: state.live ? state.loadSummary : null, children: [
      const OwnerHeading('Главная', caption: 'Обзор бизнеса'),
      const SizedBox(height: 14),
      const OwnerRestaurantPicker(),
      const SizedBox(height: 13),
      const OwnerPeriodPicker(),
      const SizedBox(height: 15),
      if (state.live && data?['mode'] == 'operational' &&
          data?['operatingDay'] is Map) ...[
        Builder(builder: (context) {
          final info = data!['operatingDay'] as Map;
          final from = (info['from'] ?? '—').toString();
          final to = (info['to'] ?? '—').toString();
          final active = (info['activeShiftCount'] ?? '—').toString();
          return OwnerCard(child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.schedule, size: 22,
                color: OwnerPalette.green),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(OwnerL10n.tr(state.language,
                    'Операционный день по кассовым сменам'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('$from — $to • $active ${OwnerL10n.tr(state.language, 'открытых смен')}',
                    style: TextStyle(fontSize: 12,
                      color: OwnerPalette.muted(context))),
                ],
              )),
            ],
          ));
        }),
        const SizedBox(height: 12),
      ],
      if (state.live) ...[
        if (state.dashboardLoading)
          const OwnerCard(child: Center(child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Получаем данные Smart Horeca OLAP…'),
            ]),
          )))
        else if (state.dashboardError != null) ...[
          OwnerCard(child: Column(children: [
            const Icon(Icons.cloud_off_rounded, color: OwnerPalette.error, size: 34),
            const SizedBox(height: 9),
            Text(state.dashboardError!, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: state.loadSummary,
              icon: const Icon(Icons.refresh), label: const Text('Повторить')),
          ])),
        ] else if (data != null) ...[
          Row(children: [
            Expanded(child: OwnerMetric('Выручка', _money(metrics['revenue']),
              onTap: state.live ? () => Navigator.push(context,
                MaterialPageRoute<void>(builder: (_) => const OwnerLiveReportScreen(
                  title: 'Касса и способы оплаты', kind: 'cash',
                ))) : null)),
            const SizedBox(width: 10),
            Expanded(child: OwnerMetric('Чеков', _count(metrics['checks']))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OwnerMetric('Средний чек', _money(metrics['avgCheck']))),
            const SizedBox(width: 10),
            Expanded(child: OwnerMetric('Валовая прибыль', _money(metrics['grossProfit']))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OwnerMetric('Скидки гостям', _money(metrics['discounts']))),
            const SizedBox(width: 10),
            Expanded(child: OwnerMetric('Надбавки', _money(metrics['surcharges']))),
          ]),
          const SizedBox(height: 10),
          OwnerMetric('Себестоимость товаров', _money(metrics['costOfGoods'])),
          if (OwnerFinanceValidation.grossProfitMatchesRevenue(metrics)) ...[
            const SizedBox(height: 10),
            OwnerCard(child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 20, color: OwnerPalette.warning),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  OwnerL10n.tr(state.language,
                    'Валовая прибыль совпадает с выручкой. '
                    'Проверьте учёт себестоимости в SH OLAP перед принятием решений.'),
                  style: const TextStyle(fontSize: 12),
                )),
              ],
            )),
          ],
          const SizedBox(height: 14),
          OwnerCard(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OwnerHeading('Выручка по дням'),
              const SizedBox(height: 12),
              if (daily.isNotEmpty)
                OwnerRevenueDiagram(
                  values: daily.map((e) => (e['revenue'] as num).toDouble()).toList(),
                  labels: daily.map((e) {
                    final date = (e['date'] ?? '').toString();
                    return date.length >= 10
                      ? '${date.substring(8, 10)}.${date.substring(5, 7)}'
                      : date;
                  }).toList(),
                  valueLabels: daily.map((e) =>
                    (e['revenue'] as num).toStringAsFixed(0)).toList(),
                )
              else const Text('Нет подтверждённых данных для диаграммы за выбранный период.'),
            ],
          )),
          const SizedBox(height: 12),
          Text('Источник: ${data['source'] ?? 'SH OLAP'} • '
            'Загрузка: ${state.lastDashboardLoadSeconds?.toStringAsFixed(1) ?? '—'} с • '
            'Обновлено: ${data['updatedAt'] ?? '—'}',
            style: TextStyle(color: OwnerPalette.muted(context), fontSize: 11)),
          const SizedBox(height: 16),
          const OwnerCard(child: Text('Показатели по отдельным ресторанам и топ блюд '
              'будут доступны после подключения соответствующих серверных отчётов.')),
        ] else const OwnerCard(child: Text('Данные ещё не загружены.')),
      ] else ...[
        Row(children: [
          Expanded(child: OwnerMetric('Выручка',
            OwnerDemoData.money(demo.revenue), trend: '↑ 12,5%')),
          const SizedBox(width: 10),
          Expanded(child: OwnerMetric('Чеков',
            demo.checks.toString(), trend: '↑ 8%')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OwnerMetric('Средний чек',
            demo.averageCheck == null ? '—'
                : OwnerDemoData.money(demo.averageCheck!, decimals: true),
            trend: '↑ 4%')),
          const SizedBox(width: 10),
          Expanded(child: OwnerMetric('Валовая прибыль*',
            OwnerDemoData.money(demo.grossProfit), trend: '↑ 11%')),
        ]),
        const SizedBox(height: 13),
        OwnerCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OwnerHeading(demo.chartTitle),
            const SizedBox(height: 14),
            OwnerBars(
              values: demo.chartValues,
              labels: demo.chartLabels,
            ),
            Text('${OwnerL10n.tr(state.language, 'Демонстрационные значения')} • ${OwnerL10n.tr(state.language, state.period)}',
              style: TextStyle(
                color: OwnerPalette.muted(context), fontSize: 11)),
          ],
        )),
        const SizedBox(height: 20),
        const OwnerHeading('Выручка по ресторанам'),
        const SizedBox(height: 9),
        for (final restaurant in demo.restaurants) ...[
          OwnerCard(child: Row(
            children: [
              Icon(Icons.store_outlined, color: OwnerPalette.accent(context)),
              const SizedBox(width: 10),
              Expanded(child: Text(restaurant.name,
                overflow: TextOverflow.ellipsis)),
              Text(OwnerDemoData.money(
                OwnerDemoData.restaurantRevenue(restaurant, state.period)),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          )),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        const OwnerHeading('Популярные блюда'),
        const SizedBox(height: 9),
        OwnerCard(child: Column(children: [
          for (var i = 0; i < OwnerDemoData.dishNames.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restaurant_outlined),
              title: Text(OwnerL10n.tr(state.language, OwnerDemoData.dishNames[i])),
              trailing: Text('${demo.dishQuantities[i]} порций'),
            ),
        ])),
        const SizedBox(height: 9),
        const OwnerDemoNotice(),
      ],
    ]);
  }
}
