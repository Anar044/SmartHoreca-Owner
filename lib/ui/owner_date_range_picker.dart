import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/owner_l10n.dart';
import '../core/owner_state.dart';

String ownerDisplayDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.'
    '${date.month.toString().padLeft(2, '0')}.'
    '${date.year.toString().padLeft(4, '0')}';

String ownerDisplayDateRange(DateTimeRange range) => range.start == range.end
    ? ownerDisplayDate(range.start)
    : '${ownerDisplayDate(range.start)} – ${ownerDisplayDate(range.end)}';

Future<DateTimeRange?> showOwnerDateRangePicker(
  BuildContext context, {
  DateTimeRange? initialRange,
  String title = 'Период отчёта',
  bool startWithInput = false,
}) {
  final language = OwnerScope.of(context).language;
  final locale = switch (language) {
    'Azərbaycan' => const Locale('az'),
    'English' => const Locale('en', 'GB'),
    _ => const Locale('ru'),
  };
  final today = DateUtils.dateOnly(DateTime.now());
  final firstDate = DateTime(1);
  final initial = initialRange != null &&
          !initialRange.start.isBefore(firstDate) &&
          !initialRange.end.isAfter(today)
      ? initialRange
      : DateTimeRange(start: today, end: today);
  return showDateRangePicker(
    context: context,
    firstDate: firstDate,
    lastDate: today,
    initialDateRange: initial,
    initialEntryMode: startWithInput
        ? DatePickerEntryMode.input
        : DatePickerEntryMode.calendar,
    helpText: OwnerL10n.tr(language, title),
    saveText: OwnerL10n.tr(language, 'Применить'),
    confirmText: OwnerL10n.tr(language, 'Применить'),
    cancelText: OwnerL10n.tr(language, 'Отмена'),
    errorFormatText: OwnerL10n.tr(language, 'Неверная дата'),
    errorInvalidText: OwnerL10n.tr(language, 'Дата вне диапазона'),
    errorInvalidRangeText: OwnerL10n.tr(language, 'Проверьте даты'),
    calendarDelegate: const _OwnerCalendarDelegate(),
    builder: (context, child) {
      final theme = Theme.of(context);
      return Localizations.override(
        context: context,
        locale: locale,
        delegates: GlobalMaterialLocalizations.delegates,
        child: Theme(
          data: theme.copyWith(
            inputDecorationTheme: theme.inputDecorationTheme.copyWith(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              errorMaxLines: 1,
            ),
          ),
          child: child!,
        ),
      );
    },
  );
}

class _OwnerCalendarDelegate extends GregorianCalendarDelegate {
  const _OwnerCalendarDelegate();

  @override
  String formatCompactDate(
          DateTime date, MaterialLocalizations localizations) =>
      ownerDisplayDate(date);

  @override
  String dateHelpText(MaterialLocalizations localizations) => 'DD.MM.YYYY';

  @override
  DateTime? parseCompactDate(
      String? inputString, MaterialLocalizations localizations) {
    final text = inputString?.trim() ?? '';
    final match =
        RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{4})$').firstMatch(text) ??
            RegExp(r'^(\d{2})(\d{2})(\d{4})$').firstMatch(text);
    if (match == null) return null;
    final day = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final year = int.parse(match[3]!);
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }
}
