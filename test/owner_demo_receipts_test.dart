import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_demo_receipts.dart';

void main() {
  test('all example receipt lines add up to paid amounts', () {
    for (final receipt in OwnerDemoReceipt.samples) {
      expect(receipt.paid, closeTo(receipt.amount, 0.001),
          reason: 'Receipt ${receipt.number} must reconcile');
    }
  });

  test('a receipt never appears under another register', () {
    final first = OwnerDemoReceipt.forCash('Касса 1');
    final third = OwnerDemoReceipt.forCash('Касса 3');
    expect(first, isNotEmpty);
    expect(third, isNotEmpty);
    expect(first.every((r) => r.cashName == 'Касса 1'), isTrue);
    expect(third.every((r) => r.cashName == 'Касса 3'), isTrue);
    expect(first.map((r) => r.number).toSet()
        .intersection(third.map((r) => r.number).toSet()), isEmpty);
  });

  test('a check can split payment between card and cash', () {
    final receipt = OwnerDemoReceipt.samples.first;
    expect(receipt.paymentLabel, contains(' + '));
    expect(receipt.amount, 75);
    expect(receipt.paid, 75);
  });
}
