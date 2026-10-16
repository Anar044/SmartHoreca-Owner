import 'package:flutter/material.dart';
import '../ui/owner_text.dart';

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

  @override
  void initState() {
    super.initState();
    // The revenue-card drill-down should immediately show registers and
    // payment methods, rather than hiding payment details behind a chart toggle.
    table = widget.kind == 'cash';
  }

  static String _fmt(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Map<String, String> _dates(OwnerState state) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (state.period == 'Период' &&
        state.customFrom != null && state.customTo != null) {
      return {
        'from': _fmt(state.customFrom!),
        'to': _fmt(state.customTo!),
      };
    }
    final end = state.period == 'Вчера'
        ? today.subtract(const Duration(days: 1)) : today;
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
    final key = '${state.workspaceId}|${ids.join(',')}|${state.period}|'
        '${state.customFrom?.toIso8601String() ?? ''}|'
        '${state.customTo?.toIso8601String() ?? ''}|${widget.kind}';
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
        'orders' => {...dates,
          if (owner.period == 'Сегодня') 'mode': 'operational'},
        _ => dates,
      };
      final endpoint = switch (widget.kind) {
        'inventory' => '/api/mobile/v1/inventory',
        'notifications' => '/api/mobile/v1/alerts',
        'orders' => '/api/mobile/v1/orders',
        'movements' => '/api/mobile/v1/movements',
        'pnl' => '/api/mobile/v1/pnl',
        _ => '/api/mobile/v1/report',
      };
      final args = widget.kind == 'inventory' || widget.kind == 'orders' ||
          widget.kind == 'notifications' || widget.kind == 'movements' ||
          widget.kind == 'pnl'
          ? query
          : {...query, 'kind': widget.kind,
              // "Today" sales match the dashboard cash-shift operating day.
              // Historical periods and accounting P&L remain calendar based.
              if (owner.period == 'Сегодня') 'mode': 'operational'};
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
    final nestedCash = widget.kind == 'cash' &&
        data?['secondaryField'] != null;
    final groupTotals = <String, double>{};
    if (nestedCash) {
      for (final row in rows) {
        final group = row['group']?.toString() ?? '—';
        groupTotals[group] = (groupTotals[group] ?? 0) +
            ((row['value'] as num?)?.toDouble() ?? 0);
      }
    }
    final chartRows = nestedCash
        ? groupTotals.entries.map((e) =>
            <String,dynamic>{'label':e.key,'value':e.value}).toList()
        : rows;
    final opValue = data?['operatingDay'];
    final operating = data?['mode'] == 'operational' && opValue is Map
        ? opValue : null;
    return Column(children: [
      if (operating != null) ...[
        OwnerCard(child: Row(children: [
          const Icon(Icons.schedule, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(
            'Операционный день: ${operating['from']} — ${operating['to']} · '
            '${operating['activeShiftCount']} открытых смен',
            style: const TextStyle(fontSize: 12),
          )),
        ])),
        const SizedBox(height: 12),
      ],
      Row(children: [
        Expanded(child: OwnerMetric('Позиций', '${data?['count'] ?? rows.length}')),
        const SizedBox(width: 10),
        Expanded(child: OwnerMetric('Всего',
          _money(data?['totalValue']))),
      ]),
      const SizedBox(height: 12),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: OwnerText('График'),
              icon: Icon(Icons.bar_chart)),
          ButtonSegment(value: true, label: OwnerText('Таблица'),
              icon: Icon(Icons.table_chart_outlined)),
        ],
        selected: {table},
        onSelectionChanged: (v) => setState(() => table = v.first),
      ),
      const SizedBox(height: 12),
      if (rows.isEmpty)
        const OwnerCard(child: OwnerText('Нет данных для выбранного периода.'))
      else if (!table)
        OwnerCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(OwnerL10n.tr(state.language, widget.title),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 13),
            OwnerRevenueDiagram(
              labelWidth: 112,
              values: chartRows.take(16).map((r) =>
                  (r['value'] as num?)?.toDouble() ?? 0).toList(),
              labels: chartRows.take(16).map((r) =>
                  (r['label'] ?? '—').toString()).toList(),
              valueLabels: chartRows.take(16).map((r) =>
                  (r['value'] as num?)?.toStringAsFixed(2) ?? '—').toList(),
            ),
            if (chartRows.length > 16) ...[
              const SizedBox(height: 8),
              Text('Показаны первые 16 позиций из ${chartRows.length}. '
                'Полный список доступен во вкладке «Таблица».',
                style: TextStyle(color: OwnerPalette.muted(context),
                  fontSize: 11)),
            ],
          ],
        ))
      else if (nestedCash) ...[
        OwnerHeading(widget.kind == 'cash'
          ? 'Касса → Способ оплаты' : 'Касса → Блюдо'),
        const SizedBox(height:8),
        for (final group in groupTotals.entries) ...[
          OwnerCard(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(group.key,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: Text(_money(group.value),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              for (final row in rows.where(
                  (row) => row['group']?.toString() == group.key))
                Padding(
                  padding: const EdgeInsets.only(left: 22),
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(row['label'].toString()),
                    trailing: Text(_money(row['value'])),
                  ),
                ),
            ],
          )),
          const SizedBox(height: 8),
        ],
      ]
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
        const OwnerText('Показана часть строк. Для полного отчёта используйте веб-систему.'),
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
          const DropdownMenuItem(value: '', child: OwnerText('Все склады')),
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
        const OwnerCard(child: OwnerText('Нет складских позиций по фильтрам.'))
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
            label: const OwnerText('Загрузить ещё товары'),
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
        const OwnerCard(child: OwnerText('Нет чеков за выбранный период.')),
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
                Text('${OwnerL10n.tr(OwnerScope.of(context).language, 'Чек')} ${order['number']}',
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
        const OwnerText('В приложении показаны первые 500 чеков.'),
      _source(context),
    ]);
  }

  Widget _movementsView(BuildContext context) {
    final rows = (data?['rows'] as List? ?? [])
        .whereType<Map<String,dynamic>>().toList();
    final summary = data?['summary'] as Map? ?? {};
    final sourceStatus = data?['sourceStatus'] as Map? ?? {};
    final missing = (data?['missingSources'] as List? ?? [])
        .map((v) => v.toString()).toList();
    const sourceNames = <String, String>{
      'incoming': 'приход',
      'outgoing': 'расход',
      'writeoff': 'списание',
      'transfer': 'перемещение',
      'inventory': 'инвентаризация',
    };
    final names = missing.map((v) => sourceNames[v] ?? v).join(', ');
    return Column(children: [
      if (data?['partial'] == true) ...[
        OwnerCard(child: Row(children: [
          const Icon(Icons.warning_amber_rounded,
            color: OwnerPalette.warning),
          const SizedBox(width: 10),
          Expanded(child: Text(
            'Данные неполные. Не удалось проверить некоторые источники'
            '${names.isNotEmpty ? ': $names' : ''}. '
            'Показаны только подтверждённые движения; '
            'итоги периода могут быть неполными.',
            style: const TextStyle(fontSize: 12),
          )),
        ])),
        const SizedBox(height: 10),
      ],
      OwnerCard(child: ListTile(
        title: const OwnerText('Движение товаров'),
        subtitle: Text('Проверено источников: ${sourceStatus.values.whereType<Map>().where((s)=>s['ok']==true).length} из ${sourceStatus.length}'),
        trailing: Text('${data?['count'] ?? rows.length}'),
      )),
      const SizedBox(height:10),
      Row(children:[
        Expanded(child:OwnerMetric('Приход',_money(summary['incoming']))),
        const SizedBox(width:8),
        Expanded(child:OwnerMetric('Расход',_money(summary['outgoing']))),
      ]),
      const SizedBox(height:8),
      Row(children:[
        Expanded(child:OwnerMetric('Списание',_money(summary['writeoff']))),
        const SizedBox(width:8),
        Expanded(child:OwnerMetric('Перемещение',_money(summary['transfer']))),
      ]),
      const SizedBox(height:8),
      OwnerMetric('Инвентаризация',_money(summary['inventory'])),
      const SizedBox(height:10),
      if(sourceStatus.isNotEmpty)
        OwnerCard(child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            const OwnerText('Источники документов',
              style:TextStyle(fontWeight:FontWeight.w700)),
            const SizedBox(height:6),
            for(final entry in sourceStatus.entries)
              Padding(
                padding:const EdgeInsets.symmetric(vertical:3),
                child:Row(children:[
                  Icon(entry.value is Map && entry.value['ok']==true
                    ?Icons.check_circle_outline:Icons.error_outline,
                    size:17,color:entry.value is Map && entry.value['ok']==true
                      ?OwnerPalette.green:OwnerPalette.warning),
                  const SizedBox(width:7),
                  Expanded(child:Text('${sourceNames[entry.key.toString()] ?? entry.key}')),
                  Text(entry.value is Map
                    ?'${entry.value['count'] ?? 0} движ.'
                    :'—'),
                ]),
              ),
          ],
        )),
      const SizedBox(height:10),
      if (rows.isEmpty) const OwnerCard(child: OwnerText('Движений за период нет.')),
      for (final row in rows) ...[
        OwnerCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(row['productName'].toString(),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${row['date'] ?? ''} • Документ ${row['documentNumber'] ?? '—'}'),
            Text(row['type'] == 'transfer' &&
              ((row['fromStoreName'] ?? '').toString().isNotEmpty ||
               (row['toStoreName'] ?? '').toString().isNotEmpty)
              ?'Перемещение: ${row['fromStoreName'] ?? '—'} → ${row['toStoreName'] ?? '—'}'
              :' ${row['label'] ?? sourceNames[row['type']?.toString()] ?? row['type'] ?? ''} • ${row['storeName'] ?? ''}'),
            if((row['status'] ?? '').toString().isNotEmpty)
              Text('Статус: ${row['status']}',
                style:TextStyle(fontSize:11,color:OwnerPalette.muted(context))),
            if((row['comment'] ?? '').toString().isNotEmpty)
              Text(row['comment'].toString(),
                style:TextStyle(fontSize:11,color:OwnerPalette.muted(context))),
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

  Widget _discountsView(BuildContext context) {
    final discounts=(data?['discounts'] as List? ?? [])
      .whereType<Map<String,dynamic>>()
      .where((row)=>row['value'] is num && row['value'] != 0).toList();
    final surcharges=(data?['surcharges'] as List? ?? [])
      .whereType<Map<String,dynamic>>()
      .where((row)=>row['value'] is num && row['value'] != 0).toList();
    final discountTotal=data?['discountTotal'];
    final surchargeTotal=data?['surchargeTotal'];
    final showDiscountTotal=discountTotal is num && discountTotal != 0;
    final showSurchargeTotal=surchargeTotal is num && surchargeTotal != 0;

    Widget section(String title,List<Map<String,dynamic>> rows,
        bool available,String? reason,bool byRestaurant,bool byRegister) {
      final caption=byRegister
        ?'Разбивка по кассам'
        :byRestaurant
          ?'Разбивка по ресторанам: тип не передан SH OLAP'
          :'Разбивка по типам из SH OLAP';
      return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        OwnerHeading(title,caption:caption),
        const SizedBox(height:8),
        if(!available)
          OwnerCard(child:Text(reason ?? 'Источник не предоставил этот показатель.'))
        else if(rows.isEmpty)
          const OwnerCard(child:OwnerText('Нет данных за выбранный период.'))
        else for(final row in rows) ...[
          OwnerCard(child:ListTile(
            contentPadding:EdgeInsets.zero,
            title:Text((row['registerName'] ?? row['label'] ?? '—').toString()),
            subtitle:row['registerName'] != null &&
                (row['group'] ?? '').toString().isNotEmpty &&
                row['group'].toString() != row['registerName'].toString()
              ?Text(row['group'].toString())
              :null,
            trailing:Text(_money(row['value']),
              style:const TextStyle(fontWeight:FontWeight.w700)),
          )),
          const SizedBox(height:7),
        ],
        const SizedBox(height:8),
      ]);
    }
    return Column(children:[
      if(showDiscountTotal && showSurchargeTotal) ...[
        Row(children:[
          Expanded(child:OwnerMetric('Сумма скидок',_money(discountTotal))),
          const SizedBox(width:10),
          Expanded(child:OwnerMetric('Сумма надбавок',_money(surchargeTotal))),
        ]),
        const SizedBox(height:15),
      ] else if(showDiscountTotal) ...[
        OwnerMetric('Сумма скидок',_money(discountTotal)),
        const SizedBox(height:15),
      ] else if(showSurchargeTotal) ...[
        OwnerMetric('Сумма надбавок',_money(surchargeTotal)),
        const SizedBox(height:15),
      ],
      if(data?['partial']==true) ...[
        const OwnerCard(child:Row(children:[
          Icon(Icons.info_outline,color:OwnerPalette.warning),
          SizedBox(width:9),
          Expanded(child:OwnerText(
            'SH OLAP не предоставил один из показателей. '
            'Отсутствующая сумма не заменяется нулём.')),
        ])),
        const SizedBox(height:14),
      ],
      section('Скидки гостям',discounts,
        data?['discountAvailable']==true,
        data?['discountUnavailableReason']?.toString(),
        data?['discountByRestaurant']==true,
        data?['discountByRegister']==true),
      section('Надбавки',surcharges,
        data?['surchargeAvailable']==true,
        data?['surchargeUnavailableReason']?.toString(),
        data?['surchargeByRestaurant']==true,
        data?['surchargeByRegister']==true),
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
      const OwnerCard(child: OwnerText('Текущие складские предупреждения. Push-уведомления ещё не подключены.')),
      const SizedBox(height: 12),
      if (rows.isEmpty)
        const OwnerCard(child: OwnerText('По текущим остаткам предупреждений нет.')),
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
      body: OwnerScreenFrame(onRefresh: _load, children: [
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
                icon: const Icon(Icons.refresh), label: const OwnerText('Повторить')),
          ]))
        else if (data != null)
          if (widget.kind == 'inventory') _inventoryView(context)
          else if (widget.kind == 'notifications') _notificationsView(context)
          else if (widget.kind == 'orders') _ordersView(context)
          else if (widget.kind == 'movements') _movementsView(context)
          else if (widget.kind == 'pnl') _pnlView(context)
          else if (widget.kind == 'discounts') _discountsView(context)
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
          ListTile(title: const OwnerText('Склад'),
              trailing: Text(row['storeName'].toString())),
          const Divider(height: 1),
          ListTile(title: const OwnerText('Себестоимость'),
              trailing: Text(money(row['unitCost']))),
          const Divider(height: 1),
          ListTile(title: const OwnerText('Срез на дату'),
              trailing: Text(asOf)),
        ])),
      ]),
    );
  }
}

