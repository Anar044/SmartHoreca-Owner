import 'package:flutter/material.dart';
import '../core/owner_backend.dart';
import '../core/owner_state.dart';
import '../core/owner_theme.dart';
import '../ui/owner_components.dart';
import '../ui/owner_text.dart';
import 'owner_live_reports.dart';

/// POS operational cash status: uses /api/mobile/v1/cash, the same source as
/// the website's /cash, not iiko cash-shift history.
class OwnerLiveCashScreen extends StatefulWidget {
  const OwnerLiveCashScreen({super.key});
  @override
  State<OwnerLiveCashScreen> createState() => _OwnerLiveCashScreenState();
}

class _OwnerLiveCashScreenState extends State<OwnerLiveCashScreen> {
  String scope = '';
  int generation = 0;
  bool loading = true;
  String? error;
  Map<String, dynamic>? data;
  String filter = 'Все';
  String search = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final owner = OwnerScope.of(context);
    final ids = owner.selectedRestaurantIds.toList()..sort();
    final key = '${owner.workspaceId}:${ids.join(',')}';
    if (key != scope) {
      scope = key;
      // Never show figures from a different organization or restaurant
      // selection while the next scoped request is loading.
      data = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _load() async {
    final owner = OwnerScope.of(context);
    final workspace = owner.workspaceId;
    final ids = owner.selectedRestaurantIds;
    if (workspace == null || ids.isEmpty) {
      setState(() { loading = false; error = 'Выберите рестораны.'; data = null; });
      return;
    }
    final seq = ++generation;
    // Retain the last verified snapshot during a manual refresh. It is only
    // retained for the same selected restaurant scope.
    setState(() { loading = true; error = null; });
    try {
      final payload = await OwnerBackend.getJson('/api/mobile/v1/cash',
        workspaceId: workspace, departmentIds: ids,
        retryTransient: false); // fail promptly instead of tripling POS load
      if (!mounted || seq != generation) return;
      setState(() { loading = false; data = payload; });
    } catch (e) {
      if (!mounted || seq != generation) return;
      setState(() { loading = false;
        error = e is OwnerApiException
          ? '${e.message} (${e.code})'
          : 'Не удалось загрузить кассы.';
      });
    }
  }

  static String money(dynamic value) =>
      value is num ? '${value.toStringAsFixed(2)} AZN' : '—';

  @override
  Widget build(BuildContext context) {
    final state = OwnerScope.of(context);
    final registers = (data?['registers'] as List? ?? [])
      .whereType<Map<String, dynamic>>().toList();
    final partial = data?['partial'] == true;
    final totals = (data?['totals'] as Map?) ??
        (data?['availableTotals'] as Map?) ?? {};
    final coverageSuffix = partial ? ' (доступные кассы)' : '';
    final restaurants = <String,String>{
      for (final entry in state.restaurantIdsByName.entries)
        entry.value: entry.key
    };
    return OwnerScreenFrame(onRefresh: _load, children: [
      const OwnerHeading('Кассы', caption: 'Оперативные заказы подключённых касс'),
      const SizedBox(height: 12),
      const OwnerRestaurantPicker(),
      const SizedBox(height: 12),
      if (loading && data == null)
        const OwnerCard(child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(children: [
            Center(child: CircularProgressIndicator()),
            SizedBox(height: 10),
            Text('Получаем данные подключённых касс…'),
          ]),
        ))
      else if (error != null && data == null)
        OwnerCard(child: Column(children: [
          const Icon(Icons.cloud_off_outlined, size: 30,
            color: OwnerPalette.error),
          const SizedBox(height: 12),
          Text(error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(onPressed: _load,
            icon: const Icon(Icons.refresh), label: const OwnerText('Повторить')),
        ]))
      else ...[
        if (loading) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          const Text('Обновляем данные подключённых касс…',
            style: TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
        ],
        if (error != null) ...[
          const OwnerCard(child: Text('Не удалось обновить данные. '
            'Ниже оставлены результаты последнего успешного запроса.',
            style: TextStyle(color: OwnerPalette.warning))),
          const SizedBox(height: 12),
        ],
        if (data?['partial'] == true) ...[
          OwnerCard(child: Row(children: [
            const Icon(Icons.warning_amber_rounded,
              color: OwnerPalette.warning),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'Это не сводный отчёт по всей сети: '
              '${(data?['missingDepartmentIds'] as List? ?? []).isNotEmpty ? 'у некоторых выбранных ресторанов нет подключённой POS-кассы. ' : ''}'
              '${(data?['unavailableRegisters'] as List? ?? []).isNotEmpty ? 'Некоторые кассы не ответили. ' : ''}'
              'Ниже показаны только доступные кассы. '
              'Продажи всей сети смотрите на главной (SH OLAP).',
              style: const TextStyle(fontSize: 12),
            )),
          ])),
          const SizedBox(height: 12),
        ],
        Row(children: [
          Expanded(child: OwnerMetric('Закрытые$coverageSuffix',
            money(totals['closedSum']))),
          const SizedBox(width: 10),
          Expanded(child: OwnerMetric('Открытые$coverageSuffix',
            money(totals['openSum']))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OwnerMetric('Ожидаемая выручка$coverageSuffix',
            money(totals['expectedSum']))),
          const SizedBox(width: 10),
          Expanded(child: OwnerMetric('Всего заказов$coverageSuffix',
            (totals['totalOrders'] ?? '—').toString())),
        ]),
        const SizedBox(height: 13),
        Row(children: [
          Expanded(child: Text('${registers.length} касс онлайн',
            style: const TextStyle(fontWeight: FontWeight.bold))),
          TextButton.icon(onPressed: _load,
            icon: const Icon(Icons.refresh), label: const OwnerText('Обновить')),
        ]),
        const SizedBox(height: 9),
        for (final register in registers) ...[
          OwnerCard(
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(
              builder: (_) => _RegisterDetail(
                register: register,
                restaurant: restaurants[register['departmentId']?.toString()]
                  ?? 'Ресторан',
              ))),
            child: Row(children: [
              Icon(Icons.point_of_sale_outlined,
                color: OwnerPalette.accent(context)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((register['name'] ?? 'Касса').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(restaurants[register['departmentId']?.toString()] ?? '—',
                    style: TextStyle(fontSize: 12,
                      color: OwnerPalette.muted(context))),
                  const Text('● Онлайн',
                    style: TextStyle(fontSize: 11,
                      color: OwnerPalette.green)),
                ],
              )),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(money((register['totals'] as Map?)?['expectedSum']),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${(register['totals'] as Map?)?['totalOrders'] ?? 0} заказов',
                  style: TextStyle(fontSize: 11,
                    color: OwnerPalette.muted(context))),
              ]),
              const Icon(Icons.chevron_right),
            ]),
          ),
          const SizedBox(height: 9),
        ],
        for (final item in (data?['unavailableRegisters'] as List? ?? [])
            .whereType<Map<String, dynamic>>()) ...[
          OwnerCard(child: Row(children: [
            const Icon(Icons.warning_amber_outlined,
              color: OwnerPalette.warning),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((item['name'] ?? 'Касса').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('Нет ответа от кассы · ${restaurants[item['departmentId']?.toString()] ?? 'Ресторан'}',
                  style: const TextStyle(fontSize: 12)),
              ],
            )),
          ])),
          const SizedBox(height: 9),
        ],
        Text('Источник: ${data?['source'] ?? 'SH POS Plugin'}',
          style: TextStyle(fontSize: 11, color: OwnerPalette.muted(context))),
      ],
    ]);
  }
}

