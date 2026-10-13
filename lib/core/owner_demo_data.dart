/// Coherent illustrative data for the OFFLINE UI preview only.
///
/// Production metrics always come from the owner-scoped server API.
/// This deliberately has no network access and is never used in live mode.
class OwnerDemoRestaurant {
  final String name;
  final int revenue;
  final int checks;
  final int grossProfit;
  final List<int> dishQuantities;

  const OwnerDemoRestaurant(
    this.name,
    this.revenue,
    this.checks,
    this.grossProfit,
    this.dishQuantities,
  );
}

class OwnerDemoSnapshot {
  final String period;
  final List<OwnerDemoRestaurant> restaurants;
  final int revenue;
  final int checks;
  final int grossProfit;
  final double periodMultiplier;
  final List<double> chartValues;
  final List<String> chartLabels;
  final String chartTitle;
  final List<int> dishQuantities;

  const OwnerDemoSnapshot({
    required this.period,
    required this.restaurants,
    required this.revenue,
    required this.checks,
    required this.grossProfit,
    required this.periodMultiplier,
    required this.chartValues,
    required this.chartLabels,
    required this.chartTitle,
    required this.dishQuantities,
  });

  double? get averageCheck => checks > 0 ? revenue / checks : null;
}

class OwnerDemoData {
  const OwnerDemoData._();

  static const List<OwnerDemoRestaurant> restaurants = [
    OwnerDemoRestaurant('Ресторан Баку', 24450, 326, 6510, [120, 90, 75]),
    OwnerDemoRestaurant('Jelly Park', 16320, 218, 4200, [80, 70, 65]),
    OwnerDemoRestaurant('Jelly Metropark', 7460, 98, 2130, [45, 30, 28]),
  ];

  static const dishNames = ['Стейк Рибай', 'Цезарь с курицей', 'Люля-кебаб'];

  static double multiplier(String period) => switch (period) {
        'Вчера' => 0.90,
        '7 дней' => 6.50,
        'Месяц' => 27.0,
        _ => 1.0,
      };

  static String chartTitle(String period) => switch (period) {
        'Сегодня' || 'Вчера' => 'Выручка по часам',
        'Месяц' => 'Выручка по неделям',
        _ => 'Выручка по дням',
      };

  static List<String> labels(String period) => switch (period) {
        'Сегодня' || 'Вчера' => ['09', '11', '13', '15', '17', '19', '21'],
        'Месяц' => ['1 нед.', '2 нед.', '3 нед.', '4 нед.'],
        _ => ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
      };

  static List<double> weights(String period) => switch (period) {
        'Сегодня' || 'Вчера' => [9, 11, 14, 18, 22, 16, 10],
        'Месяц' => [21, 23, 26, 30],
        _ => [11, 12, 12, 14, 16, 18, 17],
      };

  static OwnerDemoSnapshot snapshot(Set<String> selected, String period) {
    final filtered =
        restaurants.where((r) => selected.contains(r.name)).toList();
    final scale = multiplier(period);
    final revenue = (filtered.fold<int>(0, (sum, r) => sum + r.revenue) *
            scale)
        .round();
    final checks =
        (filtered.fold<int>(0, (sum, r) => sum + r.checks) * scale).round();
    final grossProfit =
        (filtered.fold<int>(0, (sum, r) => sum + r.grossProfit) * scale).round();

    final bars = weights(period);
    final totalWeight = bars.fold<double>(0, (sum, value) => sum + value);
    final values = bars.map((weight) => revenue * weight / totalWeight).toList();
    final quantities = [
      for (var i = 0; i < dishNames.length; i++)
        (filtered.fold<int>(0, (sum, r) => sum + r.dishQuantities[i]) *
                scale)
            .round()
    ];
    return OwnerDemoSnapshot(
      period: period,
      restaurants: filtered,
      revenue: revenue,
      checks: checks,
      grossProfit: grossProfit,
      periodMultiplier: scale,
      chartValues: values,
      chartLabels: labels(period),
      chartTitle: chartTitle(period),
      dishQuantities: quantities,
    );
  }

  static int restaurantRevenue(OwnerDemoRestaurant restaurant, String period) =>
      (restaurant.revenue * multiplier(period)).round();

  static String money(num value, {bool decimals = false}) {
    final fixed = value.toStringAsFixed(decimals ? 2 : 0);
    final parts = fixed.split('.');
    final chars = parts.first;
    final buf = StringBuffer();
    for (var i = 0; i < chars.length; i++) {
      if (i != 0 && (chars.length - i) % 3 == 0) buf.write(' ');
      buf.write(chars[i]);
    }
    if (parts.length > 1) buf.write(',${parts[1]}');
    return '${buf.toString()} AZN';
  }
}
