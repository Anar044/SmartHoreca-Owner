import 'package:flutter/material.dart';
import '../ui/owner_text.dart';

import '../core/owner_backend.dart';
import '../core/owner_state.dart';
import '../core/owner_theme.dart';
import '../ui/owner_components.dart';
import 'owner_live_reports.dart';

/// Live owner-only cash shift list. Financial values are displayed only when
/// explicitly returned by the authenticated and CHAIN-scoped server API.
class OwnerLiveCashShifts extends StatefulWidget {
  const OwnerLiveCashShifts({super.key});

  @override
  State<OwnerLiveCashShifts> createState() => _OwnerLiveCashShiftsState();
}

class _OwnerLiveCashShiftsState extends State<OwnerLiveCashShifts> {
  String period = 'Сегодня';
  String search = '';
  String status = 'Все';
  bool loading = true;
  String? error;
  Map<String, dynamic>? data;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  String _date(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Map<String, String> _periodQuery() {
    final now = DateTime.now();
    final end = period == 'Вчера'
        ? now.subtract(const Duration(days: 1)) : now;
    final start = period == '7 дней'
        ? end.subtract(const Duration(days: 6)) : end;
    return {'from': _date(start), 'to': _date(end)};
  }

  Future<void> _load() async {
    final owner = OwnerScope.of(context);
    if (!owner.live || owner.workspaceId == null ||
        owner.selectedRestaurantIds.isEmpty) {
      setState(() {
        error = 'Выберите хотя бы один доступный ресторан.';
        data = null;
        loading = false;
      });
      return;
    }
    final current = ++generation;
    setState(() {
      error = null;
      loading = true;
      data = null;
    });
    try {
      final response = await OwnerBackend.getJson('/api/mobile/v1/shifts',
        workspaceId: owner.workspaceId,
        departmentIds: owner.selectedRestaurantIds,
        query: _periodQuery(),
      );
      if (!mounted || current != generation) return;
      setState(() {
        data = response;
        loading = false;
      });
    } catch (e) {
      if (!mounted || current != generation) return;
      setState(() {
        error = e is OwnerApiException ? e.message
            : 'Не удалось получить кассовые смены.';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = OwnerScope.of(context);
    final restaurants = <String, String>{
      for (final entry in owner.restaurantIdsByName.entries)
        entry.value: entry.key,
    };
    final all = (data?['shifts'] as List? ?? [])
        .whereType<Map<String, dynamic>>().toList();
    final visible = all.where((row) {
      final rowStatus = (row['status'] ?? 'UNKNOWN').toString();
      if (status != 'Все' && rowStatus != status) return false;
      final needle = search.toLowerCase();
      if (needle.isEmpty) return true;
      return [
        row['cashRegisterName'], row['cashierName'], row['number'],
        row['id'], restaurants[(row['departmentId'] ?? '').toString()],
      ].any((value) => (value ?? '').toString().toLowerCase().contains(needle));
    }).toList();

    return OwnerScreenFrame(children: [
      const OwnerHeading('Кассы', caption: 'Просмотр кассовых смен'),
      const SizedBox(height: 12),
      const OwnerRestaurantPicker(),
      const SizedBox(height: 12),
      OwnerCard(
        onTap: () => Navigator.push(context, MaterialPageRoute<void>(
          builder: (_) => const OwnerLiveReportScreen(
            title: 'Чеки', kind: 'orders',
          ),
        )),
        child: const Row(children: [
          Icon(Icons.receipt_long_outlined),
          SizedBox(width: 10),
          Expanded(child: OwnerText('Чеки выбранных ресторанов',
              style: TextStyle(fontWeight: FontWeight.w600))),
          Icon(Icons.chevron_right),
        ]),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 7, runSpacing: 7, children: [
        for (final option in ['Сегодня', 'Вчера', '7 дней'])
          ChoiceChip(
            showCheckmark: false,
            label: Text(option, style: const TextStyle(fontSize: 12)),
            selected: period == option,
            onSelected: (_) {
              setState(() => period = option);
              _load();
            },
          ),
      ]),
      const SizedBox(height: 13),
      TextField(
        decoration: const InputDecoration(
          hintText: 'Поиск кассы, смены или кассира',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (text) => setState(() => search = text),
      ),
      const SizedBox(height: 9),
      Wrap(spacing: 7, runSpacing: 7, children: [
        for (final entry in [
          ('Все', 'Все'),
          ('Открытые', 'OPEN'),
          ('Закрытые', 'CLOSED'),
        ])
          ChoiceChip(
            showCheckmark: false,
            label: Text(entry.$1, style: const TextStyle(fontSize: 12)),
            selected: status == entry.$2,
            onSelected: (_) => setState(() => status = entry.$2),
          ),
      ]),
      const SizedBox(height: 14),
      if (loading)
        const OwnerCard(child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Column(children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            OwnerText('Получаем кассовые смены…'),
          ])),
        ))
      else if (error != null)
        OwnerCard(child: Column(children: [
          const Icon(Icons.cloud_off_outlined,
              color: OwnerPalette.error, size: 34),
          const SizedBox(height: 8),
          Text(error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _load,
              icon: const Icon(Icons.refresh), label: const OwnerText('Повторить')),
        ]))
      else ...[
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Найдено смен: ${visible.length}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          TextButton.icon(onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const OwnerText('Обновить')),
        ]),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          const OwnerCard(child: Text(
            'За выбранный период и с этими фильтрами кассовые смены не найдены.'))
        else
          for (final shift in visible) ...[
            OwnerCard(
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => OwnerLiveShiftDetail(
                    shiftId: shift['id'].toString(),
                  ),
                ));
              },
              child: Row(children: [
                Icon(Icons.point_of_sale_outlined,
                    color: OwnerPalette.accent(context)),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (shift['cashRegisterName'] ??
                       'Смена ${shift['number'] ?? shift['id']}')
                          .toString(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      restaurants[(shift['departmentId'] ?? '').toString()]
                          ?? 'Ресторан не определён',
                      style: TextStyle(color: OwnerPalette.muted(context),
                          fontSize: 12),
                    ),
                    if (shift['cashierName'] != null)
                      Text(shift['cashierName'].toString(),
                          style: TextStyle(color: OwnerPalette.muted(context),
                              fontSize: 12)),
                    if (shift['openedAt'] != null)
                      Text('Открыта: ${shift['openedAt']}',
                        style: TextStyle(color: OwnerPalette.muted(context),
                            fontSize: 11)),
                  ],
                )),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    shift['revenue'] is num
                        ? _money(shift['revenue'] as num)
                        : 'Сумма —',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(shift['status'] == 'OPEN' ? 'Открыта'
                      : shift['status'] == 'CLOSED' ? 'Закрыта' : 'Статус —',
                    style: TextStyle(fontSize: 12,
                      color: shift['status'] == 'OPEN' ? OwnerPalette.green
                          : OwnerPalette.muted(context)),
                  ),
                ]),
                const SizedBox(width: 5),
                const Icon(Icons.chevron_right, size: 18),
              ]),
            ),
            const SizedBox(height: 9),
          ],
        const SizedBox(height: 10),
        Text('Источник: ${data?['source'] ?? 'SH Cash Shifts'}'
          ' • Обновлено: ${data?['updatedAt'] ?? '—'}',
          style: TextStyle(color: OwnerPalette.muted(context), fontSize: 11)),
      ],
    ]);
  }

  String _money(num value) => '${value.toStringAsFixed(2)} AZN';
}

