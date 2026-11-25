import 'package:flutter/material.dart';
import '../ui/owner_text.dart';
import '../ui/owner_components.dart';
import '../core/owner_theme.dart';
import '../core/owner_state.dart';
import '../core/owner_demo_data.dart';
import '../core/owner_l10n.dart';
import '../ui/owner_data_freshness.dart';
import '../ui/owner_date_range_picker.dart';
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
    final data = state.live && state.selectedRestaurantIds.isEmpty
        ? null : state.summary;
    final lastVerified = DateTime.tryParse(
      (data?['updatedAt'] ?? '').toString())?.toLocal();
    final metrics = data?['metrics'] is Map ? data!['metrics'] as Map : const {};
    final progress = state.dashboardPeriodProgress;
    final loadedDays = progress?.completedDays ?? 0;
    final periodProgress = progress == null ? null
        : '${OwnerL10n.tr(state.language, 'Загружено дней')} · $loadedDays / ${progress.totalDays}';
    final daily = (data?['daily'] is List ? data!['daily'] as List : const [])
        .whereType<Map<String, dynamic>>()
        .where((e) => e['revenue'] is num)
        .toList()
      ..sort((a, b) => (b['date'] ?? '').toString()
          .compareTo((a['date'] ?? '').toString()));
    final dates = state.reportDates();
    final comparisonDates = OwnerState.previousReportDates(dates);
    final previousMetrics = state.dashboardComparison?['metrics'] as Map?;
    String previousMoney(String key) => _money(previousMetrics?[key]);
    final previousLabel = comparisonDates == null ? null : ownerDisplayDateRange(
      DateTimeRange(
        start: DateTime.parse(comparisonDates['from']!),
        end: DateTime.parse(comparisonDates['to']!),
      ),
    );
    final days = OwnerState.periodDays(dates['from']!, dates['to']!);
    final monthly = days > 32;
    final yearly = days > 1096;
    final revenueByPeriod = <String, double>{};
    for (final row in daily) {
      final day = DateTime.tryParse((row['date'] ?? '').toString());
      if (day == null) continue;
      final month = day.month.toString().padLeft(2, '0');
      final label = yearly
          ? '${day.year}'
          : monthly
              ? '$month.${day.year}'
              : '${day.day.toString().padLeft(2, '0')}.$month';
      revenueByPeriod.update(label, (sum) => sum + (row['revenue'] as num),
          ifAbsent: () => (row['revenue'] as num).toDouble());
    }

    return OwnerScreenFrame(onRefresh: state.live ? state.refreshSummary : null, children: [
      const OwnerHeading('Главная', caption: 'Обзор бизнеса'),
      const SizedBox(height: 14),
      const OwnerRestaurantPicker(),
      const SizedBox(height: 13),
      const OwnerPeriodPicker(),
      if (state.live && data?['noSalesForPeriod'] == true) ...[
        const SizedBox(height: 7),
        OwnerText('Подтверждено отсутствие продаж в выбранном '
          'календарном периоде.',
          style: TextStyle(fontSize: 12,
            color: OwnerPalette.muted(context))),
      ],
      const SizedBox(height: 15),
      if (state.live) ...[
        if (state.dashboardLoading && data == null)
          OwnerCard(child: Center(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              if (progress == null)
                const CircularProgressIndicator()
              else
                LinearProgressIndicator(value: loadedDays / progress.totalDays),
              const SizedBox(height: 14),
              Text(periodProgress ?? OwnerL10n.tr(state.language, 'Загружаем отчёт…')),
            ]),
          )))
        else if (state.dashboardError != null && data == null) ...[
          OwnerCard(child: Column(children: [
            const Icon(Icons.cloud_off_rounded, color: OwnerPalette.error, size: 34),
            const SizedBox(height: 9),
            Text(state.dashboardError!, textAlign: TextAlign.center),
            if (loadedDays > 0 && periodProgress != null) ...[
              const SizedBox(height: 6),
              Text(periodProgress),
            ],
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: state.loadSummary,
              icon: const Icon(Icons.refresh),
              label: OwnerText(loadedDays > 0 ? 'Продолжить' : 'Повторить')),
          ])),
        ] else if (data != null) ...[
          OwnerDataFreshness(data: data, updating: state.dashboardLoading),
          if (state.dashboardLoading && periodProgress != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(periodProgress),
            ),
          if (state.dashboardError != null)
            OwnerCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                    color: OwnerPalette.warning, size: 23),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    OwnerL10n.tr(state.language,
                      'Не удалось обновить сводку. Ниже предыдущие подтверждённые данные за тот же период.'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  )),
                ]),
                const SizedBox(height: 7),
                if (lastVerified != null) Text(
                  '${OwnerL10n.tr(state.language, 'Последняя успешная загрузка')}: '
                  '${OwnerState.formatDate(lastVerified)} '
                  '${lastVerified.hour.toString().padLeft(2, '0')}:'
                  '${lastVerified.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 12,
                    color: OwnerPalette.muted(context))),
                const SizedBox(height: 6),
                Text(state.dashboardError!, style: TextStyle(
                  fontSize: 12, color: OwnerPalette.muted(context))),
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: state.loadSummary,
                  icon: const Icon(Icons.refresh),
                  label: OwnerText(loadedDays > 0 ? 'Продолжить' : 'Повторить')),
              ],
            )),
          if (previousLabel != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${OwnerL10n.tr(state.language, 'Предыдущий период')} · $previousLabel',
                style: TextStyle(fontSize: 12, color: OwnerPalette.muted(context)),
              ),
            ),
            if (state.dashboardComparisonLoading && previousMetrics == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: OwnerText('Загружаем предыдущий период…'),
              ),
            if (state.dashboardComparisonFailed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (state.dashboardComparisonError != null)
                    OwnerText(state.dashboardComparisonError!),
                  OutlinedButton.icon(
                    onPressed: state.dashboardAdjustmentsLoading
                        ? null : state.retryDashboardComparison,
                    icon: const Icon(Icons.refresh),
                    label: const OwnerText('Повторить сравнение'),
                  ),
                ]),
              ),
          ],
          if (state.dashboardAdjustmentsLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: OwnerText('Загружаем скидки и надбавки…'),
            ),
          if (state.dashboardAdjustmentsError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OwnerText(state.dashboardAdjustmentsError!),
            ),
          Row(children: [
            Expanded(child: OwnerMetric('Выручка', _money(metrics['revenue']),
              previousValue: previousMoney('revenue'),
              onTap: state.live ? () => Navigator.push(context,
                MaterialPageRoute<void>(builder: (_) => const OwnerLiveReportScreen(
                  title: 'Касса и способы оплаты', kind: 'cash',
                ))) : null)),
            const SizedBox(width: 10),
            Expanded(child: OwnerMetric('Чеков', _count(metrics['checks']),
              previousValue: _count(previousMetrics?['checks']))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OwnerMetric('Средний чек', _money(metrics['avgCheck']),
              previousValue: previousMoney('avgCheck'))),
            const SizedBox(width: 10),
            Expanded(child: OwnerMetric('Валовая прибыль', _money(metrics['grossProfit']),
              previousValue: previousMoney('grossProfit'))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OwnerMetric('Скидки гостям', _money(metrics['discounts']),
              previousValue: previousMoney('discounts'))),
            const SizedBox(width: 10),
            Expanded(child: OwnerMetric('Надбавки', _money(metrics['surcharges']),
              previousValue: previousMoney('surcharges'))),
          ]),
          const SizedBox(height: 10),
          OwnerMetric('Себестоимость товаров', _money(metrics['costOfGoods']),
            previousValue: previousMoney('costOfGoods')),
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
              OwnerHeading(yearly
                  ? 'Выручка по годам'
                  : monthly
                      ? 'Выручка по месяцам'
                      : 'Выручка по дням'),
              const SizedBox(height: 12),
              if (revenueByPeriod.isNotEmpty)
                OwnerRevenueDiagram(
                  labelWidth: monthly ? 62 : 45,
                  values: revenueByPeriod.values.toList(),
                  labels: revenueByPeriod.keys.toList(),
                  valueLabels: revenueByPeriod.values
                      .map((value) => value.toStringAsFixed(0)).toList(),
                )
              else const OwnerText('Нет подтверждённых данных для диаграммы за выбранный период.'),
            ],
          )),
          const SizedBox(height: 12),
        ] else const OwnerCard(child: OwnerText('Данные ещё не загружены.')),
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
