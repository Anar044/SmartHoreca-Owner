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

  const OwnerMetric(this.label, this.value, {super.key, this.trend, this.trendColor});

  @override
  Widget build(BuildContext context) {
    return OwnerCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(OwnerL10n.tr(OwnerScope.of(context).language, label),
            style: TextStyle(color: OwnerPalette.muted(context), fontSize: 12)),
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
      onTap: state.showRestaurants,
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

  @override
  Widget build(BuildContext context) {
    final state = OwnerScope.of(context);
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: ['Сегодня', 'Вчера', '7 дней', 'Месяц'].map((item) {
        return ChoiceChip(
          label: Text(OwnerL10n.tr(state.language, item),
            style: const TextStyle(fontSize: 12)),
          selected: state.period == item,
          onSelected: (_) => state.setPeriod(item),
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
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

class OwnerScreenFrame extends StatelessWidget {
  final List<Widget> children;
  const OwnerScreenFrame({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (!OwnerScope.of(context).live) ...[
          const OwnerDemoNotice(),
          const SizedBox(height: 12),
        ],
        ...children,
      ],
    );
  }
}
