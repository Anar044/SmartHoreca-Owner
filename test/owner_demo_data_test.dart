import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_demo_data.dart';

void main() {
  test('all restaurants reproduce the approved today design example', () {
    final selected = OwnerDemoData.restaurants.map((r) => r.name).toSet();
    final snapshot = OwnerDemoData.snapshot(selected, 'Сегодня');

    expect(snapshot.revenue, 48230);
    expect(snapshot.checks, 642);
    expect(snapshot.grossProfit, 12840);
    expect(snapshot.averageCheck!.toStringAsFixed(2), '75.12');
    expect(snapshot.restaurants, hasLength(3));
    expect(snapshot.dishQuantities, [245, 190, 168]);
    expect(snapshot.chartValues.reduce((a, b) => a + b),
        closeTo(snapshot.revenue, 0.00001));
  });

  test('selecting two restaurants changes total, chart and top dishes', () {
    const two = {'Jelly Park', 'Jelly Metropark'};
    final snapshot = OwnerDemoData.snapshot(two, 'Сегодня');

    expect(snapshot.restaurants.map((e) => e.name).toSet(), two);
    expect(snapshot.revenue, 23780);
    expect(snapshot.checks, 316);
    expect(snapshot.grossProfit, 6330);
    expect(snapshot.dishQuantities, [125, 100, 93]);
    expect(snapshot.chartValues.reduce((a, b) => a + b),
        closeTo(snapshot.revenue, 0.00001));
    expect(snapshot.restaurants.fold<int>(
        0, (sum, r) => sum + OwnerDemoData.restaurantRevenue(r, 'Сегодня')),
        snapshot.revenue);
  });

  test('period changes both numeric values and chart labels', () {
    const selection = {'Ресторан Баку'};
    final today = OwnerDemoData.snapshot(selection, 'Сегодня');
    final yesterday = OwnerDemoData.snapshot(selection, 'Вчера');
    final week = OwnerDemoData.snapshot(selection, '7 дней');
    final month = OwnerDemoData.snapshot(selection, 'Месяц');

    expect(today.revenue, 24450);
    expect(yesterday.revenue, 22005);
    expect(week.revenue, 158925);
    expect(month.revenue, 660150);
    expect(today.chartTitle, 'Выручка по часам');
    expect(week.chartTitle, 'Выручка по дням');
    expect(month.chartTitle, 'Выручка по неделям');
    expect(month.chartLabels, hasLength(4));
    for (final item in [today, yesterday, week, month]) {
      expect(item.chartValues.reduce((a, b) => a + b),
          closeTo(item.revenue, 0.00001));
    }
  });

  test('format numbers in AZN without misleading dot-decimal notation', () {
    expect(OwnerDemoData.money(48230), '48 230 AZN');
    expect(OwnerDemoData.money(75.12, decimals: true), '75,12 AZN');
  });
}
