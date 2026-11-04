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
    final caution=OwnerAuditEventStyle.fromEvent(event('PAYMENT_CHANGED',
      raw:'paymentTypeChanged'));
    final critical=OwnerAuditEventStyle.fromEvent(event('RECEIPT_STORNO',
      raw:'voidReceipt'));
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

  test('only seven preselected push events are red, with RU/AZ/EN title', () {
    const cases=<String, (String, String)>{
      'addingDiscount': ('DISCOUNT_APPLIED','Добавлена скидка'),
      'removingDiscount': ('DISCOUNT_REMOVED','Удалена скидка'),
      'addingSurcharge': ('SURCHARGE_APPLIED','Добавлена надбавка'),
      'removingSurcharge': ('SURCHARGE_REMOVED','Удалена надбавка'),
      'cancellationOfGuestBill': ('PRECHECK_CANCELLED','Отменён пречек'),
      'deletionOfPrintedItem': ('ITEM_REMOVED','Удалено распечатанное блюдо'),
      'voidReceipt': ('RECEIPT_STORNO','Сторно чека'),
    };
    for (final row in cases.entries) {
      final style=OwnerAuditEventStyle.fromEvent(
        event(row.value.$1,raw:row.key));
      expect(style.title,row.value.$2,reason:row.key);
      expect(style.color,OwnerAuditEventStyle.red,reason:row.key);
      expect(style.level,OwnerAuditLevel.critical,reason:row.key);
      expect(style.icon,isNot(Icons.history_outlined));
      expect(OwnerL10n.hasTranslation('Azərbaycan',style.title),isTrue);
      expect(OwnerL10n.hasTranslation('English',style.title),isTrue);
    }
  });

  test('all other events including previously called dangerous are NOT red', () {
    const extra=<String, String>{
      'ORDER_CANCELLED':'deletingAnOrder',
      'PRECHECK_OVERDUE':'orderInTheStatusOfTheBillForALongTime',
      'PAYMENT_CHANGED':'paymentTypeChanged',
      'ORDER_CLOSED':'closingOrder',
      'ITEM_ADDED':'addingItem',
      'ITEM_REMOVED':'deletionOfNotPrintedItem',
      'DISCOUNT_APPLIED':'someOtherDiscountEvent',
      'SURCHARGE_REMOVED':'unknownSurchargeRemoval',
      'RECEIPT_STORNO':'refund',
      'OTHER':'openCashDrawer',
      'OTHER2':'reopenClosedOrder',
      'OTHER3':'manualPriceChanged',
      'OTHER4':'cancelPayment',
      'OTHER5':'returnPayment',
    };
    for (final row in extra.entries) {
      final style=OwnerAuditEventStyle.fromEvent(
        event(row.key,raw:row.value));
      expect(style.color,isNot(OwnerAuditEventStyle.red),reason:row.value);
      expect(style.level,isNot(OwnerAuditLevel.critical),reason:row.value);
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
    final row=event('DISCOUNT_APPLIED',raw:'addingDiscount')
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
    final row=event('RECEIPT_STORNO',raw:'voidReceipt')
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
