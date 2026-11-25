import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import '../core/owner_backend.dart';
import '../core/owner_state.dart';
import '../ui/owner_components.dart';
import '../ui/owner_date_range_picker.dart';
import '../ui/owner_text.dart';

typedef OwnerLflLoader = Future<Map<String, dynamic>> Function(
  String workspaceId,
  Set<String> restaurantIds,
  Map<String, String> query,
);

class OwnerLflScreen extends StatefulWidget {
  const OwnerLflScreen({super.key, this.load = _loadApi});

  final OwnerLflLoader load;

  static Future<Map<String, dynamic>> _loadApi(
    String workspaceId,
    Set<String> restaurantIds,
    Map<String, String> query,
  ) =>
      OwnerBackend.getJson(
        '/api/mobile/v1/lfl',
        workspaceId: workspaceId,
        departmentIds: restaurantIds,
        query: query,
        retryTransient: false,
        timeout: const Duration(seconds: 115),
      );

  @override
  State<OwnerLflScreen> createState() => _OwnerLflScreenState();
}

class _OwnerLflScreenState extends State<OwnerLflScreen> {
  DateTimeRange? _current;
  late DateTimeRange _comparison;
  bool _customComparison = false;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;
  String _metric = 'revenue';
  String? _workspace;
  Set<String> _restaurants = {};
  int _accessEpoch = -1;
  int _generation = 0;

  static DateTime _previousYear(DateTime date) {
    if (date.year == 1) return date;
    final year = date.year - 1;
    final lastDay = DateUtils.getDaysInMonth(year, date.month);
    return DateTime(year, date.month, date.day.clamp(1, lastDay));
  }

  static DateTimeRange _yearEarlier(DateTimeRange range) => DateTimeRange(
        start: _previousYear(range.start),
        end: _previousYear(range.end),
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final owner = OwnerScope.of(context);
    if (_current == null) {
      final dates = owner.reportDates();
      _current = DateTimeRange(
        start: DateTime.parse(dates['from']!),
        end: DateTime.parse(dates['to']!),
      );
      _comparison = _yearEarlier(_current!);
    }
    final workspace = owner.live ? owner.workspaceId : null;
    final restaurants = owner.selectedRestaurantIds;
    if (_workspace != workspace ||
        _accessEpoch != owner.cacheEpoch ||
        !setEquals(_restaurants, restaurants)) {
      _workspace = workspace;
      _restaurants = restaurants;
      _accessEpoch = owner.cacheEpoch;
      _clearResult();
    }
  }

  void _clearResult() {
    ++_generation;
    _result = null;
    _error = null;
    _loading = false;
  }

  Future<void> _pickPeriod({required bool comparison}) async {
    final range = await showOwnerDateRangePicker(
      context,
      initialRange: comparison ? _comparison : _current,
      title: comparison ? 'Период сравнения' : 'Текущий период',
      startWithInput: true,
    );
    if (!mounted || range == null) return;
    setState(() {
      if (comparison) {
        _customComparison = true;
        _comparison = range;
      } else {
        _current = range;
        if (!_customComparison) _comparison = _yearEarlier(range);
      }
      _clearResult();
    });
  }