class OwnerLiveOrderScreen extends StatefulWidget {
  final Map<String,dynamic> order;
  const OwnerLiveOrderScreen({super.key,required this.order});
  @override
  State<OwnerLiveOrderScreen> createState() => _OwnerLiveOrderScreenState();
}

class _OwnerLiveOrderScreenState extends State<OwnerLiveOrderScreen> {
  Map<String,dynamic>? details;
  String? error;
  bool loading = false;

  @override
  void initState(){
    super.initState();
    if(widget.order['detailsAvailable'] == true){
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if(mounted) _load();
      });
    }
  }

  Future<void> _load() async {
    final owner=OwnerScope.of(context);
    setState((){loading=true;error=null;details=null;});
    try{
      final result=await OwnerBackend.getJson('/api/mobile/v1/receipt',
        workspaceId:owner.workspaceId,
        departmentIds:owner.selectedRestaurantIds,
        query:{
          'number':widget.order['number'].toString(),
          'date':widget.order['date'].toString(),
          'departmentId':widget.order['departmentId'].toString(),
          if((widget.order['shiftId'] ?? '').toString().isNotEmpty)
            'shiftId':widget.order['shiftId'].toString(),
          if((widget.order['orderId'] ?? '').toString().isNotEmpty)
            'orderId':widget.order['orderId'].toString(),
        });
      if(!mounted)return;
      setState((){loading=false;details=result;});
    }catch(e){
      if(!mounted)return;
      setState((){loading=false;error=e is OwnerApiException
        ? '${e.message} (${e.code})' : 'Не удалось получить состав чека.';});
    }
  }

  String money(dynamic value)=>value is num
      ? '${value.toStringAsFixed(2)} AZN' : '—';

  @override
  Widget build(BuildContext context){
    final order=widget.order;
    final lineItems=(details?['positions'] as List? ?? [])
      .whereType<Map<String,dynamic>>().toList();
    return Scaffold(
      appBar: AppBar(title: Text('${OwnerL10n.tr(OwnerScope.of(context).language, 'Чек')} ${order['number']}')),
      body: OwnerScreenFrame(onRefresh: _load, children: [
        OwnerHeading('${OwnerL10n.tr(OwnerScope.of(context).language, 'Чек')} ${order['number']}',
          caption:'Данные SH OLAP только для просмотра'),
        const SizedBox(height:12),
        OwnerCard(child:Column(children:[
          ListTile(title:const OwnerText('Дата'),
            trailing:Text('${order['date'] ?? '—'}')),
          const Divider(height:1),
          ListTile(title:const OwnerText('Стол'),
            trailing:Text((order['table'] ?? details?['table'] ?? '—').toString())),
          const Divider(height:1),
          ListTile(title:const OwnerText('Официант'),
            trailing:Text((order['waiter'] ?? details?['waiter'] ?? '—').toString())),
          const Divider(height:1),
          ListTile(title:const OwnerText('Скидка'),
            trailing:Text(money(order['discountAmount']))),
          const Divider(height:1),
          ListTile(title:const OwnerText('Надбавка'),
            trailing:Text(money(order['surchargeAmount']))),
          const Divider(height:1),
          ListTile(title:const OwnerText('Сумма'),
            trailing:Text(money(order['amount']))),
        ])),
        const SizedBox(height:12),
        if(order['detailsAvailable'] != true)
          const OwnerCard(child:OwnerText(
            'SH OLAP не предоставил уникальный идентификатор чека '
            'или кассовой смены. Состав заказа нельзя показать достоверно.'))
        else if(loading)
          const OwnerCard(child:Padding(
            padding:EdgeInsets.all(24),
            child:Center(child:CircularProgressIndicator())))
        else if(error != null)
          OwnerCard(child:Column(children:[
            Text(error!,textAlign:TextAlign.center),
            const SizedBox(height:10),
            FilledButton.tonalIcon(onPressed:_load,
              icon:const Icon(Icons.refresh),
              label:const OwnerText('Повторить')),
          ]))
        else if(details != null) ...[
          const OwnerHeading('Состав чека',
            caption:'Фактические блюда из SH OLAP'),
          const SizedBox(height:10),
          for(final item in lineItems)
            Padding(
              padding:const EdgeInsets.only(bottom:8),
              child:OwnerCard(child:Row(children:[
                Expanded(child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    Text((item['name'] ?? '—').toString(),
                      style:const TextStyle(fontWeight:FontWeight.w600)),
                    if(item['quantity'] is num)
                      Text('${item['quantity']} шт.',
                        style:TextStyle(fontSize:12,
                          color:OwnerPalette.muted(context))),
                  ],
                )),
                const SizedBox(width:8),
                Text(money(item['amount']),
                  style:const TextStyle(fontWeight:FontWeight.w600)),
              ])),
            ),
          OwnerCard(child:ListTile(
            title:const OwnerText('Сумма позиций'),
            trailing:Text(money(details?['itemsTotal'])))),
          const SizedBox(height:12),
          const OwnerHeading('Способы оплаты'),
          const SizedBox(height:8),
          if(details?['paymentsAvailable'] == true)
            for(final payment in (details?['payments'] as List? ?? [])
                .whereType<Map<String,dynamic>>()) ...[
              OwnerCard(child:ListTile(
                contentPadding:EdgeInsets.zero,
                title:Text((payment['name'] ?? '—').toString()),
                trailing:Text(money(payment['amount']),
                  style:const TextStyle(fontWeight:FontWeight.w700)),
              )),
              const SizedBox(height:7),
            ]
          else
            OwnerCard(child:Text((details?['paymentNote'] ??
              'Способы оплаты не подтверждены SH Server.').toString())),
        ],
      ]),
    );
  }
}