class _RegisterDetail extends StatefulWidget {
  final Map<String, dynamic> register;
  final String restaurant;
  const _RegisterDetail({required this.register, required this.restaurant});
  @override
  State<_RegisterDetail> createState() => _RegisterDetailState();
}

class _RegisterDetailState extends State<_RegisterDetail> {
  String filter = 'Все';
  String search = '';

  String _time(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final date = parsed.toLocal();
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.register['name'] ?? 'Касса').toString();
    final orders = (widget.register['orders'] as List? ?? [])
      .whereType<Map<String, dynamic>>().where((row) {
        if (filter != 'Все' && row['status'] != filter) return false;
        if (search.isEmpty) return true;
        return [
          row['number'], row['waiter'], row['cashier'], row['table'],
          row['floor'], row['openedAt'], row['closedAt']
        ].any((v) => v.toString().toLowerCase().contains(search.toLowerCase()));
      }).toList()
      ..sort((a,b) => (b['openedAt'] ?? '').toString()
          .compareTo((a['openedAt'] ?? '').toString()));
    final totals = widget.register['totals'] as Map? ?? {};
    final pluginId = (widget.register['id'] ?? '').toString();
    final departmentId = (widget.register['departmentId'] ?? '').toString();
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: OwnerScreenFrame(children: [
        OwnerHeading(widget.restaurant, caption: 'Заказы кассы • открытые и закрытые'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OwnerMetric('Закрытые заказы',
            _OwnerLiveCashScreenState.money(totals['closedSum']))),
          const SizedBox(width: 10),
          Expanded(child: OwnerMetric('Открытые заказы',
            _OwnerLiveCashScreenState.money(totals['openSum']))),
        ]),
        const SizedBox(height: 10),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search), hintText: 'Поиск заказа, стола или зала...'),
          onChanged: (v) => setState(() => search = v.trim()),
        ),
        const SizedBox(height: 9),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final entry in [
            ('Все', 'Все'), ('Открытые', 'OPEN'), ('Закрытые', 'CLOSED'),
          ])
            ChoiceChip(label: Text(entry.$1), selected: filter == entry.$2,
              onSelected: (_) => setState(() => filter = entry.$2)),
        ]),
        const SizedBox(height: 12),
        if (orders.isEmpty) const OwnerCard(child: Text('Заказы не найдены.')),
        for (final order in orders)
          Padding(padding: const EdgeInsets.only(bottom: 8),
            child: OwnerCard(
              onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                builder: (_) => OwnerLivePosOrderScreen(
                  order: order,
                  pluginId: pluginId,
                  departmentId: departmentId,
                  restaurant: widget.restaurant,
                  registerName: name,
                ),
              )),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Заказ №${order['number']}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${order['status'] == 'OPEN' ? 'Открыт' : order['status'] == 'CLOSED' ? 'Закрыт' : order['status'] ?? 'Статус не указан'}'
                      '${(order['floor'] ?? '').toString().trim().isNotEmpty ? ' · Зал: ${order['floor']}' : ''}'
                      '${(order['table'] ?? '').toString().trim().isNotEmpty ? ' · Стол: ${order['table']}' : ''}'),
                    Text('Время открытия: ${_time(order['openedAt'])}',
                      style: TextStyle(fontSize: 11,
                        color: OwnerPalette.muted(context))),
                    Text('Время закрытия: ${_time(order['closedAt'])}',
                      style: TextStyle(fontSize: 11,
                        color: OwnerPalette.muted(context))),
                  ],
                ),
                trailing: SizedBox(
                  width: 95,
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Flexible(child: Text(
                      _OwnerLiveCashScreenState.money(order['amount']),
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.bold))),
                    const Icon(Icons.chevron_right, size: 18),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
