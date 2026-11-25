import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
}) {
  final language = OwnerScope.of(context).language;
  final today = DateUtils.dateOnly(DateTime.now());
  final initial = initialRange != null &&
          initialRange.start.year >= 1 &&
          !initialRange.end.isAfter(today)
      ? initialRange
      : DateTimeRange(start: today, end: today);
  return showDialog<DateTimeRange>(
    context: context,
    builder: (_) => OwnerDateRangeDialog(
      initialRange: initial,
      today: today,
      language: language,
      title: title,
    ),
  );
}

class OwnerDateRangeDialog extends StatefulWidget {
  const OwnerDateRangeDialog({
    super.key,
    required this.initialRange,
    required this.today,
    required this.language,
    required this.title,
  });

  final DateTimeRange initialRange;
  final DateTime today;
  final String language;
  final String title;

  @override
  State<OwnerDateRangeDialog> createState() => _OwnerDateRangeDialogState();
}

class _OwnerDateRangeDialogState extends State<OwnerDateRangeDialog> {
  late final _start = _DateParts(widget.initialRange.start);
  late final _end = _DateParts(widget.initialRange.end);
  String? _startError;
  String? _endError;

  String _tr(String key) => OwnerL10n.tr(widget.language, key);

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  String? _dateError(DateTime? date) {
    if (date == null) return 'Неверная дата';
    return date.isAfter(widget.today) ? 'Дата вне диапазона' : null;
  }

  void _apply() {
    final start = _start.date;
    final end = _end.date;
    final startError = _dateError(start);
    final endError = _dateError(end);
    if (startError != null || endError != null) {
      setState(() {
        _startError = startError;
        _endError = endError;
      });
      return;
    }
    if (end!.isBefore(start!)) {
      setState(() {
        _startError = null;
        _endError = 'Проверьте даты';
      });
      return;
    }
    Navigator.pop(context, DateTimeRange(start: start, end: end));
  }

  Future<void> _openCalendar() async {
    FocusScope.of(context).unfocus();
    final start = _start.date;
    final end = _end.date;
    final initial = start != null &&
            end != null &&
            !end.isBefore(start) &&
            !end.isAfter(widget.today)
        ? DateTimeRange(start: start, end: end)
        : widget.initialRange;
    final locale = switch (widget.language) {
      'Azərbaycan' => const Locale('az'),
      'English' => const Locale('en', 'GB'),
      _ => const Locale('ru'),
    };
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1),
      lastDate: widget.today,
      initialDateRange: initial,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: _tr(widget.title),
      saveText: _tr('Применить'),
      cancelText: _tr('Отмена'),
      builder: (context, child) => Localizations.override(
        context: context,
        locale: locale,
        delegates: GlobalMaterialLocalizations.delegates,
        child: child!,
      ),
    );
    if (mounted && selected != null) Navigator.pop(context, selected);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        title: Row(
          children: [
            Expanded(child: Text(_tr(widget.title))),
            IconButton(
              tooltip: _tr('Календарь'),
              onPressed: _openCalendar,
              icon: const Icon(Icons.calendar_month_outlined),
            ),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _dateRow(_tr('Дата начала'), _start, _startError),
            const SizedBox(height: 16),
            _dateRow(_tr('Дата окончания'), _end, _endError, last: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_tr('Отмена')),
          ),
          FilledButton(onPressed: _apply, child: Text(_tr('Применить'))),
        ],
      );

  Widget _dateRow(String label, _DateParts parts, String? error,
      {bool last = false}) {
    final theme = Theme.of(context);
    const labels = ['День', 'Месяц', 'Год'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        Semantics(
          container: true,
          explicitChildNodes: true,
          label: label,
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  flex: i == 2 ? 5 : 4,
                  child: TextField(
                    controller: parts.controllers[i],
                    focusNode: parts.focusNodes[i],
                    onTap: () => parts.select(i),
                    onTapAlwaysCalled: true,
                    enableInteractiveSelection: false,
                    contextMenuBuilder: null,
                    keyboardType: TextInputType.number,
                    textInputAction: last && i == 2
                        ? TextInputAction.done
                        : TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(i == 2 ? 4 : 2),
                    ],
                    textAlign: TextAlign.center,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: _tr(labels[i]),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Semantics(
            liveRegion: true,
            child: Text(
              _tr(error),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        ],
      ],
    );
  }
}

class _DateParts {
  _DateParts(DateTime date)
      : controllers = [
          TextEditingController(text: date.day.toString().padLeft(2, '0')),
          TextEditingController(text: date.month.toString().padLeft(2, '0')),
          TextEditingController(text: date.year.toString().padLeft(4, '0')),
        ] {
    for (var i = 0; i < focusNodes.length; i++) {
      final index = i;
      final node = focusNodes[i];
      node.addListener(() {
        if (node.hasFocus) select(index);
      });
    }
  }

  final List<TextEditingController> controllers;
  final focusNodes = List.generate(3, (_) => FocusNode());

  void select(int index) {
    final controller = controllers[index];
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }

  DateTime? get date {
    final day = int.tryParse(controllers[0].text);
    final month = int.tryParse(controllers[1].text);
    final yearText = controllers[2].text;
    final year = int.tryParse(yearText);
    if (day == null ||
        month == null ||
        year == null ||
        year < 1 ||
        yearText.length != 4) {
      return null;
    }
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  void dispose() {
    for (final node in focusNodes) {
      node.dispose();
    }
    for (final controller in controllers) {
      controller.dispose();
    }
  }
}
