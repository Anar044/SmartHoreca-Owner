import 'package:flutter/material.dart';
import '../core/owner_theme.dart';
import '../core/owner_state.dart';
import '../core/owner_l10n.dart';

class OwnerCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const OwnerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OwnerPalette.surface(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class OwnerMetric extends StatelessWidget {
  final String label;
  final String value;
  final String? trend;
  final Color? trendColor;
  final VoidCallback? onTap;

  const OwnerMetric(this.label, this.value, {super.key, this.trend, this.trendColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    return OwnerCard(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(OwnerL10n.tr(OwnerScope.of(context).language, label),
              style: TextStyle(color: OwnerPalette.muted(context), fontSize: 12))),
            if (onTap != null) Icon(Icons.chevron_right, size: 16,
              color: OwnerPalette.muted(context)),
          ]),
          const SizedBox(height: 8),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          ),
          if (trend != null) ...[
            const SizedBox(height: 5),
            Text(trend!, style: TextStyle(color: trendColor ?? OwnerPalette.green, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

class OwnerHeading extends StatelessWidget {
  final String title;
  final String? caption;
  const OwnerHeading(this.title, {super.key, this.caption});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(OwnerL10n.tr(OwnerScope.of(context).language, title),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (caption != null) ...[
          const SizedBox(height: 4),
          Text(OwnerL10n.tr(OwnerScope.of(context).language, caption!),
            style: TextStyle(color: OwnerPalette.muted(context), fontSize: 12)),
        ],
      ],
    );
  }
}

class OwnerDemoNotice extends StatelessWidget {
  const OwnerDemoNotice({super.key});

  @override
  Widget build(BuildContext context) {
    // Never show design-preview/beta labels in the public App Store binary.
    // The offline preview itself is already disabled in a signed release.
    const previewAvailable = bool.fromEnvironment(
      'SH_ENABLE_DEMO', defaultValue: true);
    const storeCapture = bool.fromEnvironment(
      'SH_STORE_CAPTURE', defaultValue: false);
    if (!previewAvailable || storeCapture) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        const Icon(Icons.info_outline, size: 15, color: OwnerPalette.warning),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            OwnerL10n.tr(OwnerScope.of(context).language,
              'Демо дизайна • данные условные, API пока не подключён'),
            style: TextStyle(fontSize: 11, color: OwnerPalette.muted(context)),
          ),
        ),
      ],
    );
  }
}

class OwnerRestaurantPicker extends StatelessWidget {
  const OwnerRestaurantPicker({super.key});

  Future<void> _chooseRestaurants(BuildContext context, OwnerState state) async {
    // A report is a pushed route. Switching OwnerStage here would replace the
    // app's home screen behind that route and leave its picker unusable.
    // Keep a local draft until Apply; dismissing the sheet changes nothing.
    final draft = <String>{...state.selectedRestaurants};
    var query = '';
    var workingOnly = false;

    final choice = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final visible = state.availableRestaurants.where((name) {
            if (!name.toLowerCase().contains(query.toLowerCase())) return false;
            return !workingOnly ||
                state.departmentEvidence[state.restaurantIdsByName[name]]
                    ?.evidenceOfWork == true;
          }).toList();
          String tr(String ru) => OwnerL10n.tr(state.language, ru);

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
            child: FractionallySizedBox(
              heightFactor: 0.84,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 12, 8),
                  child: Row(children: [
                    Expanded(child: Text(tr('Выбор ресторанов'),
                      style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700))),
                    IconButton(
                      tooltip: tr('Закрыть'),
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: tr('Найти подразделение'),
                      isDense: true,
                    ),
                    onChanged: (value) =>
                        setSheetState(() => query = value.trim()),
                  ),
                ),
                if (state.departmentEvidence.values
                    .any((info) => info.evidenceOfWork)) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(spacing: 8, children: [
                        ChoiceChip(
                          label: Text(tr('Все')),
                          selected: !workingOnly,
                          showCheckmark: false,
                          onSelected: (_) =>
                              setSheetState(() => workingOnly = false),
                        ),
                        ChoiceChip(
                          label: Text(tr('С признаками работы')),
                          selected: workingOnly,
                          showCheckmark: false,
                          onSelected: (_) =>
                              setSheetState(() => workingOnly = true),
                        ),
                      ]),
                    ),
                  ),
                ],
                CheckboxListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                  title: Text(tr('Выбрать все')),
                  subtitle: Text('${tr('Выбран')}: ${draft.length}'),
                  value: draft.length == state.availableRestaurants.length,
                  onChanged: (checked) => setSheetState(() {
                    draft.clear();
                    if (checked == true) {
                      draft.addAll(state.availableRestaurants);
                    }
                  }),
                ),
                const Divider(height: 1),
                Expanded(child: visible.isEmpty
                  ? Center(child: Text(tr('Подразделения не найдены')))
                  : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final name = visible[index];
                      return CheckboxListTile(
                        key: ValueKey('restaurant:$name'),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 18),
                        title: Text(name, maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        value: draft.contains(name),
                        onChanged: (checked) => setSheetState(() {
                          if (checked == true) {
                            draft.add(name);
                          } else {
                            draft.remove(name);
                          }
                        }),
                      );
                    },
                  )),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: draft.isEmpty ? null
                        : () => Navigator.of(sheetContext)
                            .pop(Set<String>.of(draft)),
                      child: Text('${tr('Применить')} (${draft.length})'),
                    ),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
    if (choice == null || !context.mounted) return;
    state.applyRestaurantSelection(choice);
  }

  @override
  Widget build(BuildContext context) {
    final state = OwnerScope.of(context);
    final count = state.selectedRestaurants.length;
    final title = count == state.availableRestaurants.length
        ? '${OwnerL10n.tr(state.language, 'Все рестораны')} ($count)'
        : count == 1
            ? state.selectedRestaurants.first
            : '${OwnerL10n.tr(state.language, 'Выбран')}: $count';
    return OwnerCard(
      padding: EdgeInsets.zero,
      onTap: () => _chooseRestaurants(context, state),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.store_outlined, size: 19, color: OwnerPalette.accent(context)),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            const Icon(Icons.keyboard_arrow_down),
          ],
        ),
      ),
    );
  }
}

