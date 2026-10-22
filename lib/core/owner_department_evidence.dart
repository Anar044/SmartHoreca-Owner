import 'owner_l10n.dart';

/// Evidence of CHAIN restaurant operation, always scoped to the user's
/// authorized organization. Missing numbers mean "not verified", never zero.
class OwnerDepartmentEvidence {
  final String id;
  final String activity;
  final int? groupCount;
  final int? cashCount;
  final int? recentShiftCount;
  final int? shiftLookbackDays;
  final double? recentRevenue;
  final bool salesVerified;
  final bool periodVerified;
  final bool shiftsVerified;
  final String groupStatus;
  final String cashStatus;

  const OwnerDepartmentEvidence({
    required this.id, required this.activity,
    this.groupCount, this.cashCount,
    this.recentShiftCount, this.shiftLookbackDays,
    this.recentRevenue,
    required this.salesVerified, required this.periodVerified,
    this.shiftsVerified=false,
    this.groupStatus='UNAVAILABLE',
    this.cashStatus='UNAVAILABLE',
  });

  factory OwnerDepartmentEvidence.fromJson(Map<String,dynamic> json) {
    int? count(dynamic v)=>v is num && v.isFinite && v>=0 ? v.toInt():null;
    final amount=json['recentRevenueAZN'];
    return OwnerDepartmentEvidence(
      id:(json['id']??'').toString(),
      activity:(json['activity']??'UNVERIFIED').toString(),
      groupCount:count(json['groupCount']),
      cashCount:count(json['cashCount']),
      recentShiftCount:count(json['recentShiftCount']),
      shiftLookbackDays:count(json['shiftLookbackDays']),
      recentRevenue:amount is num && amount.isFinite
        ?amount.toDouble():null,
      salesVerified:json['recentSalesVerified']==true,
      periodVerified:json['recentPeriodVerified']==true,
      shiftsVerified:json['recentShiftsVerified']==true,
      groupStatus:(json['groupStatus']??'UNAVAILABLE').toString(),
      cashStatus:(json['cashStatus']??'UNAVAILABLE').toString(),
    );
  }

  bool get evidenceOfWork =>
    activity=='SALES_CONFIRMED' ||
    activity=='SHIFTS_CONFIRMED' ||
    activity=='POS_CONFIGURED' ||
    (recentShiftCount??0)>0 ||
    (groupCount??0)>0 ||
    (cashCount??0)>0;

  String get shortStatus {
    if(activity=='SALES_CONFIRMED')return 'Есть продажи за 30 дней';
    if(activity=='SHIFTS_CONFIRMED')return 'Есть кассовые смены';
    if((cashCount??0)>0)return 'Есть касса / точка продаж';
    if((groupCount??0)>0)return 'Есть группа';
    return 'Активность не подтверждена';
  }

  String get topologySummary => topologySummaryFor('Русский');

  String topologySummaryFor(String language) {
    final groups=groupCount==null?'—':'$groupCount';
    final registers=cashCount==null?'—':'$cashCount';
    return '${OwnerL10n.tr(language,'Групп:')} $groups · '
      '${OwnerL10n.tr(language,'Касс/точек:')} $registers';
  }

  String? get shiftSummary {
    if((recentShiftCount??0)>0){
      return 'Подтверждены кассовые смены';
    }
    if(shiftsVerified && recentShiftCount==0){
      return 'За проверенный период кассовые смены не найдены';
    }
    return null;
  }

  bool get hasUnknownSources =>
    groupCount==null || cashCount==null ||
    (!periodVerified && !salesVerified) ||
    (!shiftsVerified && !evidenceOfWork);
}
