import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_department_evidence.dart';

void main() {
  test('sales, POS configuration and unverified departments are distinct', () {
    final selling=OwnerDepartmentEvidence.fromJson({
      'id':'r1','activity':'SALES_CONFIRMED','groupCount':1,
      'cashCount':2,'recentRevenueAZN':1752,
      'recentSalesVerified':true,'recentPeriodVerified':true
    });
    expect(selling.evidenceOfWork,true);
    expect(selling.shortStatus,'Есть продажи за 30 дней');
    expect(selling.recentRevenue,1752);

    final configured=OwnerDepartmentEvidence.fromJson({
      'id':'r2','activity':'POS_CONFIGURED',
      'groupCount':1,'cashCount':0,
      'recentSalesVerified':false,'recentPeriodVerified':true
    });
    expect(configured.evidenceOfWork,true);
    expect(configured.shortStatus,'Есть группа');

    final unknown=OwnerDepartmentEvidence.fromJson({
      'id':'r3','activity':'UNVERIFIED',
      'groupCount':null,'cashCount':null,
      'recentSalesVerified':false,'recentPeriodVerified':false
    });
    expect(unknown.evidenceOfWork,false);
    expect(unknown.recentRevenue,isNull);
    expect(unknown.topologySummary,'Конфигурация касс недоступна');
    expect(unknown.shortStatus,'Активность не подтверждена');
  });
}
