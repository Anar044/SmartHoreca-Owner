import 'package:flutter/material.dart';
import '../core/owner_audit_event_style.dart';
import '../core/owner_l10n.dart';
import '../core/owner_theme.dart';

/// Read-only tile for an already verified POS audit entry. Its presentation
/// never changes event IDs, audit timestamps, event kind or cached history.
class OwnerAuditEventTile extends StatelessWidget {
  final Map<String, dynamic> entry;
  final String language;
  final String Function(dynamic) formatTime;
  final String Function(dynamic) formatMoney;

  const OwnerAuditEventTile({
    super.key,
    required this.entry,
    required this.language,
    required this.formatTime,
    required this.formatMoney,
  });

  @override
  Widget build(BuildContext context) {
    final style = OwnerAuditEventStyle.fromEvent(entry);
    String tr(String text) => OwnerL10n.tr(language, text);
    String value(String field) => (entry[field] ?? '').toString().trim();
    final isSurcharge = entry['kind'] == 'SURCHARGE_APPLIED' ||
      entry['kind'] == 'SURCHARGE_REMOVED';

    final details = <String>[
      if (value('itemName').isNotEmpty)
        '${tr('Блюдо')}: ${value('itemName')}',
      if (value('adjustmentName').isNotEmpty)
        '${tr(isSurcharge ? 'Надбавка' : 'Скидка')}: ${value('adjustmentName')}',
      if (entry['percent'] is num)
        '${tr('Процент')}: ${entry['percent']}%',
      if (value('writeOffLabel').isNotEmpty)
        '${tr('Списание')}: ${tr(value('writeOffLabel'))}',
      if (value('writeOffReason').isNotEmpty)
        '${tr('Причина списания')}: ${value('writeOffReason')}',
      if (value('writeOffComment').isNotEmpty)
        '${tr('Комментарий')}: ${value('writeOffComment')}',
      if (entry['billMinutes'] is num)
        '${tr('Время ожидания')}: ${entry['billMinutes']} ${tr('мин')}',
      if (value('linkedOrderNum').isNotEmpty)
        '${tr('Связанный чек')}: №${value('linkedOrderNum')}',
      if (entry['quantity'] is num)
        '${tr('Количество')}: ${entry['quantity']}',
      if (entry['amount'] is num)
        '${tr('Сумма')}: ${formatMoney(entry['amount'])}',
      if (value('paymentType').isNotEmpty)
        '${tr('Оплата')}: ${value('paymentType')}',
      if (value('employee').isNotEmpty)
        '${tr('Сотрудник')}: ${value('employee')}',
    ];

    final dateTime = formatTime(entry['occurredAt']);
    final isDark = OwnerPalette.isDark(context);
    final base = OwnerPalette.surface(context);
    final tint = style.color.withValues(alpha: isDark ? 0.075 : 0.035);
    final color = Color.alphaBlend(tint, base);

    return Semantics(
      label: '${tr(style.title)}. $dateTime. ${details.join('. ')}',
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: style.color.withValues(alpha:
            isDark ? 0.28 : 0.30)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 43, height: 43,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(style.icon, size: 22, color: style.color),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(style.title),
                  style: TextStyle(
                    color: style.level == OwnerAuditLevel.critical
                      ? style.color : OwnerPalette.text(context),
                    fontWeight: FontWeight.w700, fontSize: 14, height: 1.28)),
                const SizedBox(height: 4),
                Text(dateTime, style: TextStyle(
                  fontSize: 11.5, color: OwnerPalette.muted(context))),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  for (final detail in details)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(detail, style: TextStyle(
                        fontSize: 12, height: 1.35,
                        color: OwnerPalette.muted(context))),
                    ),
                ],
              ],
            )),
          ],
        ),
      ),
    );
  }
}
