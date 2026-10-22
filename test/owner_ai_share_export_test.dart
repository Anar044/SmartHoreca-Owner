import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_ai_export.dart';
import 'package:smart_horeca_owner/core/owner_l10n.dart';

void main(){
  test('PDF export includes only real report rows and measured chart values',(){
    final table=OwnerAiExport.rows({
      'columns':[{'label':'Ресторан'},{'label':'Выручка AZN'}],
      'rows':[['RMS 2',1752.0]],
    });
    expect(table,[['Ресторан','Выручка AZN'],['RMS 2','1752.0']]);
    final chart=OwnerAiExport.chartPoints({
      'series':[{'name':'Продажи','data':[
        {'label':'2026-10-20','value':1500},
        {'label':'2026-10-21','value':null},
        {'label':'2026-10-22','value':-5},
      ]}]
    });
    expect(chart.length,2);
    expect(chart.first,['Продажи','2026-10-20','1500']);
    expect(OwnerAiExport.chartPoints({'series':[]}),isEmpty);
  });

  test('AI/share and CHAIN controls have AZ/EN translations',(){
    const keys=[
      'Копировать','Поделиться','Экспорт в PDF','Стоп',
      'Остановить ответ AI','Ответ скопирован','Голосовой вопрос',
      'С признаками работы','Без подтверждения',
      'Есть кассовые смены','Групп:','Касс/точек:',
    ];
    for(final key in keys){
      expect(OwnerL10n.hasTranslation('Azərbaycan',key),isTrue,
        reason:'No Azerbaijani translation: $key');
      expect(OwnerL10n.hasTranslation('English',key),isTrue,
        reason:'No English translation: $key');
    }
  });
}