class OwnerLiveShiftDetail extends StatefulWidget {
  final String shiftId;

  const OwnerLiveShiftDetail({super.key, required this.shiftId});

  @override
  State<OwnerLiveShiftDetail> createState() => _OwnerLiveShiftDetailState();
}

class _OwnerLiveShiftDetailState extends State<OwnerLiveShiftDetail> {
  Map<String, dynamic>? detail;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final state = OwnerScope.of(context);
    setState(() {
      loading = true;
      error = null;
      detail = null;
    });
    try {
      final response = await OwnerBackend.getJson('/api/mobile/v1/shift',
        workspaceId: state.workspaceId,
        departmentIds: state.selectedRestaurantIds,
        query: {'id': widget.shiftId},
      );
      if (!mounted) return;
      setState(() {
        detail = response;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e is OwnerApiException ? e.message
            : 'Не удалось получить сведения о смене.';
        loading = false;
      });
    }
  }

  String display(dynamic value) => value == null ? '—' : value.toString();
  String money(dynamic value) =>
      value is num ? '${value.toStringAsFixed(2)} AZN' : '—';

  @override
  Widget build(BuildContext context) {
    final shift = detail;
    final ops = (shift?['operations'] as List? ?? [])
        .whereType<Map<String, dynamic>>().toList();
    return Scaffold(
      appBar: AppBar(title: const OwnerText('Детали смены')),
      body: OwnerScreenFrame(children: [
        if (loading)
          const OwnerCard(child: Padding(
            padding: EdgeInsets.all(18),
            child: Center(child: CircularProgressIndicator()),
          ))
        else if (error != null)
          OwnerCard(child: Column(children: [
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const OwnerText('Повторить')),
          ]))
        else if (shift != null) ...[
          OwnerHeading('Смена ${display(shift['number'])}',
            caption: 'Просмотр без возможности изменений'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OwnerMetric('Выручка', money(shift['revenue']))),
            const SizedBox(width: 10),
            Expanded(child: OwnerMetric('Чеки', display(shift['checkCount']))),
          ]),
          const SizedBox(height: 12),
          OwnerCard(child: Column(children: [
            ListTile(contentPadding: EdgeInsets.zero,
              title: const OwnerText('Открытие'),
              trailing: Text(display(shift['openedAt']))),
            const Divider(height: 1),
            ListTile(contentPadding: EdgeInsets.zero,
              title: const OwnerText('Закрытие'),
              trailing: Text(display(shift['closedAt']))),
            const Divider(height: 1),
            ListTile(contentPadding: EdgeInsets.zero,
              title: const OwnerText('Кассир'),
              trailing: Text(display(shift['cashierName']))),
          ])),
          const SizedBox(height: 16),
          const OwnerHeading('Оплаты и операции',
            caption: 'Движения наличных не приравниваются к выручке'),
          const SizedBox(height: 10),
          if (shift['paymentsLoaded'] != true)
            const OwnerCard(child: Text(
              'SH Server не вернул данные об оплатах. '
              'Они не отображаются как нулевые.'))
          else if (ops.isEmpty)
            const OwnerCard(child: OwnerText('Операций оплаты не найдено.'))
          else
            for (final operation in ops) ...[
              OwnerCard(child: Row(children: [
                const Icon(Icons.payments_outlined),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(display(operation['group']),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(display(operation['date']),
                      style: TextStyle(color: OwnerPalette.muted(context),
                          fontSize: 11)),
                  ],
                )),
                Text(money(operation['amount']),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              ])),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 12),
          Text('Обновлено: ${shift['updatedAt'] ?? '—'}',
            style: TextStyle(color: OwnerPalette.muted(context), fontSize: 11)),
        ],
      ]),
    );
  }
}
