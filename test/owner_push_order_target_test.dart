import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_push_service.dart';

void main() {
  const department = '123e4567-e89b-12d3-a456-426614174000';
  const plugin = 'b557baad-f85c-4f40-a247-12f8855951ee';

  test('discount push resolves to the exact restaurant, cash and order', () {
    final target = OwnerPushOrderTarget.fromData(const {
      'kind': 'DISCOUNT_APPLIED',
      'departmentId': department,
      'pluginId': plugin,
      'orderNum': '45',
    });
    expect(target, isNotNull);
    expect(target!.orderNum, '45');
    expect(target.pluginId, plugin);
    expect(target.departmentId, department);
  });

  test('legacy and incomplete notifications never navigate to a guessed cash', () {
    expect(OwnerPushOrderTarget.fromData(const {
      'kind': 'DISCOUNT_APPLIED',
      'departmentId': department,
      'orderNum': '45',
    }), isNull);
    expect(OwnerPushOrderTarget.fromData(const {
      'kind': 'PAYMENT',
      'departmentId': department,
      'pluginId': plugin,
      'orderNum': '45',
    }), isNull);
    expect(OwnerPushOrderTarget.fromData(const {
      'kind': 'DISCOUNT_APPLIED',
      'departmentId': 'not-a-department',
      'pluginId': plugin,
      'orderNum': '45',
    }), isNull);
  });

  test('notification requires a real order number', () {
    expect(OwnerPushOrderTarget.fromData(const {
      'kind': 'DISCOUNT_REMOVED',
      'departmentId': department,
      'pluginId': plugin,
      'orderNum': '',
    }), isNull);
  });

  test('all seven distinct approved risk events support scoped order navigation', () {
    const approvedKinds = <String>{
      'DISCOUNT_APPLIED','DISCOUNT_REMOVED',
      'ITEM_REMOVED','PRECHECK_CANCELLED','RECEIPT_STORNO',
      'SURCHARGE_APPLIED','SURCHARGE_REMOVED',
    };
    expect(OwnerPushService.kinds.toSet(), approvedKinds);
    expect(OwnerPushService.kinds.length, 7);
    for (final kind in approvedKinds) {
      final target = OwnerPushOrderTarget.fromData({
        'kind': kind,
        'departmentId': department,
        'pluginId': plugin,
        'orderNum': '45',
      });
      expect(target, isNotNull, reason: kind);
      expect(target!.kind, kind);
      expect(target.departmentId, department);
    }
    expect(OwnerPushOrderTarget.fromData(const {
      'kind':'addingSurcharge',
      'departmentId':department,'pluginId':plugin,'orderNum':'45',
    }), isNull);
  });
}
