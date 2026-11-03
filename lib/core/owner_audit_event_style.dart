import 'package:flutter/material.dart';

/// Presentation only. Event identity, time, employee, amounts and ordering
/// always come from the verified POS audit API; never derive an operation by
/// comparing snapshots or changing the authoritative event payload.
enum OwnerAuditLevel { ordinary, payment, caution, critical }

class OwnerAuditEventStyle {
  final IconData icon;
  final Color color;
  final OwnerAuditLevel level;
  final String title;

  const OwnerAuditEventStyle(this.icon, this.color, this.level, this.title);

  static const blue = Color(0xFF4C8DFF);
  static const green = Color(0xFF34C77B);
  static const amber = Color(0xFFF5B83D);
  static const red = Color(0xFFFF5A5F);

  static const _ordinary = OwnerAuditLevel.ordinary;
  static const _payment = OwnerAuditLevel.payment;
  static const _caution = OwnerAuditLevel.caution;
  static const _critical = OwnerAuditLevel.critical;

  static String _normalized(dynamic value) =>
    (value ?? '').toString().trim().toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Resolve a visual identity from *verified* kind/rawType data.
  /// Never infer an actual payment, refund or deletion from a monetary total.
  static OwnerAuditEventStyle fromEvent(Map<String, dynamic> event) {
    final kind = (event['kind'] ?? '').toString().trim().toUpperCase();
    final raw = _normalized(event['rawType']);

    // The server currently normalizes both deletion types to ITEM_REMOVED.
    // A printed dish deletion is materially more serious than an unprinted one.
    if (kind == 'ITEM_REMOVED') {
      if (raw.contains('printeditem') && !raw.contains('notprinteditem')) {
        return const OwnerAuditEventStyle(
          Icons.delete_outline, red, _critical, 'Удалено распечатанное блюдо');
      }
      if (raw.contains('notprinteditem')) {
        return const OwnerAuditEventStyle(Icons.remove_circle_outline,
          amber, _caution, 'Удалено нераспечатанное блюдо');
      }
      return const OwnerAuditEventStyle(Icons.remove_circle_outline,
        amber, _caution, 'Удалено блюдо');
    }

    switch (kind) {
      case 'ORDER_OPENED':
        return const OwnerAuditEventStyle(Icons.note_add_outlined,
          blue, _ordinary, 'Заказ открыт');
      case 'ITEM_ADDED':
        return const OwnerAuditEventStyle(Icons.restaurant_menu_outlined,
          blue, _ordinary, 'Добавлено блюдо');
      case 'PRECHECK_PRINTED':
        return const OwnerAuditEventStyle(Icons.print_outlined,
          blue, _ordinary, 'Распечатан пречек');
      case 'ORDER_CLOSED':
        // "Closed" does not prove the order was paid.
        return const OwnerAuditEventStyle(Icons.check_circle_outline,
          green, _payment, 'Заказ закрыт');
      case 'PAYMENT':
        final type = (event['paymentType'] ?? '').toString().toLowerCase();
        if (RegExp(r'налич|cash|nağd|naqd').hasMatch(type)) {
          return const OwnerAuditEventStyle(Icons.payments_outlined,
            green, _payment, 'Оплата наличными');
        }
        if (RegExp(r'карт|card|kart').hasMatch(type)) {
          return const OwnerAuditEventStyle(Icons.credit_card_outlined,
            green, _payment, 'Оплата картой');
        }
        return const OwnerAuditEventStyle(Icons.payments_outlined,
          green, _payment, 'Оплата заказа');
      case 'DISCOUNT_APPLIED':
        return const OwnerAuditEventStyle(Icons.percent,
          amber, _caution, 'Добавлена скидка');
      case 'DISCOUNT_REMOVED':
        return const OwnerAuditEventStyle(Icons.cancel_outlined,
          amber, _caution, 'Удалена скидка');
      case 'SURCHARGE_APPLIED':
        return const OwnerAuditEventStyle(Icons.trending_up_outlined,
          amber, _caution, 'Добавлена надбавка');
      case 'SURCHARGE_REMOVED':
        return const OwnerAuditEventStyle(Icons.trending_down_outlined,
          amber, _caution, 'Удалена надбавка');
      case 'PRICE_ADJUSTMENT':
        return const OwnerAuditEventStyle(Icons.price_change_outlined,
          amber, _caution, 'Изменено условие расчёта');
      case 'PRECHECK_CANCELLED':
        return const OwnerAuditEventStyle(Icons.receipt_long_outlined,
          amber, _caution, 'Отменён пречек');
      case 'PRECHECK_OVERDUE':
        return const OwnerAuditEventStyle(Icons.schedule_outlined,
          amber, _caution, 'Долгое ожидание после пречека');
      case 'TABLE_CHANGED':
        return const OwnerAuditEventStyle(Icons.swap_horiz,
          amber, _caution, 'Изменён стол');
      case 'WAITER_CHANGED':
        return const OwnerAuditEventStyle(Icons.person_outline,
          amber, _caution, 'Изменён официант');
      case 'PAYMENT_CHANGED':
        return const OwnerAuditEventStyle(Icons.credit_card_outlined,
          amber, _caution, 'Изменён тип оплаты');
      case 'ORDER_CANCELLED':
        return const OwnerAuditEventStyle(Icons.cancel_outlined,
          red, _critical, 'Заказ отменён / удалён');
      case 'RECEIPT_STORNO':
        return const OwnerAuditEventStyle(Icons.block_outlined,
          red, _critical, 'Сторно чека');
    }

    // Some older plugin versions identify the operation only in rawType.
    // Match only explicit names; do not invent an operation for unknown types.
    if (raw.contains('opencashdrawer') || raw.contains('cashdraweropened')) {
      return const OwnerAuditEventStyle(Icons.inventory_2_outlined,
        red, _critical, 'Открыт денежный ящик');
    }
    if (raw.contains('reopenclosedorder') || raw.contains('reopeningclosedorder')) {
      return const OwnerAuditEventStyle(Icons.lock_open_outlined,
        red, _critical, 'Повторно открыт закрытый заказ');
    }
    if (raw.contains('manualpricechange') || raw.contains('manualpricechanged')) {
      return const OwnerAuditEventStyle(Icons.sell_outlined,
        red, _critical, 'Изменена цена вручную');
    }
    if (raw.contains('cancelpayment') || raw.contains('paymentcancelled')) {
      return const OwnerAuditEventStyle(Icons.money_off_outlined,
        red, _critical, 'Отмена оплаты');
    }
    if (raw.contains('refund') || raw.contains('returnpayment')) {
      return const OwnerAuditEventStyle(Icons.reply_outlined,
        red, _critical, 'Возврат');
    }
    if (raw.contains('orderguestsnumberchanged') ||
        raw.contains('guestcountchanged')) {
      return const OwnerAuditEventStyle(Icons.people_outline,
        blue, _ordinary, 'Изменено количество гостей');
    }
    if (raw.contains('ordersplit') || raw.contains('splitorder')) {
      return const OwnerAuditEventStyle(Icons.call_split_outlined,
        amber, _caution, 'Разделение заказа');
    }
    if (raw.contains('ordermerged') || raw.contains('mergeorders')) {
      return const OwnerAuditEventStyle(Icons.merge_type_outlined,
        amber, _caution, 'Объединение заказов');
    }

    final label = (event['label'] ?? '').toString().trim();
    return OwnerAuditEventStyle(Icons.history_outlined,
      blue, _ordinary, label.isEmpty ? 'Событие заказа' : label);
  }
}