  Future<void> _run() async {
    final workspace = _workspace;
    if (workspace == null || _restaurants.isEmpty || _loading) return;
    final current = _current!;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });
    try {
      final result = await widget.load(workspace, _restaurants, {
        'from': OwnerState.formatDate(current.start),
        'to': OwnerState.formatDate(current.end),
        'compareFrom': OwnerState.formatDate(_comparison.start),
        'compareTo': OwnerState.formatDate(_comparison.end),
      });
      if (!mounted || generation != _generation) return;
      setState(() {
        _result = result;
        if ((result['metrics'] as Map?)?[_metric] == null) _metric = 'revenue';
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error is OwnerApiException
            ? error.message
            : 'Не удалось загрузить данные Smart Horeca.';
        _loading = false;
      });
    }
  }

  int _days(DateTimeRange range) => OwnerState.periodDays(
        OwnerState.formatDate(range.start),
        OwnerState.formatDate(range.end),
      );

  Widget _periodCard(String label, DateTimeRange range, VoidCallback onTap) =>
      OwnerCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: onTap,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.date_range_outlined),
          title: OwnerText(label),
          subtitle: Text(ownerDisplayDateRange(range)),
          trailing: const Icon(Icons.edit_calendar_outlined),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final current = _current!;
    final metrics = _result?['metrics'] as Map?;
    final selected = metrics?[_metric] as Map?;
    return Scaffold(
      appBar: AppBar(title: const Text('Like-for-Like (LFL)')),
      body: OwnerScreenFrame(
        onRefresh: _run,
        children: [
          const OwnerRestaurantPicker(),
          const SizedBox(height: 12),
          _periodCard(
              'Текущий период', current, () => _pickPeriod(comparison: false)),
          const SizedBox(height: 8),
          _periodCard('Период сравнения', _comparison,
              () => _pickPeriod(comparison: true)),
          if (_days(current) != _days(_comparison)) ...[
            const SizedBox(height: 8),
            const OwnerText('В периодах разное число дней.'),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading || _workspace == null || _restaurants.isEmpty
                ? null
                : _run,
            icon: const Icon(Icons.compare_arrows),
            label: const OwnerText('Сравнить'),
          ),
          if (_loading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            OwnerCard(
                child: OwnerText(_error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ))),
          ],
          if (selected != null) ...[
            const SizedBox(height: 16),
            if (metrics?['checks'] != null) ...[
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'revenue', label: OwnerText('Выручка')),
                  ButtonSegment(value: 'checks', label: OwnerText('Чеки')),
                ],
                selected: {_metric},
                onSelectionChanged: (value) =>
                    setState(() => _metric = value.first),
              ),
              const SizedBox(height: 12),
            ],
            _comparisonCard(
              'Итого по сопоставимым точкам',
              selected['total'] as Map,
              subtitle: _ComparableCount(selected['comparableCount'] as int),
            ),
            if (selected['comparableCount'] == 0) ...[
              const SizedBox(height: 8),
              const OwnerText('Нет точек с данными за оба периода.'),
            ],
            for (final row in (selected['rows'] as List).whereType<Map>()) ...[
              const SizedBox(height: 8),
              _comparisonCard(row['name'].toString(), row, restaurant: true),
            ],
          ],
        ],
      ),
    );
  }

  String _amount(Object? value, {bool signed = false}) {
    if (value is! num) return '—';
    final sign = signed && value > 0 ? '+' : '';
    final currency = _result?['currency'] ?? 'AZN';
    return _metric == 'checks'
        ? '$sign${value.toStringAsFixed(0)}'
        : '$sign${value.toStringAsFixed(2)} $currency';
  }

  Widget _comparisonCard(
    String title,
    Map row, {
    bool restaurant = false,
    Widget? subtitle,
  }) {
    final change = row['change'];
    final percent = row['percent'];
    final changeLabel = percent is num
        ? '${_amount(change, signed: true)} (${percent > 0 ? '+' : ''}${percent.toStringAsFixed(1)}%)'
        : _amount(change, signed: true);
    return OwnerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (restaurant)
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700))
          else
            OwnerText(title,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          if (subtitle != null) subtitle,
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _periodAmount('Текущий период', row['current'])),
              const SizedBox(width: 8),
              Expanded(
                  child: _periodAmount('Период сравнения', row['comparison'])),
            ],
          ),
          const SizedBox(height: 10),
          if (change == null && restaurant)
            const OwnerText('Вне сравнения')
          else
            Row(children: [
              const Expanded(child: OwnerText('Изменение')),
              Flexible(
                flex: 2,
                child: Text(
                  changeLabel,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _periodAmount(String label, Object? value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OwnerText(label, style: Theme.of(context).textTheme.bodySmall),
          Text(_amount(value),
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      );
}

class _ComparableCount extends StatelessWidget {
  const _ComparableCount(this.count);

  final int count;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Flexible(child: OwnerText('Сопоставимых точек')),
          Text(' · $count'),
        ],
      );
}
