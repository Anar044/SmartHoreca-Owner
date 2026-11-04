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

  test('a tapped push matches only the same restaurant, plugin and order', () {
    final target = OwnerPushOrderTarget.fromData(const {
      'kind':'SURCHARGE_APPLIED',
      'departmentId':department,'pluginId':plugin,'orderNum':'45',
    })!;
    expect(target.matchesOrder(departmentId:department,
      pluginId:plugin,orderNum:'45'),isTrue);
    expect(target.matchesOrder(departmentId:department,
      pluginId:plugin,orderNum:'46'),isFalse);
    expect(target.matchesOrder(departmentId:department,
      pluginId:'other-plugin',orderNum:'45'),isFalse);
    expect(target.matchesOrder(departmentId:'other-department',
      pluginId:plugin,orderNum:'45'),isFalse);
  });

  test('visible order handler consumes one matching push, unregistration is safe', () {
    final target=OwnerPushOrderTarget.fromData(const {
      'kind':'SURCHARGE_REMOVED',
      'departmentId':department,'pluginId':plugin,'orderNum':'45',
    })!;
    var refreshes=0;
    bool refresh(OwnerPushOrderTarget message) {
      if(!message.matchesOrder(departmentId:department,
          pluginId:plugin,orderNum:'45')) {
        return false;
      }
      refreshes++;
      return true;
    }
    OwnerPushService.registerVisibleOrder(refresh);
    addTearDown(() => OwnerPushService.unregisterVisibleOrder(refresh));
    expect(OwnerPushService.refreshVisibleOrder(target),isTrue);
    expect(refreshes,1);
    final other=OwnerPushOrderTarget.fromData(const {
      'kind':'DISCOUNT_APPLIED',
      'departmentId':department,'pluginId':plugin,'orderNum':'46',
    })!;
    expect(OwnerPushService.refreshVisibleOrder(other),isFalse);
    expect(refreshes,1);
    OwnerPushService.unregisterVisibleOrder(refresh);
    expect(OwnerPushService.refreshVisibleOrder(target),isFalse);
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