/// Detailed order opened directly from the selected live POS register.
class OwnerLivePosOrderScreen extends StatefulWidget {
  final Map<String,dynamic> order;
  final String pluginId;
  final String departmentId;
  final String restaurant;
  final String registerName;
  const OwnerLivePosOrderScreen({
    super.key, required this.order, required this.pluginId,
    required this.departmentId, required this.restaurant,
    required this.registerName,
  });

  @override
  State<OwnerLivePosOrderScreen> createState() => _OwnerLivePosOrderScreenState();
}

class _OwnerLivePosOrderScreenState extends State<OwnerLivePosOrderScreen> {
  Map<String,dynamic>? details;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  String _raw(dynamic value) => (value ?? '').toString().trim();

  String _time(dynamic value) {
    final raw = _raw(value);
    if (raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final date = parsed.toLocal();
    return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
  }

  String _money(dynamic value) =>
    value is num ? '${value.toStringAsFixed(2)} AZN' : '—';

  Future<void> _load() async {
    final owner=OwnerScope.of(context);
    final workspace=owner.workspaceId;
    if (workspace == null || widget.pluginId.isEmpty ||
        widget.departmentId.isEmpty) {
      setState(() {
        loading=false;
        error='Не удалось подтвердить кассу и ресторан выбранного заказа.';
      });
      return;
    }
    setState(() {loading=true;error=null;details=null;});
    final order=widget.order;
    final query=<String,String>{
      'pluginId':widget.pluginId,
      'orderNum':_raw(order['number']),
      'departmentId':widget.departmentId,
      'registerName':widget.registerName,
      for (final key in ['status','table','floor','waiter','cashier','openedAt',
          'billAt','closedAt'])
        if (_raw(order[key]).isNotEmpty) key:_raw(order[key]),
      if (order['amount'] is num) 'amount':order['amount'].toString(),
      if (order['discountAmount'] is num)
        'discountAmount':order['discountAmount'].toString(),
      if (order['surchargeAmount'] is num)
        'surchargeAmount':order['surchargeAmount'].toString(),
    };
    try {
      final result=await OwnerBackend.getJson(
        '/api/mobile/v1/cash-order',
        workspaceId:workspace,
        departmentIds:owner.selectedRestaurantIds,
        query:query,
        retryTransient:false, // do not requery a slow POS order automatically
      );
      if(!mounted)return;
      setState(() {loading=false;details=result;});
    } catch(e) {
      if(!mounted)return;
      setState(() {
        loading=false;
        error=e is OwnerApiException
          ?'${e.message} (${e.code})'
          :'Не удалось загрузить информацию о заказе.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final order=details ?? widget.order;
    final items=(details?['items'] as List? ?? [])
      .whereType<Map<String,dynamic>>().toList();
    final payments=(details?['payments'] as List? ?? [])
      .whereType<Map<String,dynamic>>().toList();
    final openedAt=_time(order['openedAt']);
    final closedAt=_time(order['closedAt']);
    final status=_raw(order['status']).toUpperCase();
    final info=<MapEntry<String,String>>[
      MapEntry('Статус',_raw(order['status'])),
      MapEntry('Время открытия',openedAt.isEmpty?'—':openedAt),
      MapEntry('Ресторан',widget.restaurant),
      MapEntry('Касса',widget.registerName),
      MapEntry('Зал',_raw(order['floor'])),
      MapEntry('Стол',_raw(order['table'])),
      MapEntry('Официант',_raw(order['waiter'])),
      MapEntry('Кассир',_raw(order['cashier'])),
      MapEntry('Выставлен счёт',_time(order['billAt'])),
      if(order['discountAmount'] is num && order['discountAmount'] != 0)
        MapEntry('Скидка',_money(order['discountAmount'])),
      if(order['surchargeAmount'] is num && order['surchargeAmount'] != 0)
        MapEntry('Надбавка',_money(order['surchargeAmount'])),
      if(order['amount'] is num) MapEntry('Итого',_money(order['amount'])),
      MapEntry('Время закрытия',
        closedAt.isEmpty ? (status=='OPEN'?'Ещё открыт':'—') : closedAt),
    ].where((entry)=>entry.value.trim().isNotEmpty).toList();
    final title='Заказ №${widget.order['number']}';
    return Scaffold(
      appBar:AppBar(title:Text(title,style:const TextStyle(fontSize:17))),
      body:OwnerScreenFrame(onRefresh:_load,children:[
        OwnerHeading(title,caption:'${widget.restaurant} • ${widget.registerName}'),
        const SizedBox(height:12),
        if(loading)
          const OwnerCard(child:Padding(
            padding:EdgeInsets.all(24),
            child:Center(child:CircularProgressIndicator()))),
        if(error!=null)
          OwnerCard(child:Column(children:[
            Text(error!,textAlign:TextAlign.center),
            const SizedBox(height:10),
            FilledButton.tonalIcon(onPressed:_load,
              icon:const Icon(Icons.refresh),
              label:const OwnerText('Повторить')),
          ])),
        if(!loading && error==null && details!=null) ...[
          OwnerCard(child:Column(children:[
            for(var i=0;i<info.length;i++) ...[
              ListTile(
                dense:true,
                contentPadding:EdgeInsets.zero,
                title:OwnerText(info[i].key),
                trailing:SizedBox(
                  width:190,
                  child:Text(info[i].value,textAlign:TextAlign.end,
                    style:const TextStyle(fontWeight:FontWeight.w600)),
                ),
              ),
              if(i<info.length-1) const Divider(height:1),
            ],
          ])),
          const SizedBox(height:14),
          const OwnerHeading('Состав заказа'),
          const SizedBox(height:9),
          if(items.isEmpty)
            const OwnerCard(child:OwnerText(
              'Касса не предоставила позиции этого заказа. Обновите экран или проверьте доступность детализации в POS.')),
          for(final item in items) ...[
            OwnerCard(child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Text((item['name']??'Без названия').toString(),
                  style:const TextStyle(fontWeight:FontWeight.w700)),
                const SizedBox(height:6),
                Row(children:[
                  Expanded(child:Text(
                    'Кол-во: ${item['quantity'] ?? '—'}'
                    '${item['price'] is num ? ' · Цена: ${_money(item['price'])}' : ''}',
                    style:TextStyle(color:OwnerPalette.muted(context),fontSize:12))),
                  Text(_money(item['amount']),
                    style:const TextStyle(fontWeight:FontWeight.w700)),
                ]),
                if((item['status']??'').toString().isNotEmpty)
                  Text('Статус позиции: ${item['status']}',
                    style:TextStyle(color:OwnerPalette.muted(context),fontSize:11)),
                for(final modifier in (item['modifiers'] as List? ?? [])
                    .whereType<Map<String,dynamic>>())
                  Padding(
                    padding:const EdgeInsets.only(top:4,left:8),
                    child:Text('+ ${modifier['name']} × ${modifier['quantity'] ?? 1}',
                      style:TextStyle(color:OwnerPalette.muted(context),fontSize:12)),
                  ),
              ],
            )),
            const SizedBox(height:8),
          ],
          if(payments.isNotEmpty) ...[
            const SizedBox(height:6),
            const OwnerHeading('Способы оплаты'),
            const SizedBox(height:8),
            for(final payment in payments) ...[
              OwnerCard(child:ListTile(
                contentPadding:EdgeInsets.zero,
                title:Text((payment['name']??'—').toString()),
                trailing:Text(_money(payment['amount']),
                  style:const TextStyle(fontWeight:FontWeight.w700)),
              )),
              const SizedBox(height:7),
            ],
          ],
        ],
      ]),
    );
  }
}
