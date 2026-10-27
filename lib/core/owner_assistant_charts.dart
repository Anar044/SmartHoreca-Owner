/// Deterministic conversion of already-received, server-verified report
/// rows into a chart. No AI prose, totals, or unverified device cache is used.
/// Callers must use only the current authenticated conversation and scope.
class OwnerAssistantCharts {
  const OwnerAssistantCharts._();

  static final RegExp _request = RegExp(
    r'график|диаграм|постро|визуализ|qrafik|diaqram|qrafiq|chart|graph|plot',
    caseSensitive: false,
  );

  static bool wantsChart(String question) => _request.hasMatch(question);

  /// Only unqualified requests such as "qrafik üzrə göstər" can reuse the
  /// previous report. A requested new period, category or restaurant always
  /// goes back to the authorized AI endpoint for fresh verified data.
  static bool isPreviousReportChartRequest(String question) {
    if (!wantsChart(question) || question.length > 100) return false;
    const allowed = <String>{
      'qrafik', 'qrafiq', 'grafik', 'diaqram', 'diaqrama',
      'üzrə', 'uzre', 'göstər', 'goster', 'gostər', 'göstərin',
      'görünüşündə', 'şəklində', 'kimi', 'bunu',
      'график', 'графике', 'графиком', 'диаграмму', 'диаграмме',
      'покажи', 'показать', 'выведи', 'отобрази', 'построй',
      'на', 'в', 'виде', 'это', 'его',
      'show', 'chart', 'graph', 'diagram', 'plot', 'display',
      'draw', 'make', 'please', 'as', 'a', 'the', 'it', 'me',
    };
    final tokens = question.toLowerCase()
        .replaceAll(RegExp(r'[.,!?;:—–-]'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty);
    return tokens.isNotEmpty && tokens.every(allowed.contains);
  }

  /// Safely copy up to three structured charts from the verified API.
  static List<Map<String, dynamic>> fromApi(dynamic charts, dynamic chart) {
    final list = <Map<String, dynamic>>[];
    if (charts is List) {
      for (final item in charts) {
        if (item is Map && item['series'] is List && list.length < 3) {
          list.add(Map<String, dynamic>.from(item));
        }
      }
    }
    if (list.isEmpty && chart is Map && chart['series'] is List) {
      list.add(Map<String, dynamic>.from(chart));
    }
    return list;
  }

  /// Values in structured table cells may include currency or grouping
  /// separators (e.g. "2 304", "2.304,50", "2,304.50" or "2 304 AZN").
  /// Reject free-form prose, dates, percentages and non-finite values.
  static double? _number(dynamic raw) {
    if (raw is num) return raw.isFinite ? raw.toDouble() : null;
    if (raw is! String) return null;
    var value = raw.trim().replaceAll(RegExp(r'[\u00a0\u202f]'), ' ');
    value = value.replaceFirst(RegExp(r'\s*(?:AZN|₼|USD|EUR|RUB|₽)\s*$',
      caseSensitive: false), '').trim();
    if (!RegExp(r'^[+-]?[0-9][0-9 ,\.]*$').hasMatch(value)) return null;
    if (value.contains(' ')) {
      if (!RegExp(r'^[+-]?\d{1,3}(?: \d{3})+(?:[.,]\d{1,2})?$')
          .hasMatch(value)) return null;
      value = value.replaceAll(' ', '');
    }
    final commas = ','.allMatches(value).length;
    final dots = '.'.allMatches(value).length;
    if (commas > 0 && dots > 0) {
      // Last separator determines decimal portion.
      final lastComma = value.lastIndexOf(',');
      final lastDot = value.lastIndexOf('.');
      if (lastComma > lastDot) {
        value = value.replaceAll('.', '').replaceAll(',', '.');
      } else {
        value = value.replaceAll(',', '');
      }
    } else if (commas > 0 || dots > 0) {
      final separator = commas > 0 ? ',' : '.';
      final pieces = value.split(separator);
      if (pieces.length > 2) {
        if (pieces.skip(1).every((part) => part.length == 3)) {
          value = pieces.join();
        } else {
          return null;
        }
      } else if (pieces.length == 2) {
        if (pieces.last.length == 3 && pieces.first.length <= 3) {
          value = pieces.join();
        } else if (pieces.last.length <= 2) {
          value = pieces.join('.');
        } else {
          return null;
        }
      }
    }
    final result = double.tryParse(value);
    return result != null && result.isFinite ? result : null;
  }

  static Map<String, dynamic>? fromReport(Map<String, dynamic>? report) {
    if (report == null) return null;
    final columns = report['columns'];
    final rows = report['rows'];
    if (columns is! List || columns.length != 2 || rows is! List ||
        rows.isEmpty || rows.length > 100) return null;
    String columnLabel(dynamic col) =>
      col is Map ? (col['label'] ?? '').toString().trim() : col.toString().trim();
    final firstColumn = columnLabel(columns[0]);
    final valueColumn = columnLabel(columns[1]);
    if (firstColumn.isEmpty || valueColumn.isEmpty) return null;
    final points = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (row is! List || row.length != 2) return null;
      final label = row[0].toString().trim();
      final number = _number(row[1]);
      if (label.isEmpty || number == null ||
          label.length > 100 || _number(label) != null) return null;
      points.add({'label': label, 'value': number});
    }
    if (points.isEmpty) return null;
    // Reuse exact period and measure metadata, without introducing a new period.
    final title = (report['title'] ?? valueColumn).toString().trim();
    final period = (report['periodLabel'] ?? '').toString().trim();
    return {
      'type': 'horizontal_bar',
      'title': title.isEmpty ? valueColumn : title,
      'subtitle': period,
      'xLabel': firstColumn,
      'yLabel': valueColumn,
      'series': [
        {'name': valueColumn, 'data': points}
      ],
      'notes': <String>[],
    };
  }
}
