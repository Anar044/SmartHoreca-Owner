import 'package:flutter/material.dart';

import '../core/owner_backend.dart';
import '../core/owner_state.dart';
import '../core/owner_theme.dart';
import '../core/owner_l10n.dart';
import '../ui/owner_components.dart';

/// All screens in this file render authoritative, CHAIN-scoped server results.
/// No demo financial values or fabricated receipt items are used here.
class OwnerLiveReportScreen extends StatefulWidget {
  final String title;
  final String kind;
  const OwnerLiveReportScreen({
    super.key, required this.title, required this.kind,
  });

  @override
  State<OwnerLiveReportScreen> createState() => _OwnerLiveReportScreenState();
}

class _OwnerLiveReportScreenState extends State<OwnerLiveReportScreen> {
  String _scopeKey = '';
  int _generation = 0;
  bool loading = true;
  bool table = false;
  bool loadingNext = false;
  String? error;
  Map<String, dynamic>? data;
  String warehouse = '';
  String filter = 'Все';
  String search = '';

  static String _fmt(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Map<String, String> _dates(OwnerState state) {
    final now = DateTime.now();
    final end = state.period == 'Вчера'
        ? now.subtract(const Duration(days: 1)) : now;
    final start = switch (state.period) {
      '7 дней' => end.subtract(const Duration(days: 6)),
      'Месяц' => end.subtract(const Duration(days: 29)),
      _ => end,
    };
    return {'from': _fmt(start), 'to': _fmt(end)};
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = OwnerScope.of(context);
    final ids = state.selectedRestaurantIds.toList()..sort();
    final key = '${state.workspaceId}|${ids.join(',')}|${state.period}|${widget.kind}';
    if (key != _scopeKey) {
      _scopeKey = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _load() async {
    final owner = OwnerScope.of(context);
    final workspaceId = owner.workspaceId;
    final ids = owner.selectedRestaurantIds;
    if (!owner.live || workspaceId == null || ids.isEmpty) {
      setState(() {
        loading = false;
        error = 'Выберите доступные рестораны.';
        data = null;
      });
      return;
    }
    final seq = ++_generation;
    setState(() {
      loading = true;
      error = null;
      data = null;
    });
    final dates = _dates(owner);
    try {
      final query = switch (widget.kind) {
        'inventory' || 'notifications' => {'date': dates['to']!},
        _ => dates,
      };
      final endpoint = switch (widget.kind) {
        'inventory' || 'notifications' => '/api/mobile/v1/inventory',
        'orders' => '/api/mobile/v1/orders',
        'movements' => '/api/mobile/v1/movements',
        'pnl' => '/api/mobile/v1/pnl',
        _ => '/api/mobile/v1/report',
      };
      final args = widget.kind == 'inventory' || widget.kind == 'orders' ||
          widget.kind == 'notifications' || widget.kind == 'movements' ||
          widget.kind == 'pnl'
          ? query
          : {...query, 'kind': widget.kind};
      final result = await OwnerBackend.getJson(
        endpoint,
        workspaceId: workspaceId,
        departmentIds: ids,
        query: args,
      );
      if (!mounted || seq != _generation) return;
      setState(() {
        data = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _generation) return;
      setState(() {
        loading = false;
        error = e is OwnerApiException ? e.message
            : 'Не удалось загрузить данные Smart Horeca.';
      });
    }
  }

  Future<void> _loadNext() async {
    if (loadingNext || widget.kind != 'inventory') return;
    final next = data?['nextOffset'];
    if (next is! int) return;
    final owner = OwnerScope.of(context);
    final workspace = owner.workspaceId;
    if (workspace == null) return;
    final current = _generation;
    final date = _dates(owner)['to'];
    if (date == null) return;
    setState(() => loadingNext = true);
    try {
      final chunk = await OwnerBackend.getJson(
        '/api/mobile/v1/inventory',
        workspaceId: workspace,
        departmentIds: owner.selectedRestaurantIds,
        query: {'date': date, 'offset': '$next'},
      );
      if (!mounted || _generation != current) return;
      final oldRows = (data?['rows'] as List? ?? []);
      final newRows = (chunk['rows'] as List? ?? []);
      setState(() {
        data = {
          ...data!,
          'rows': [...oldRows, ...newRows],
          'nextOffset': chunk['nextOffset'],
        };
      });
    } catch (e) {
      if (mounted && _generation == current) {
        setState(() => error = e is OwnerApiException
            ? e.message : 'Не удалось загрузить следующие товары.');
      }
    } finally {
      if (mounted && _generation == current) {
        setState(() => loadingNext = false);
      }
    }
  }

  String _money(dynamic amount) => amount is num
      ? '${amount.toStringAsFixed(2)} AZN' : '—';
  String _amount(dynamic amount, String unit) => amount is num
      ? '${amount.toStringAsFixed(3)} $unit' : '—';

  Widget _source(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Text(
      'Источник: ${data?['source'] ?? 'Smart Horeca'}',
      style: TextStyle(color: OwnerPalette.muted(context), fontSize: 11),
    ),
  );

  Widget _olapView(BuildContext context, OwnerState state) {
    final rows = (data?['rows'] as List? ?? [])
        .whereType<Map<String, dynamic>>().toList();
    return Column(children: [
      Row(children: [
        Expanded(child: OwnerMetric('Позиций', '${data?['count'] ?? rows.length}')),
        const SizedBox(width: 10),
        Expanded(child: OwnerMetric('Всего',
          _money(rows.fold<double>(0, (v, e) =>
              v + ((e['value'] as num?)?.toDouble() ?? 0))))),
      ]),
      const SizedBox(height: 12),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('График'),
              icon: Icon(Icons.bar_chart)),
          ButtonSegment(value: true, label: Text('Таблица'),
              icon: Icon(Icons.table_chart_outlined)),
        ],
        selected: {table},
        onSelectionChanged: (v) => setState(() => table = v.first),
      ),
      const SizedBox(height: 12),
      if (rows.isEmpty)
        const OwnerCard(child: Text('Нет данных для выбранного периода.'))
      else if (!table)
        OwnerCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(OwnerL10n.tr(state.language, widget.title),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 13),
            OwnerBars(
              values: rows.take(12).map((r) =>
                  (r['value'] as num?)?.toDouble() ?? 0).toList(),
              labels: rows.take(12).map((r) =>
                  r['label'].toString()).toList(),
            ),
          ],
        ))
      else
        for (final row in rows) ...[
          OwnerCard(child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(row['label'].toString()),
            trailing: Text(_money(row['value']),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          )),
          const SizedBox(height: 8),
        ],
      if (data?['truncated'] == true)
        const Text('Показана часть строк. Для полного отчёта используйте веб-систему.'),
      _source(context),
    ]);
  }

  Widget _inventoryView(BuildContext context) {
    final summary = data?['summary'] as Map? ?? {};
    final stores = (data?['warehouses'] as List? ?? [])
        .whereType<Map<String, dynamic>>().toList();
    final rows = (data?['rows'] as List? ?? [])
        .whereType<Map<String, dynamic>>().where((row) {
      if (warehouse.isNotEmpty && row['storeId'] != warehouse) {
        return false;
      }
      if (filter == 'Отрицательные' &&
          ((row['quantity'] as num?) ?? 0) >= 0) {
        return false;
      }
      if (filter == 'Ниже min' && row['belowMin'] != true) {
        return false;
      }
      if (filter == 'В наличии' &&
          ((row['quantity'] as num?) ?? 0) <= 0) {
        return false;
      }
      return [
        row['productName'], row['productCode'], row['storeName']
      ].any((v) => v.toString().toLowerCase().contains(search.toLowerCase()));
    }).toList();
    return Column(children: [
      Row(children: [
        Expanded(child: OwnerMetric('Стоимость запасов',
            _money(summary['value']))),
        const SizedBox(width: 10),
        Expanded(child: OwnerMetric('Позиций',
            '${summary['positions'] ?? '—'}')),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: OwnerMetric('Отрицательные',
            '${summary['negative'] ?? '—'}')),
        const SizedBox(width: 10),
        Expanded(child: OwnerMetric('Ниже минимума',
            '${summary['belowMinimum'] ?? '—'}')),
      ]),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: warehouse,
        decoration: const InputDecoration(labelText: 'Склад'),
        items: [
          const DropdownMenuItem(value: '', child: Text('Все склады')),
          ...stores.map((s) => DropdownMenuItem(
            value: s['id'].toString(),
            child: Text(s['name'].toString()),
          )),
        ],
        onChanged: (value) => setState(() => warehouse = value ?? ''),
      ),
      const SizedBox(height: 10),
      TextField(
        decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Поиск товара, кода...'),
        onChanged: (text) => setState(() => search = text),
      ),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final f in ['Все','В наличии','Ниже min','Отрицательные'])
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(f),
                selected: filter == f,
                showCheckmark: false,
                onSelected: (_) => setState(() => filter = f),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      if (rows.isEmpty)
        const OwnerCard(child: Text('Нет складских позиций по фильтрам.'))
      else for (final row in rows) ...[
        OwnerCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => OwnerLiveProductScreen(row: row,
              asOf: data?['asOf']?.toString() ?? ''),
          )),
          child: Row(children: [
            Icon(Icons.inventory_2_outlined,
                color: OwnerPalette.accent(context)),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row['productName'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(row['storeName'].toString(),
                    style: TextStyle(color: OwnerPalette.muted(context),
                        fontSize: 11)),
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_amount(row['quantity'], row['unit']?.toString() ?? ''),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(_money(row['value']),
                  style: TextStyle(color: OwnerPalette.muted(context),
                      fontSize: 11)),
            ]),
            const Icon(Icons.chevron_right, size: 18),
          ]),
        ),
        const SizedBox(height: 8),
      ],
      if (data?['nextOffset'] != null)
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: loadingNext ? null : _loadNext,
            icon: loadingNext
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.expand_more),
            label: const Text('Загрузить ещё товары'),
          ),
        ),
      _source(context),
    ]);
  }

  Widget _ordersView(BuildContext context) {
    final orders = (data?['orders'] as List? ?? [])
        .whereType<Map<String, dynamic>>().toList();
    return Column(children: [
      Row(children: [
        Expanded(child: OwnerMetric('Чеков', '${data?['count'] ?? '—'}')),
        const SizedBox(width: 10),
        const Expanded(child: OwnerMetric('Режим', 'Просмотр')),
      ]),
      const SizedBox(height: 12),
      if (orders.isEmpty)
        const OwnerCard(child: Text('Нет чеков за выбранный период.')),
      for (final order in orders) ...[
        OwnerCard(
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(
            builder: (_) => OwnerLiveOrderScreen(order: order),
          )),
          child: Row(children: [
            const Icon(Icons.receipt_long_outlined),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Чек ${order['number']}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${order['date'] ?? ''} • ${order['table'] ?? ''}',
                    style: TextStyle(color: OwnerPalette.muted(context),
                        fontSize: 11)),
              ],
            )),
            Text(_money(order['amount']),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const Icon(Icons.chevron_right, size: 17),
          ]),
        ),
        const SizedBox(height: 9),
      ],
      if (data?['truncated'] == true)
        const Text('В приложении показаны первые 500 чеков.'),
      _source(context),
    ]);
  }

  Widget _movementsView(BuildContext context) {
    final rows = (data?['rows'] as List? ?? [])
        .whereType<Map<String,dynamic>>().toList();
    return Column(children: [
      OwnerCard(child: ListTile(
        title: const Text('Движение товаров'),
        trailing: Text('${data?['count'] ?? rows.length}'),
      )),
      const SizedBox(height: 10),
      if (rows.isEmpty) const OwnerCard(child: Text('Движений за период нет.')),
      for (final row in rows) ...[
        OwnerCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(row['productName'].toString(),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${row['date'] ?? ''} • ${row['documentNumber'] ?? ''}'),
            Text('${row['type'] ?? ''} • ${row['storeName'] ?? ''}'),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_amount(row['quantity'], row['unit']?.toString() ?? '')),
              Text(_money(row['value'])),
            ]),
          ],
        )),
        const SizedBox(height: 8),
      ],
      _source(context),
    ]);
  }

  Widget _pnlView(BuildContext context) {
    final metrics = data?['metrics'] as Map? ?? {};
    final rows = (data?['rows'] as List? ?? [])
        .whereType<Map<String,dynamic>>().toList();
    return Column(children: [
      Row(children: [
        Expanded(child: OwnerMetric('Выручка', _money(metrics['revenue']))),
        const SizedBox(width: 10),
        Expanded(child: OwnerMetric('Валовая прибыль',
            _money(metrics['grossProfit']))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: OwnerMetric('Себестоимость',
            _money(metrics['cogs']))),
        const SizedBox(width: 10),
        Expanded(child: OwnerMetric('Чистая прибыль',
            _money(metrics['netProfit']))),
      ]),
      const SizedBox(height: 12),
      for (final row in rows) ...[
        OwnerCard(child: Row(children: [
          Expanded(child: Text(row['name'].toString())),
          const SizedBox(width: 9),
          Text(_money(row['value']),
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ])),
        const SizedBox(height: 7),
      ],
      _source(context),
    ]);
  }

  Widget _notificationsView(BuildContext context) {
    final rows = (data?['rows'] as List? ?? [])
        .whereType<Map<String,dynamic>>()
        .where((e) => e['belowMin'] == true ||
          ((e['quantity'] as num?) ?? 0) < 0).toList();
    return Column(children: [
      const OwnerCard(child: Text('Текущие складские предупреждения. '
          'Push-уведомления ещё не подключены.')),
      const SizedBox(height: 12),
      if (rows.isEmpty)
        const OwnerCard(child: Text('По текущим остаткам предупреждений нет.')),
      for (final row in rows) ...[
        OwnerCard(child: ListTile(
          leading: const Icon(Icons.warning_amber_outlined,
              color: OwnerPalette.warning),
          title: Text(row['productName'].toString()),
          subtitle: Text('${row['storeName'] ?? ''} • '
              '${row['quantity'] ?? '—'} ${row['unit'] ?? ''}'),
        )),
        const SizedBox(height: 8),
      ],
      _source(context),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final owner = OwnerScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(OwnerL10n.tr(owner.language, widget.title),
            style: const TextStyle(fontSize: 17)),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: OwnerScreenFrame(children: [
        const OwnerRestaurantPicker(),
        const SizedBox(height: 12),
        if (widget.kind != 'inventory' && widget.kind != 'notifications')
          const OwnerPeriodPicker(),
        const SizedBox(height: 14),
        if (loading)
          const OwnerCard(child: Padding(
            padding: EdgeInsets.all(22),
            child: Center(child: CircularProgressIndicator()),
          ))
        else if (error != null)
          OwnerCard(child: Column(children: [
            const Icon(Icons.cloud_off_outlined, size: 30,
                color: OwnerPalette.error),
            const SizedBox(height: 9),
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: _load,
                icon: const Icon(Icons.refresh), label: const Text('Повторить')),
          ]))
        else if (data != null)
          if (widget.kind == 'inventory') _inventoryView(context)
          else if (widget.kind == 'notifications') _notificationsView(context)
          else if (widget.kind == 'orders') _ordersView(context)
          else if (widget.kind == 'movements') _movementsView(context)
          else if (widget.kind == 'pnl') _pnlView(context)
          else _olapView(context, owner),
      ]),
    );
  }
}

