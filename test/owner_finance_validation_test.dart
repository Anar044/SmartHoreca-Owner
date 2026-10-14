import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_finance_validation.dart';

void main() {
  test('flags suspicious exact match only when positive numeric data available', () {
    expect(OwnerFinanceValidation.grossProfitMatchesRevenue({
      'revenue': 31, 'grossProfit': 31
    }), isTrue);
    expect(OwnerFinanceValidation.grossProfitMatchesRevenue({
      'revenue': 31, 'grossProfit': 12
    }), isFalse);
    expect(OwnerFinanceValidation.grossProfitMatchesRevenue({
      'revenue': null, 'grossProfit': null
    }), isFalse);
    expect(OwnerFinanceValidation.grossProfitMatchesRevenue({
      'revenue': 0, 'grossProfit': 0
    }), isFalse);
  });
}
