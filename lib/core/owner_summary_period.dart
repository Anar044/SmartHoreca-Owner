import 'owner_backend.dart';

typedef SummaryWindow = ({String from, String to});
typedef SummaryWindowReader = Future<Map<String, dynamic>> Function(
    SummaryWindow);

String _dateKey(DateTime value) => value.toIso8601String().substring(0, 10);
DateTime _date(String key) => DateTime.parse('${key}T00:00:00Z');

int _days(SummaryWindow window) =>
    _date(window.to).difference(_date(window.from)).inDays + 1;

Iterable<SummaryWindow> _months(SummaryWindow range, int span) sync* {
  final end = _date(range.to);
  var first = _date(range.from);
  while (!first.isAfter(end)) {
    final blockStart = (first.month - 1) ~/ span * span + 1;
    final nextMonth = DateTime.utc(first.year, blockStart + span);
    final last = nextMonth.isAfter(end)
        ? end
        : nextMonth.subtract(const Duration(days: 1));
    yield (from: _dateKey(first), to: _dateKey(last));
    first = nextMonth;
  }
}

class OwnerSummaryPeriod {
  OwnerSummaryPeriod(this.range, Set<String> departments,
      {this.section = 'full'})
      : _departments = departments.map(_departmentKey).toSet();

  static const _metrics = [
    'revenue',
    'checks',
    'grossProfit',
    'discounts',
    'surcharges',
    'costOfGoods',
  ];

  final SummaryWindow range;
  final String section;
  final Set<String> _departments;
  final _completed = <SummaryWindow, Map<String, dynamic>>{};
  final _split = <SummaryWindow>{};

  int _completedDays = 0;
  int get completedDays => _completedDays;
  late final int totalDays = _days(range);

  static String _departmentKey(String value) => value
      .trim()
      .replaceFirst(RegExp(r'^\{'), '')
      .replaceFirst(RegExp(r'\}$'), '')
      .toLowerCase();

  static const _interrupted = OwnerApiException(
    'SUMMARY_SCOPE_CHANGED',
    'Выбор ресторанов или период изменились.',
    409,
  );
  static const _unverified = OwnerApiException(
    'SUMMARY_WINDOW_UNVERIFIED',
    'Источник не подтвердил данные за часть периода.',
    502,
  );

  bool _canSplit(OwnerApiException error) =>
      error.status == 504 ||
      const {
        'API_TIMEOUT',
        'AI_SOURCE_TIMEOUT',
        'UPSTREAM_TIMEOUT',
        'BROKER_QUEUE_TIMEOUT',
        'BROKER_REQUEST_TIMEOUT',
        'OLAP_SOURCE_INCOMPLETE',
        'HTTP_502',
        'HTTP_504',
        'HTTP_524',
      }.contains(error.code);

  Future<Map<String, dynamic>> load(
    SummaryWindowReader read, {
    required bool Function() isCurrent,
    required void Function() onProgress,
  }) async {
    Future<void> visit(SummaryWindow window) async {
      if (!isCurrent()) throw _interrupted;
      if (_completed.containsKey(window)) return;
      if (!_split.contains(window)) {
        try {
          final value = await read(window);
          if (!isCurrent()) throw _interrupted;
          _verify(window, value);
          _completed[window] = value;
          _completedDays += _days(window);
          onProgress();
          return;
        } on OwnerApiException catch (error) {
          if (!isCurrent()) throw _interrupted;
          if (_days(window) <= 1 || !_canSplit(error)) rethrow;
          _split.add(window);
        }
      }
      final middle =
          _date(window.from).add(Duration(days: (_days(window) - 1) ~/ 2));
      await visit((from: window.from, to: _dateKey(middle)));
      await visit(
          (from: _dateKey(middle.add(const Duration(days: 1))), to: window.to));
    }

    onProgress();
    for (final window in _months(range, section == 'full' ? 1 : 2)) {
      await visit(window);
    }
    if (!isCurrent()) throw _interrupted;
    return _combine();
  }

  void _verify(SummaryWindow window, Map<String, dynamic> value) {
    final scope = value['scope'];
    final days = value['daily'];
    if (value['success'] != true ||
        (value['section'] ?? 'full') != section ||
        value['mode'] != 'calendar' ||
        value['from'] != window.from ||
        value['to'] != window.to ||
        value['metrics'] is! Map ||
        days is! List ||
        scope is! Map ||
        scope['departmentScopeApplied'] != true ||
        DateTime.tryParse('${value['updatedAt'] ?? ''}') == null) {
      throw _unverified;
    }
    final ids = scope['selectedDepartmentIds'];
    if (ids is! List ||
        ids.length != _departments.length ||
        !ids.every((id) =>
            id is String && _departments.contains(_departmentKey(id))) ||
        ids.map((id) => _departmentKey(id as String)).toSet().length !=
            _departments.length) {
      throw _unverified;
    }
    final dates = <String>{};
    for (final day in days) {
      final date = day is Map ? day['date'] : null;
      final parsed =
          date is String ? DateTime.tryParse('${date}T00:00:00Z') : null;
      if (date is! String ||
          parsed == null ||
          _dateKey(parsed) != date ||
          date.compareTo(window.from) < 0 ||
          date.compareTo(window.to) > 0 ||
          !dates.add(date)) {
        throw _unverified;
      }
    }
  }

  Map<String, dynamic> _combine() {
    final parts = _completed.values;
    final metrics = <String, num?>{
      for (final key in _metrics)
        key: parts.fold<num?>(0, (sum, part) {
          final value = (part['metrics'] as Map)[key];
          return sum != null && value is num && value.isFinite
              ? sum + value
              : null;
        }),
    };
    final revenue = metrics['revenue'];
    final checks = metrics['checks'];
    metrics['avgCheck'] = revenue != null && checks != null && checks > 0
        ? revenue / checks
        : null;
    final oldest = parts
        .map((part) => DateTime.parse(part['updatedAt'] as String).toUtc())
        .reduce((a, b) => a.isBefore(b) ? a : b);
    return {
      ...parts.first,
      'from': range.from,
      'to': range.to,
      'updatedAt': oldest.toIso8601String(),
      'metrics': metrics,
      'noSalesForPeriod':
          parts.every((part) => part['noSalesForPeriod'] == true),
      'daily': [for (final part in parts) ...(part['daily'] as List)],
      'unavailableMetrics': {
        for (final part in parts)
          if (part['unavailableMetrics'] is Map)
            ...(part['unavailableMetrics'] as Map),
      },
      'costOfGoodsSource': metrics['costOfGoods'] == null
          ? 'UNAVAILABLE'
          : parts.first['costOfGoodsSource'],
    };
  }
}

Map<String, dynamic> mergeSummarySections(
  Map<String, dynamic> core,
  Map<String, dynamic> adjustments,
) {
  final coreDate = DateTime.parse(core['updatedAt'] as String);
  final adjustmentDate = DateTime.parse(adjustments['updatedAt'] as String);
  return {
    ...core,
    'section': 'full',
    'updatedAt': (coreDate.isBefore(adjustmentDate) ? coreDate : adjustmentDate)
        .toIso8601String(),
    'metrics': {
      ...(core['metrics'] as Map),
      for (final name in ['discounts', 'surcharges'])
        name: (adjustments['metrics'] as Map)[name],
    },
    'unavailableMetrics': adjustments['unavailableMetrics'],
  };
}