class OwnerPeriodPicker extends StatelessWidget {
  const OwnerPeriodPicker({super.key});

  String _shortDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}';
  }

  Future<void> _chooseCustomPeriod(
      BuildContext context, OwnerState state) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initialStart = state.customFrom ?? today.subtract(const Duration(days: 29));
    final initialEnd = state.customTo ?? today;
    final start = initialStart.isAfter(today) ? today : initialStart;
    final end = initialEnd.isAfter(today) ? today : initialEnd;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: start.isAfter(end) ? end : start,
        end: end.isBefore(start) ? start : end,
      ),
      helpText: 'Выберите период отчёта',
      saveText: 'Применить',
    );
    if (range == null || !context.mounted) return;
    if (range.end.difference(range.start).inDays > 31) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'Период ограничен 32 календарными днями. Выберите более короткий диапазон.')),
      );
      return;
    }
    state.setCustomPeriod(range.start, range.end);
  }

  @override
  Widget build(BuildContext context) {
    final state = OwnerScope.of(context);
    final customLabel = state.period == 'Период' &&
        state.customFrom != null && state.customTo != null
      ? '${_shortDate(state.customFrom)}–${_shortDate(state.customTo)}'
      : 'Выбрать даты';
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        ...['Сегодня', 'Вчера', '7 дней', 'Месяц'].map((item) {
          return ChoiceChip(
            label: Text(OwnerL10n.tr(state.language, item),
              style: const TextStyle(fontSize: 12)),
            selected: state.period == item,
            onSelected: (_) => state.setPeriod(item),
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
          );
        }),
        ChoiceChip(
          avatar: const Icon(Icons.calendar_month_outlined, size: 16),
          label: Text(customLabel, style: const TextStyle(fontSize: 12)),
          selected: state.period == 'Период',
          onSelected: (_) { _chooseCustomPeriod(context, state); },
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class OwnerBars extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  const OwnerBars({super.key, required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(1, (a, b) => b > a ? b : a);
    return SizedBox(
      height: 126,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: FractionallySizedBox(
                      heightFactor: (values[i] / maxValue).clamp(0.06, 1.0),
                      alignment: Alignment.bottomCenter,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: OwnerPalette.accent(context),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(OwnerL10n.tr(OwnerScope.of(context).language,
                    i < labels.length ? labels[i] : ''), maxLines: 1,
                  style: TextStyle(fontSize: 10, color: OwnerPalette.muted(context))),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class OwnerRevenueDiagram extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final List<String> valueLabels;
  final double labelWidth;
  const OwnerRevenueDiagram({
    super.key, required this.values, required this.labels,
    required this.valueLabels, this.labelWidth = 45,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(0, (max, value) =>
      value.abs() > max ? value.abs() : max);
    if (values.isEmpty) return const Text('Нет данных для диаграммы.');
    return Column(
      children: List.generate(values.length, (i) {
        final value = values[i];
        final fraction = maxValue > 0
            ? (value.abs() / maxValue).clamp(0.0, 1.0).toDouble() : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: Row(children: [
            SizedBox(
              width: labelWidth,
              child: Text(i < labels.length ? labels[i] : '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11,
                  color: OwnerPalette.muted(context))),
            ),
            const SizedBox(width: 8),
            Expanded(child: Container(
              height: 13,
              decoration: BoxDecoration(
                color: OwnerPalette.raised(context),
                borderRadius: BorderRadius.circular(5),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction,
                child: Container(
                  decoration: BoxDecoration(
                    color: value < 0 ? OwnerPalette.error
                        : OwnerPalette.accent(context),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            )),
            const SizedBox(width: 8),
            SizedBox(
              width: 92,
              child: Text(i < valueLabels.length ? valueLabels[i] : '—',
                textAlign: TextAlign.end,
                maxLines: 1,
                style: const TextStyle(fontSize: 11,
                  fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        );
      }),
    );
  }
}

class OwnerScreenFrame extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  const OwnerScreenFrame({super.key, required this.children, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final state = OwnerScope.of(context);
    return RefreshIndicator(
      onRefresh: () async {
        if (onRefresh != null) {
          await onRefresh!();
        } else if (state.live && state.tabIndex == 0) {
          await state.loadSummary();
        }
      },
      child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (!OwnerScope.of(context).live) ...[
          const OwnerDemoNotice(),
          const SizedBox(height: 12),
        ],
        ...children,
      ],
    ));
  }
}
