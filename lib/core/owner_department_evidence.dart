/// Server-reported business activity is evidence, not an enable/disable flag.
/// A missing OLAP row can NEVER prove that a CHAIN restaurant is inactive.
class OwnerDepartmentEvidence {
  final String id;
  final String activity;
  final int? groupCount;
  final int? cashCount;
  final double? recentRevenue;
  final bool salesVerified;
  final bool periodVerified;

  const OwnerDepartmentEvidence({
    required this.id,required this.activity,this.groupCount,this.cashCount,
    this.recentRevenue,required this.salesVerified,required this.periodVerified
  });

  factory OwnerDepartmentEvidence.fromJson(Map<String,dynamic> json) {
    final amount=json['recentRevenueAZN'];
    int? count(dynamic v) => v is num && v>=0 ? v.toInt() : null;
    return OwnerDepartmentEvidence(
      id: (json['id']??'').toString(),
      activity: (json['activity']??'UNVERIFIED').toString(),
      groupCount:count(json['groupCount']),
      cashCount:count(json['cashCount']),
      recentRevenue:amount is num && amount.isFinite ? amount.toDouble():null,
      salesVerified:json['recentSalesVerified']==true,
      periodVerified:json['recentPeriodVerified']==true
    );
  }
  bool get evidenceOfWork => activity=='SALES_CONFIRMED' ||
      activity=='POS_CONFIGURED' ||
      (groupCount??0)>0||(cashCount??0)>0;
  String get shortStatus {
    if(activity=='SALES_CONFIRMED')return 'Есть продажи за 30 дней';
    if((cashCount??0)>0)return 'Есть касса / точка продаж';
    if((groupCount??0)>0)return 'Есть группа';
    return 'Активность не подтверждена';
  }
  String get topologySummary {
    final chunks=<String>[];
    if(groupCount!=null) chunks.add('Групп: $groupCount');
    if(cashCount!=null) chunks.add('Касс/точек: $cashCount');
    return chunks.isEmpty?'Конфигурация касс недоступна':chunks.join(' · ');
  }
}
