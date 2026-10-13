import 'package:flutter/material.dart';
import '../ui/owner_components.dart';
import '../core/owner_theme.dart';
import '../core/owner_state.dart';

class OwnerHomeScreen extends StatelessWidget {
  const OwnerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final selected = OwnerScope.of(context).selectedRestaurants;
    return OwnerScreenFrame(children: [
      const OwnerHeading('Главная', caption: 'Обзор бизнеса'),
      const SizedBox(height: 14),
      const OwnerRestaurantPicker(),
      const SizedBox(height: 13),
      const OwnerPeriodPicker(),
      const SizedBox(height: 15),
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
          const SizedBox(height: 4),
          Text('Данные примера — не финансовый отчёт',
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
        if (selected.contains(row.$1)) OwnerCard(child: Row(
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
      OwnerCard(child: Column(children: [
        for (final row in const [
          ('Стейк Рибай', '245 порций'),
          ('Цезарь с курицей', '190 порций'),
          ('Люля-кебаб', '168 порций'),
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restaurant_outlined),
            title: Text(row.$1),
            trailing: Text(row.$2),
          ),
      ])),
      const SizedBox(height: 8),
      Text('*Прибыль показывается только при проверенной себестоимости.',
          style: TextStyle(color: OwnerPalette.muted(context), fontSize: 11)),
    ]);
  }
}