class OwnerLiveProductScreen extends StatelessWidget {
  final Map<String,dynamic> row;
  final String asOf;
  const OwnerLiveProductScreen({
    super.key, required this.row, required this.asOf,
  });

  @override
  Widget build(BuildContext context) {
    String money(dynamic n) =>
        n is num ? '${n.toStringAsFixed(2)} AZN' : '—';
    return Scaffold(
      appBar: AppBar(title: Text(row['productName'].toString())),
      body: OwnerScreenFrame(children: [
        OwnerHeading(row['productName'].toString(),
          caption: row['categoryName']?.toString() ?? ''),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OwnerMetric('Остаток',
              '${row['quantity'] ?? '—'} ${row['unit'] ?? ''}')),
          const SizedBox(width: 10),
          Expanded(child: OwnerMetric('Стоимость', money(row['value']))),
        ]),
        const SizedBox(height: 12),
        OwnerCard(child: Column(children: [
          ListTile(title: const Text('Склад'),
              trailing: Text(row['storeName'].toString())),
          const Divider(height: 1),
          ListTile(title: const Text('Себестоимость'),
              trailing: Text(money(row['unitCost']))),
          const Divider(height: 1),
          ListTile(title: const Text('Срез на дату'),
              trailing: Text(asOf)),
        ])),
      ]),
    );
  }
}

