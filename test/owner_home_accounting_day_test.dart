import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_state.dart';
import 'package:smart_horeca_owner/core/owner_backend.dart';
import 'package:smart_horeca_owner/screens/home_screen.dart';

void main() {
  test('push covers all accessible restaurants independently of Dashboard', () {
    final state=OwnerState()
      ..availableRestaurants=['RMS 1','RMS 2']
      ..restaurantIdsByName={'RMS 1':'dept-1','RMS 2':'dept-2'}
      ..selectedRestaurants={'RMS 1'};
    addTearDown(state.dispose);
    expect(state.selectedRestaurantIds,{'dept-1'});
    expect(state.pushRestaurantIds,{'dept-1','dept-2'});
  });

  test('Home uses the web accounting-day mode for Today and every period', () {
    expect(OwnerState.dashboardDateMode, 'calendar');
  });

  test('Home compares with the immediately preceding equal-length period', () {
    final state = OwnerState();
    addTearDown(state.dispose);
    final now = DateTime(2026, 11, 25);
    expect(OwnerState.previousReportDates(state.reportDates(now: now)), {
      'from': '2026-11-24', 'to': '2026-11-24',
    });
    state.period = 'Месяц';
    expect(OwnerState.previousReportDates(state.reportDates(now: now)), {
      'from': '2026-09-27', 'to': '2026-10-26',
    });
    expect(OwnerState.previousReportDates({
      'from': '2024-02-28', 'to': '2024-03-01',
    }), {
      'from': '2024-02-25', 'to': '2024-02-27',
    });
  });

  test('financial summary cache is bound to tenant, department and period', () {
    final state = OwnerState();
    addTearDown(state.dispose);
    final exact = OwnerState.summaryCacheKey('ws-1', ['r2','r1'],
      '2026-11-04','2026-11-04','calendar');
    expect(exact, OwnerState.summaryCacheKey('ws-1', ['r1','r2'],
      '2026-11-04','2026-11-04','calendar'));
    state.rememberResponse(exact, {'metrics': {'revenue': 123}});
    expect(state.cachedResponse(exact)?['metrics']['revenue'],123);
    for (final different in [
      OwnerState.summaryCacheKey('ws-2',['r1','r2'],
        '2026-11-04','2026-11-04','calendar'),
      OwnerState.summaryCacheKey('ws-1',['r1'],
        '2026-11-04','2026-11-04','calendar'),
      OwnerState.summaryCacheKey('ws-1',['r1','r2'],
        '2026-11-03','2026-11-03','calendar'),
    ]) {
      expect(state.cachedResponse(different), isNull);
    }
    state.clearResponseCache();
    expect(state.cachedResponse(exact),isNull);
  });

  test('Dashboard error shows safe source code and HTTP status', () {
    const err = OwnerApiException('HTTP_503',
      'Сервис Smart Horeca временно недоступен.',503);
    final label = OwnerState.summaryErrorText(err);
    expect(label,contains('HTTP_503'));
    expect(label,contains('HTTP 503'));
    expect(OwnerState.summaryErrorText(const OwnerApiException(
        'SECRET:opaque-url/path','Ошибка',502)),
      isNot(contains('opaque-url')));
  });

  testWidgets('Home retains verified figures and warns on failed refresh',
      (tester) async {
    final owner = OwnerState()
      ..live = true
      ..availableRestaurants = ['RMS 1']
      ..selectedRestaurants = {'RMS 1'}
      ..restaurantIdsByName = {'RMS 1': 'rms1'}
      ..dashboardError = 'Сбой отчёта (HTTP_502 · HTTP 502)'
      ..summary = {
        'success': true,
        'updatedAt': '2026-11-04T08:32:00Z',
        'metrics': {
          'revenue': 120.0, 'checks': 3,
          'avgCheck': 40.0, 'grossProfit': 50.0,
          'discounts': 2.0, 'surcharges': 0.0, 'costOfGoods': 70.0
        },
        'daily': <Map<String, dynamic>>[]
      };
    addTearDown(owner.dispose);
    await tester.pumpWidget(OwnerScope(state:owner,
      child:const MaterialApp(home:Scaffold(body:OwnerHomeScreen()))));
    await tester.pump();
    expect(find.text('Выручка'),findsWidgets);
    expect(find.textContaining('120.00 AZN'),findsWidgets);
    expect(find.textContaining('HTTP_502'),findsOneWidget);
    expect(find.textContaining('Последняя успешная загрузка'),findsOneWidget);
  });
  testWidgets('Home has no outdated open-shift operational-day card',
      (tester) async {
    final owner = OwnerState()
      ..live = true
      ..availableRestaurants = ['RMS 1']
      ..selectedRestaurants = {'RMS 1'}
      ..restaurantIdsByName = {'RMS 1': 'rms1'}
      ..summary = {
        'success': true,
        'mode': 'calendar',
        'metrics': {
          'revenue': 120.0, 'checks': 3,
          'avgCheck': 40.0, 'grossProfit': 50.0,
          'discounts': 2.0, 'surcharges': 0.0, 'costOfGoods': 70.0
        },
        'daily': <Map<String, dynamic>>[]
      };
    addTearDown(owner.dispose);
    await tester.pumpWidget(OwnerScope(
      state: owner,
      child: const MaterialApp(home: Scaffold(body: OwnerHomeScreen())),
    ));
    await tester.pump();
    expect(find.text('Выручка'), findsWidgets);
    expect(find.text('Операционный день по кассовым сменам'), findsNothing);
    expect(find.textContaining('продолжившаяся после полуночи'), findsNothing);
  });

  testWidgets('each live Home KPI shows a scoped previous-period value',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final owner = OwnerState()
      ..live = true
      ..workspaceId = 'ws-1'
      ..availableRestaurants = ['Центр']
      ..restaurantIdsByName = {'Центр': 'dept-1'}
      ..selectedRestaurants = {'Центр'}
      ..period = 'Период'
      ..customFrom = DateTime(2026, 11, 7)
      ..customTo = DateTime(2026, 11, 8)
      ..summary = {
        'metrics': {
          'revenue': 120, 'checks': 3, 'avgCheck': 40, 'grossProfit': 50,
          'discounts': 2, 'surcharges': 5, 'costOfGoods': 70,
        },
      };
    addTearDown(owner.dispose);
    owner.rememberResponse(
      OwnerState.summaryCacheKey(
        'ws-1', ['dept-1'], '2026-11-05', '2026-11-06', 'calendar',
      ),
      {
        'metrics': {
          'revenue': 90, 'checks': 2, 'avgCheck': 45, 'grossProfit': 30,
          'discounts': 1, 'surcharges': 0, 'costOfGoods': 60,
        },
      },
    );
    await tester.pumpWidget(OwnerScope(
      state: owner,
      child: const MaterialApp(home: Scaffold(body: OwnerHomeScreen())),
    ));
    expect(find.text('Предыдущий период · 05.11.2026 – 06.11.2026'), findsOneWidget);
    for (final value in [
      '90.00 AZN', '2', '45.00 AZN', '30.00 AZN',
      '1.00 AZN', '0.00 AZN', '60.00 AZN',
    ]) {
      expect(find.text(value), findsOneWidget);
    }
    owner.restaurantIdsByName = {'Центр': 'dept-2'};
    expect(owner.dashboardComparison, isNull);
    expect(tester.takeException(), isNull);
  });
}
