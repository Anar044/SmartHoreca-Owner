import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_assistant_charts.dart';

void main() {
  final report = <String, dynamic>{
    'title': 'Kassalar üzrə satış hesabatı',
    'periodLabel': '1–27 oktyabr 2026',
    'columns': [
      {'label': 'Kassa', 'align': 'left'},
      {'label': 'Satış, AZN', 'align': 'right'}
    ],
    'rows': [
      ['TEST', '2 304'],
      ['RMS 1 KASSA', '114']
    ],
    'totals': ['Ümumi satış', '2 418 AZN']
  };

  test('Azerbaijani follow-up matches and uses only verified table rows', () {
    expect(OwnerAssistantCharts.wantsChart('qrafik uzre göstər'), isTrue);
    expect(OwnerAssistantCharts.wantsChart('покажи график'), isTrue);
    expect(OwnerAssistantCharts.wantsChart('show chart'), isTrue);
    final chart = OwnerAssistantCharts.fromReport(report)!;
    expect(chart['title'], 'Kassalar üzrə satış hesabatı');
    expect(chart['subtitle'], '1–27 oktyabr 2026');
    final series = chart['series'] as List;
    final points = (series.first as Map)['data'] as List;
    expect(points, [
      {'label': 'TEST', 'value': 2304.0},
      {'label': 'RMS 1 KASSA', 'value': 114.0}
    ]);
    expect(points.length, 2);
  });

  test('number formatting and invalid report lines never create fake points', () {
    for (final formatted in ['2 304', '2.304', '2,304', '2.304,50',
      '2,304.50', '2 304 AZN', '2 304 ₼']) {
      final parsed = OwnerAssistantCharts.fromReport({
        ...report,
        'rows': [['TEST', formatted]],
      });
      expect(parsed, isNotNull, reason: formatted);
    }
    for (final bad in ['?', '2 November', '24%', 'pending', '12:45']) {
      expect(OwnerAssistantCharts.fromReport({
        ...report,
        'rows': [['TEST', bad]],
      }), isNull, reason: bad);
    }
    expect(OwnerAssistantCharts.fromReport({
      ...report,
      'rows': [['TEST', '2304'], ['RMS 1 KASSA', '?']],
    }), isNull);
    expect(OwnerAssistantCharts.fromReport({
      ...report,
      'columns': [{'label':'Amount'}],
    }), isNull);
  });

  test('accepts up to three genuine server charts and legacy single chart', () {
    final chart = OwnerAssistantCharts.fromReport(report)!;
    expect(OwnerAssistantCharts.fromApi([chart, chart, chart, chart], null),
      hasLength(3));
    expect(OwnerAssistantCharts.fromApi(null, chart), hasLength(1));
    expect(OwnerAssistantCharts.fromApi(null, null), isEmpty);
  });
}
