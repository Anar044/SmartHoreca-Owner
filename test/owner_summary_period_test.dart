import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_backend.dart';
import 'package:smart_horeca_owner/core/owner_summary_period.dart';

int days(SummaryWindow window) =>
    DateTime.parse(window.to).difference(DateTime.parse(window.from)).inDays +
    1;

Map<String, dynamic> reply(SummaryWindow window, Set<String> restaurants) => {
      'success': true,
      'mode': 'calendar',
      'from': window.from,
      'to': window.to,
      'updatedAt': '2026-11-25T09:36:00Z',
      'scope': {
        'departmentScopeApplied': true,
        'selectedDepartmentIds': restaurants.toList()
      },
      'metrics': {
        'revenue': days(window) * restaurants.length * 10,
        'checks': days(window) * restaurants.length * 2,
        'grossProfit': days(window) * restaurants.length * 7,
        'discounts': 0,
        'surcharges': window.from == '2026-09-01' ? null : 0,
        'costOfGoods': days(window) * restaurants.length * 3,
      },
      'daily': [
        for (int i = 0; i < days(window); i++)
          {
            'date': DateTime.parse(window.from)
                .add(Duration(days: i))
                .toIso8601String()
                .substring(0, 10),
            'revenue': restaurants.length * 10,
          },
      ],
    };

void main() {
  final restaurants = {for (int i = 1; i <= 22; i++) 'dept-$i'};

  test(
      '22 restaurants through November survive timeouts and resume confirmed months',
      () async {
    final period =
        OwnerSummaryPeriod((from: '2026-01-01', to: '2026-11-25'), restaurants);
    final calls = <SummaryWindow>[];
    var disconnect = true;
    Future<Map<String, dynamic>> read(SummaryWindow window) async {
      calls.add(window);
      expect(days(window), lessThanOrEqualTo(31));
      if (window.from == '2026-05-01' && days(window) == 31) {
        throw const OwnerApiException('API_TIMEOUT', 'Timeout', 504);
      }
      if (window.from == '2026-06-01' && disconnect) {
        throw const OwnerApiException('NETWORK_UNAVAILABLE', 'Offline', 503);
      }
      return reply(window, restaurants);
    }

    await expectLater(
      period.load(read, isCurrent: () => true, onProgress: () {}),
      throwsA(isA<OwnerApiException>()
          .having((e) => e.code, 'code', 'NETWORK_UNAVAILABLE')),
    );
    expect(period.completedDays, 151);
    final firstPass = calls.length;
    disconnect = false;
    final progress = <int>[];
    final result = await period.load(read,
        isCurrent: () => true,
        onProgress: () => progress.add(period.completedDays));
    expect(calls[firstPass].from, '2026-06-01');
    expect(progress.first, 151);
    expect(progress.last, 329);
    expect(result['metrics']['revenue'], 329 * 22 * 10);
    expect(result['metrics']['checks'], 329 * 22 * 2);
    expect(result['metrics']['avgCheck'], 5);
    expect(result['metrics']['surcharges'], isNull);
    expect((result['daily'] as List).map((row) => row['date']).toSet().length,
        329);
  });

  test(
      'invalid scope, accounting dates or access errors never enter the summary',
      () async {
    final period =
        OwnerSummaryPeriod((from: '2024-02-01', to: '2024-03-03'), restaurants);
    var attempts = 0;
    await expectLater(
        period.load((window) async {
          attempts++;
          return reply(window, {'outside'});
        }, isCurrent: () => true, onProgress: () {}),
        throwsA(isA<OwnerApiException>()));
    expect(attempts, 1);
    expect(period.completedDays, 0);
    await expectLater(
        period.load((window) async {
          final value = reply(window, restaurants);
          (value['daily'] as List).add({'date': '2024-02-30'});
          return value;
        }, isCurrent: () => true, onProgress: () {}),
        throwsA(isA<OwnerApiException>()));
    expect(period.completedDays, 0);
  });
}
