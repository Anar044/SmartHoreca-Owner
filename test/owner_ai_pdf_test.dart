import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_ai_pdf.dart';

void main() {
  test('PDF keeps Azerbaijani and Cyrillic answers in correct order', () {
    expect(OwnerAiPdf.paragraphs('Satış gəliri 120 AZN\nВыручка 120 AZN'),
      ['Satış gəliri 120 AZN', 'Выручка 120 AZN']);
  });
  test('PDF cuts oversize paragraphs without discarding content', () {
    final long='Satış ' * 200;
    final chunks=OwnerAiPdf.paragraphs(long);
    expect(chunks.length, greaterThan(1));
    expect(chunks.join(' ').trim(),long.trim());
  });
  test('PDF chart uses only server-grounded numeric values', () {
    final points=OwnerAiPdf.chartPoints({'series':[
      {'name':'Satış', 'data':[
        {'label':'Bakı', 'value':50},
        {'label':'Sumqayıt', 'value':'5000'},
        {'label':'Gəncə', 'value':25},
      ]}
    ]});
    expect(points.length, 2);
    expect(points.first['label'], 'Satış / Bakı');
    expect(points.last['value'], 25.0);
  });
}