class OwnerLiveOrderScreen extends StatelessWidget {
  final Map<String,dynamic> order;
  const OwnerLiveOrderScreen({super.key,required this.order});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Чек ${order['number']}')),
    body: OwnerScreenFrame(children: [
      OwnerHeading('Чек ${order['number']}',
          caption: 'Данные SH OLAP только для просмотра'),
      const SizedBox(height: 12),
      OwnerCard(child: Column(children: [
        ListTile(title: const Text('Дата'),
            trailing: Text('${order['date'] ?? '—'}')),
        const Divider(height: 1),
        ListTile(title: const Text('Стол'),
            trailing: Text('${order['table'] ?? '—'}')),
        const Divider(height: 1),
        ListTile(title: const Text('Официант'),
            trailing: Text('${order['waiter'] ?? '—'}')),
        const Divider(height: 1),
        ListTile(title: const Text('Сумма'),
            trailing: Text(order['amount'] is num
                ? '${(order['amount'] as num).toStringAsFixed(2)} AZN'
                : '—')),
      ])),
      const SizedBox(height: 12),
      const OwnerCard(child: Text('Состав чека и разделение оплат '
          'пока не предоставлены источником SH OLAP. '
          'Они не подменяются демонстрационными позициями.')),
    ]),
  );
}
