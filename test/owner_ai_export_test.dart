import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_ai_export.dart';

void main() {
  test('copy includes actual chart labels and values, not just the AI prose', () {
    final copied = OwnerAiExport.answerWithVisualsText(
      answer: 'Qrafik əvvəlki hesabatdan quruldu.',
      charts: [
        {
          'title': 'Kassalar üzrə satışlar',
          'subtitle': '1–27 oktyabr 2026',
          'series': [
            {
              'name': 'AZN',
              'data': [
                {'label': 'TEST', 'value': 2304},
                {'label': 'RMS 1 KASSA', 'value': 114},
              ]
            }
          ],
        }
      ],
    );
    expect(copied, contains('TEST: 2304'));
    expect(copied, contains('RMS 1 KASSA: 114'));
    expect(copied, contains('Kassalar üzrə satışlar'));
    expect(copied, contains('1–27 oktyabr 2026'));
  });

  test('copy includes table and white-labels the backend presentation', () {
    final copied = OwnerAiExport.answerWithVisualsText(
      answer: 'Hesabat hazırdır.',
      report: {
        'title': 'Satış hesabatı',
        'columns': [
          {'label': 'Kassa'},
          {'label': 'Satış, AZN'},
        ],
        'rows': [
          ['TEST', '2 304'],
          ['RMS 1 KASSA', '114'],
        ]
      },
      chart: {
        'title': 'iiko satış diaqramı',
        'series': [
          {'name': 'AZN', 'data': [
            {'label': 'TEST', 'value': 2304}
          ]}
        ]
      },
    );
    expect(copied, contains('TEST | 2 304'));
    expect(copied, contains('RMS 1 KASSA | 114'));
    expect(copied, isNot(contains('iiko')));
    expect(copied, contains('Smart Horeca satış diaqramı'));
  });
}
