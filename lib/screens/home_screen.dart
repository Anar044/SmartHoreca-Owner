import 'package:flutter/material.dart';
import '../ui/owner_components.dart';
import '../core/owner_theme.dart';
import '../core/owner_state.dart';

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
    final data = state.summary;
    final metrics = data?['metrics'] is Map ? data!['metrics'] as Map : const {};
    final daily = (data?['daily'] is List ? data!['daily'] as List : const [])
        .whereType<Map<String, dynamic>>().toList();

    return OwnerScreenFrame(children: [
      const OwnerHeading('Главная', caption: 'Обзор бизнеса'),
      const SizedBox(height: 14),
      const OwnerRestaurantPicker(),
      const SizedBox(height: 13),
      const OwnerPeriodPicker(),
      const SizedBox(height: 15),
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
            Expanded(child: OwnerMetric('Выручка', _money(metrics['revenue']))),
            const SizedBox(width: 10),
            Expanded(child: OwnerMetric('Чеков', _count(metrics['checks']))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OwnerMetric('Средний чек', _money(metrics['avgCheck']))),
            const SizedBox(width: 10),
            Expanded(child: OwnerMetric('Валовая прибыль', _money(metrics['grossProfit']))),
          ]),
          const SizedBox(height: 14),
          OwnerCard(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OwnerHeading('Выручка по дням'),
              const SizedBox(height: 12),
              if (daily.isNotEmpty)
                OwnerBars(
                  values: daily.map((e) => (e['revenue'] as num?)?.toDouble() ?? 0).toList(),
                  labels: daily.map((e) => e['date'].toString().substring(5)).toList(),
                )
              else const Text('Нет данных для графика за выбранный период.'),
            ],
          )),
          const SizedBox(height: 12),
          Text('Источник: ${data['source'] ?? 'SH OLAP'} • '
            'Обновлено: ${data['updatedAt'] ?? '—'}',
            style: TextStyle(color: OwnerPalette.muted(context), fontSize: 11)),
          const SizedBox(height: 16),
          const OwnerCard(child: Text('Показатели по отдельным ресторанам и топ блюд '
              'будут доступны после подключения соответствующих серверных отчётов.')),
        ] else const OwnerCard(child Text('Данные ещё не загружены.')),
      ] else ...[
        const Row(children: [
          Expanded(child: OwnerMetric('Выручка', '48 230 AZN', trend: '↑ 12,5%')),
          SizedBox(width: 10),
          Expanded(child: OwnerMetric('Чеков', '642', trend: '↑ 8%')),
        ]),
        const SizedBox(height: 10),
        const Row(children: [
          Expanded(child: OwnerMetric('Средний чек', '75,12 AZN', trend: '↑ 4%')),
          SizedBox(width: 10),
          Expanded(child: OwnerMetric('Валовая прибыль*', '12 840 AZN', trend: '↑ 11%')),
        ]),
        const SizedBox(height: 13),
        OwnerCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const OwnerHeading('Выручка по дням'),
            const SizedBox(height: 14),
            const OwnerBars(
              values: [18, 26, 23, 32, 43, 37, 50],
              labels: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
            ),
            Text('Демонстрационные значения',
                style: TextStyle(color: OwnerPalette.muted(context), fontSize: 11)),
          ],
        )),
        const SizedBox(height: 20),
        const OwnerHeading('Выручка по ресторанам'),
        const SizedBox(height: 9),
        for (final row in const [
          ('Ресторан Баку', '24 450 AZN'),
          ('Jelly Park', '16 320 AZN'),
          ('Jelly Metropark', '7 460 AZN'),
        ]) ...[
          if (selected.contains(row.$1))
            OwnerCard(child: Row(
              children: [
                Icon(Icons.store_outlined, color: OwnerPalette.accent(context)),
                const SizedBox(width: 10),
                Expanded(child: Text(row.$1, overflow: TextOverflow.ellipsis)),
                Text(row.$2, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            )),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        const OwnerHeading('Популярные блюда'),
        const SizedBox(height: 9),
        const OwnerCard(child: Column(children: [
          ListTile(contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.restaurant_outlined), title: Text('Стейк Рибай'), trailing: Text('245 порций')),
          ListTile(contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.restaurant_outlined), title: Text('Цезарь с курицей'), trailing: Text('190 порций')),
          ListTile(contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.restaurant_outlined), title: Text('Люля-кебаб'), trailing: Text('168 порций')),
        ])),
        const SizedBox(height: 9),
        const OwnerDemoNotice(),
      ],
    ]);
  }
}
