import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_audit_history.dart';

void main() {
  test('payment edit returning only a close event keeps all prior audit events',(){
    final before=<Map<String,dynamic>>[
      {'id':'new','kind':'ORDER_OPENED','occurredAt':'2026-10-19T10:00:00Z'},
      {'id':'discount','kind':'DISCOUNT_APPLIED',
        'occurredAt':'2026-10-19T10:05:00Z'},
      {'id':'closed','kind':'ORDER_CLOSED',
        'occurredAt':'2026-10-19T10:10:00Z'},
    ];
    final after=mergeConfirmedAuditEvents(before,[
      {'id':'closed','kind':'ORDER_CLOSED',
        'occurredAt':'2026-10-19T10:10:00Z'}
    ]);
    expect(after.map((e)=>e['id']).toList(),['new','discount','closed']);
  });
  test('refund and empty upstream response do not erase proven events',(){
    final original=<Map<String,dynamic>>[
      {'id':'new','kind':'ORDER_OPENED','occurredAt':'2026-10-19T10:00:00Z'},
      {'id':'closed','kind':'ORDER_CLOSED','occurredAt':'2026-10-19T10:10:00Z'}
    ];
    expect(mergeConfirmedAuditEvents(original,[]).length,2);
    final withStorno=mergeConfirmedAuditEvents(original,[
      {'id':'storno','kind':'RECEIPT_STORNO',
        'occurredAt':'2026-10-19T10:12:00Z'}
    ]);
    expect(withStorno.map((e)=>e['kind']).toList(),
      ['ORDER_OPENED','ORDER_CLOSED','RECEIPT_STORNO']);
  });
  test('cache never confuses restaurants, terminals or order numbers',(){
    final a=ownerPosAuditCacheKey('org','rms2','cash1','45');
    expect(a,isNot(ownerPosAuditCacheKey('org','rms2','cash2','45')));
    expect(a,isNot(ownerPosAuditCacheKey('org','rms1','cash1','45')));
    expect(a,isNot(ownerPosAuditCacheKey('org','rms2','cash1','46')));
    expect(a,isNot(ownerPosAuditCacheKey('other','rms2','cash1','45')));
  });
}
