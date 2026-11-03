import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_audit_event_style.dart';
import 'package:smart_horeca_owner/core/owner_l10n.dart';
import 'package:smart_horeca_owner/ui/owner_audit_event_tile.dart';

Map<String, dynamic> event(String kind, {String raw = '',
  String label = 'Другое событие заказа',
  String paymentType = ''}) => {
    'id':'verified-1',
    'kind':kind,
    'rawType':raw,
    'label':label,
    'paymentType':paymentType,
    'occurredAt':'2026-11-03T09:00:00Z',
  };

void main() {
  test('four risk levels use distinct colors and icons', () {
    final ordinary=OwnerAuditEventStyle.fromEvent(event('ORDER_OPENED'));
    final payment=OwnerAuditEventStyle.fromEvent(event('ORDER_CLOSED'));
    final caution=OwnerAuditEventStyle.fromEvent(event('DISCOUNT_APPLIED'));
    final critical=OwnerAuditEventStyle.fromEvent(event('RECEIPT_STORNO'));
    expect(ordinary.level,OwnerAuditLevel.ordinary);
    expect(ordinary.color,OwnerAuditEventStyle.blue);
    expect(ordinary.icon,Icons.note_add_outlined);
    expect(payment.level,OwnerAuditLevel.payment);
    expect(payment.color,OwnerAuditEventStyle.green);
    expect(caution.level,OwnerAuditLevel.caution);
    expect(caution.color,OwnerAuditEventStyle.amber);
    expect(critical.level,OwnerAuditLevel.critical);
    expect(critical.color,OwnerAuditEventStyle.red);
  });

  test('seven owner risk alerts have icon and RU/AZ/EN title', () {
    const cases=<String,String>{
      'DISCOUNT_APPLIED':'Добавлена скидка',
      'DISCOUNT_REMOVED':'Удалена скидка',
      'SURCHARGE_APPLIED':'Добавлена надбавка',
      'SURCHARGE_REMOVED':'Удалена надбавка',
      'PRECHECK_CANCELLED':'Отменён пречек',
      'RECEIPT_STORNO':'Сторно чека',
      'ITEM_REMOVED':'Удалено распечатанное блюдо',
    };
    for (final row in cases.entries) {
      final style=OwnerAuditEventStyle.fromEvent(event(row.key,
        raw:row.key=='ITEM_REMOVED'?'deletionOfPrintedItem':''));
      expect(style.title,row.value);
      expect(style.icon,isNot(Icons.history_outlined));
      expect(OwnerL10n.hasTranslation('Azərbaycan',style.title),isTrue);
      expect(OwnerL10n.hasTranslation('English',style.title),isTrue);
    }
  });

  test('printed deletion is critical; unprinted deletion is caution', () {
    final printed=OwnerAuditEventStyle.fromEvent(event('ITEM_REMOVED',
      raw:'deletionOfPrintedItem'));
    final unprinted=OwnerAuditEventStyle.fromEvent(event('ITEM_REMOVED',
      raw:'deletionOfNotPrintedItem'));
    expect(printed.level,OwnerAuditLevel.critical);
    expect(unprinted.level,OwnerAuditLevel.caution);
    expect(printed.title,isNot(unprinted.title));
  });

  test('unknown events are not fabricated as payments or refunds', () {
    final unknown=event('OTHER',raw:'unrecognizedVendorEvent',
      label:'Операция без классификации');
    final style=OwnerAuditEventStyle.fromEvent(unknown);
    expect(style.level,OwnerAuditLevel.ordinary);
    expect(style.title,'Операция без классификации');
    expect(style.icon,Icons.history_outlined);
    expect(unknown['rawType'],'unrecognizedVendorEvent');
  });

  test('payment change is caution; confirmed payments are green', () {
    expect(OwnerAuditEventStyle.fromEvent(event('PAYMENT_CHANGED')).level,
      OwnerAuditLevel.caution);
    final card=OwnerAuditEventStyle.fromEvent(
      event('PAYMENT',paymentType:'Card'));
    final cash=OwnerAuditEventStyle.fromEvent(
      event('PAYMENT',paymentType:'Наличные'));
    expect(card.title,'Оплата картой');
    expect(cash.title,'Оплата наличными');
    expect(card.level,OwnerAuditLevel.payment);
  });

  testWidgets('AZ card keeps verified event details without losing data',
    (tester) async {
    final row=event('DISCOUNT_APPLIED')
      ..addAll({
        'itemName':'Caesar Salad',
        'adjustmentName':'Happy Hour',
        'percent':10,
        'amount':5.5,
        'employee':'Cashier 1'
      });
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: OwnerAuditEventTile(
        entry:row, language:'Azərbaycan',
        formatTime: (_) => '03.11.2026 13:00',
        formatMoney: (_) => '5.50 AZN',
      ),
    )));
    expect(find.text('Endirim tətbiq edildi'),findsOneWidget);
    expect(find.text('03.11.2026 13:00'),findsOneWidget);
    expect(find.textContaining('Happy Hour'),findsOneWidget);
    expect(find.textContaining('Cashier 1'),findsOneWidget);
    expect(find.textContaining('5.50 AZN'),findsOneWidget);
    expect(find.byIcon(Icons.percent),findsOneWidget);
  });

  testWidgets('English card shows a storno as critical without changing amount',
    (tester) async {
    final row=event('RECEIPT_STORNO')
      ..addAll({'amount':20, 'employee':'Cashier 2'});
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: OwnerAuditEventTile(
        entry:row, language:'English',
        formatTime: (_) => '03.11.2026 13:00',
        formatMoney: (_) => '20.00 AZN',
      ),
    )));
    expect(find.text('Receipt voided'),findsOneWidget);
    expect(find.byIcon(Icons.block_outlined),findsOneWidget);
    expect(find.textContaining('20.00 AZN'),findsOneWidget);
  });
}
