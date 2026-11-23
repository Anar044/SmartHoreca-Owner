import 'dart:convert';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import '../core/owner_backend.dart';
import '../core/owner_l10n.dart';
import '../core/owner_olap_client.dart';
import '../core/owner_state.dart';
import '../core/owner_theme.dart';
import '../ui/owner_components.dart';
import '../ui/owner_text.dart';

String _tr(BuildContext context, String text) =>
    OwnerL10n.tr(OwnerScope.of(context).language, text);

String _message(Object error) => error is OwnerApiException
    ? error.message
    : 'Не удалось загрузить данные Smart Horeca.';

bool _currentWorkspace(BuildContext context, OwnerOlapClient client) {
  final owner = OwnerScope.of(context);
  return owner.live && owner.workspaceId == client.workspaceId;
}

class OwnerOlapReportsScreen extends StatefulWidget {
  final OwnerOlapClient client;

  const OwnerOlapReportsScreen({super.key, required this.client});

  @override
  State<OwnerOlapReportsScreen> createState() => _OwnerOlapReportsScreenState();
}

class _OwnerOlapReportsScreenState extends State<OwnerOlapReportsScreen> {
  List<OwnerOlapTemplate> _reports = [];
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reports = await widget.client.list();
      if (mounted) setState(() => _reports = reports);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _message(error);
          _reports = [];
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(OwnerOlapTemplate report) async {
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => _ReportView(client: widget.client, report: report),
        ));
    if (mounted && _currentWorkspace(context, widget.client)) await _load();
  }

  Future<void> _edit([OwnerOlapTemplate? report]) async {
    final saved = await Navigator.push(
        context,
        MaterialPageRoute<OwnerOlapTemplate>(
          builder: (_) => _ReportEditor(client: widget.client, initial: report),
        ));
    if (!mounted || !_currentWorkspace(context, widget.client)) return;
    if (saved == null) {
      if (report != null) await _load();
      return;
    }
    setState(() =>
        _reports = [saved, ..._reports.where((item) => item.id != saved.id)]);
    if (report == null) await _open(saved);
  }

  Future<void> _delete(OwnerOlapTemplate report) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const OwnerText('Удалить отчёт?'),
        content: Text(report.name),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const OwnerText('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const OwnerText('Удалить')),
        ],
      ),
    );
    if (confirm != true ||
        !mounted ||
        !_currentWorkspace(context, widget.client) ||
        _loading) {
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.client.delete(report);
      if (mounted) {
        setState(() => _reports.removeWhere((item) => item.id == report.id));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: OwnerText(_message(error))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const OwnerText('Мои OLAP-отчёты')),
        body: !_currentWorkspace(context, widget.client)
            ? const Center(
                child: OwnerText('Нет доступа к выбранной организации.'))
            : OwnerScreenFrame(onRefresh: _load, children: [
                if (_loading) const LinearProgressIndicator(),
                if (_error != null)
                  _OlapError(_error!, onRetry: _loading ? null : _load)
                else ...[
                  FilledButton.icon(
                    onPressed: _loading ? null : () => _edit(),
                    icon: const Icon(Icons.add),
                    label: const OwnerText('Создать отчёт'),
                  ),
                  const SizedBox(height: 14),
                  if (!_loading && _reports.isEmpty)
                    const OwnerCard(
                        child: OwnerText(
                            'У вас пока нет сохранённых OLAP-отчётов.')),
                  for (final report in _reports)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OwnerCard(
                          child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.table_chart_outlined),
                        title: Text(report.name),
                        onTap: _loading ? null : () => _open(report),
                        trailing: PopupMenuButton<String>(
                          enabled: !_loading,
                          tooltip: _tr(context, 'Действия с отчётом'),
                          onSelected: (choice) {
                            if (choice == 'edit') {
                              _edit(report);
                            } else {
                              _delete(report);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'edit', child: OwnerText('Изменить')),
                            PopupMenuItem(
                                value: 'delete', child: OwnerText('Удалить')),
                          ],
                        ),
                      )),
                    ),
                ],
              ]),
      );
}

class _OlapError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _OlapError(this.message, {this.onRetry});

  @override
  Widget build(BuildContext context) => OwnerCard(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OwnerText(message,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const OwnerText('Повторить'),
            ),
        ],
      ));
}

class _ReportEditor extends StatefulWidget {
  final OwnerOlapClient client;
  final OwnerOlapTemplate? initial;

  const _ReportEditor({required this.client, this.initial});

  @override
  State<_ReportEditor> createState() => _ReportEditorState();
}

class _ReportEditorState extends State<_ReportEditor> {
  final _form = GlobalKey<FormState>();
  late final _template = widget.initial ?? OwnerOlapTemplate.draft();
  late final _name = TextEditingController(text: _template.name);
  late final _groups = _template.groups.toList();
  late final _measures = _template.measures.toList();
  late final _filters = _template.filters.toList();
  Map<String, OwnerOlapField>? _catalog;
  String? _catalogError;
  String? _saveError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadFields() async {
    setState(() => _catalogError = null);
    try {
      final fields = await widget.client.fields();
      fields.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      if (mounted) {
        setState(
            () => _catalog = {for (final field in fields) field.name: field});
      }
    } catch (error) {
      if (mounted) setState(() => _catalogError = _message(error));
    }
  }

  Future<OwnerOlapField?> _choose(
          String title, Iterable<OwnerOlapField> fields) =>
      showModalBottomSheet<OwnerOlapField>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _FieldPicker(title: title, fields: fields.toList()),
      );

  String _label(String name) => _catalog?[name]?.title ?? name;

  Future<void> _addField(String title, List<String> selected,
      bool Function(OwnerOlapField) allowed) async {
    final field = await _choose(
        title,
        _catalog!.values.where(
            (field) => allowed(field) && !selected.contains(field.name)));
    if (mounted && field != null) setState(() => selected.add(field.name));
  }

  Future<void> _editFilter({int? index}) async {
    final previous = index == null ? null : _filters[index];
    final field = previous == null
        ? await _choose(
            'Поле для фильтра',
            _catalog!.values.where((field) =>
                field.filter &&
                !_filters.any((filter) => filter.field == field.name)))
        : _catalog![previous.field];
    if (field == null || !mounted) return;
    final filter = field.valueChoices
        ? await showModalBottomSheet<OwnerOlapFilter>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => _FilterChoices(
                client: widget.client, field: field, previous: previous),
          )
        : await showDialog<OwnerOlapFilter>(
            context: context,
            builder: (_) => _FilterDialog(field: field, previous: previous),
          );
    if (filter == null ||
        !mounted ||
        !_currentWorkspace(context, widget.client)) {
      return;
    }
    setState(() {
      if (index == null) {
        _filters.add(filter);
      } else {
        _filters[index] = filter;
      }
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _saveError = 'Введите название отчёта.');
      return;
    }
    if (_measures.isEmpty) {
      setState(() => _saveError = 'Добавьте хотя бы один показатель.');
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final saved = await widget.client.save(OwnerOlapTemplate(
        id: _template.id,
        version: _template.version,
        name: _name.text.trim(),
        groups: _groups,
        measures: _measures,
        filters: _filters,
      ));
      if (mounted && _currentWorkspace(context, widget.client)) {
        Navigator.pop(context, saved);
      }
    } catch (error) {
      if (mounted) setState(() => _saveError = _message(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _fields(String title, List<String> selected,
          bool Function(OwnerOlapField) allowed) =>
      OwnerCard(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OwnerHeading(title),
          if (selected.isNotEmpty)
            Wrap(spacing: 8, children: [
              for (final field in selected)
                InputChip(
                    label: Text(_label(field)),
                    onDeleted: _saving
                        ? null
                        : () => setState(() => selected.remove(field))),
            ]),
          TextButton.icon(
            onPressed: _saving || selected.length >= 8
                ? null
                : () => _addField(title, selected, allowed),
            icon: const Icon(Icons.add),
            label: const OwnerText('Добавить поле'),
          ),
        ],
      ));

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: Scaffold(
          appBar: AppBar(
              title: OwnerText(
                  widget.initial == null ? 'Создать отчёт' : 'Изменить отчёт')),
          body: !_currentWorkspace(context, widget.client)
              ? const Center(
                  child: OwnerText('Нет доступа к выбранной организации.'))
              : _catalogError != null
                  ? OwnerScreenFrame(children: [
                      _OlapError(_catalogError!, onRetry: _loadFields)
                    ])
                  : _catalog == null
                      ? const Center(child: CircularProgressIndicator())
                      : Form(
                          key: _form,
                          child: OwnerScreenFrame(children: [
                            TextFormField(
                              controller: _name,
                              enabled: !_saving,
                              maxLength: 100,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                labelText: _tr(context, 'Название отчёта'),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (value) => (value ?? '').trim().isEmpty
                                  ? _tr(context, 'Введите название отчёта.')
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            _fields(
                                'Группировки', _groups, (field) => field.group),
                            const SizedBox(height: 10),
                            _fields('Показатели', _measures,
                                (field) => field.measure),
                            const SizedBox(height: 10),
                            OwnerCard(
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const OwnerHeading('Фильтры'),
                                for (var index = 0;
                                    index < _filters.length;
                                    index++)
                                  _filterTile(index),
                                TextButton.icon(
                                  onPressed: _saving || _filters.length >= 8
                                      ? null
                                      : () => _editFilter(),
                                  icon: const Icon(Icons.add),
                                  label: const OwnerText('Добавить фильтр'),
                                ),
                              ],
                            )),
                            if (_saveError != null) ...[
                              const SizedBox(height: 10),
                              _OlapError(_saveError!),
                            ],
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: const Icon(Icons.save_outlined),
                              label: OwnerText(
                                  _saving ? 'Сохраняем…' : 'Сохранить отчёт'),
                            ),
                            if (_saving) const LinearProgressIndicator(),
                          ]),
                        ),
        ),
      );

  Widget _filterTile(int index) {
    final filter = _filters[index];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(_label(filter.field)),
      subtitle: Text(
          '${_tr(context, filter.exclude ? 'Исключить' : 'Включить')} · '
          '${filter.values.join(', ')}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis),
      onTap: _saving ? null : () => _editFilter(index: index),
      trailing: IconButton(
        tooltip: _tr(context, 'Удалить фильтр'),
        onPressed:
            _saving ? null : () => setState(() => _filters.removeAt(index)),
        icon: const Icon(Icons.close),
      ),
    );
  }
}

class _FieldPicker extends StatefulWidget {
  final String title;
  final List<OwnerOlapField> fields;

  const _FieldPicker({required this.title, required this.fields});

  @override
  State<_FieldPicker> createState() => _FieldPickerState();
}

class _FieldPickerState extends State<_FieldPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final matches = widget.fields
        .where((field) =>
            field.title.toLowerCase().contains(_query) ||
            field.name.toLowerCase().contains(_query))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: .78,
        child: SafeArea(
            top: false,
            child: Column(children: [
              ListTile(
                title: OwnerHeading(widget.title),
                trailing: CloseButton(onPressed: () => Navigator.pop(context)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: _tr(context, 'Поиск поля'),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
              ),
              Expanded(
                  child: matches.isEmpty
                      ? const Center(child: OwnerText('Поля не найдены.'))
                      : ListView.builder(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: matches.length,
                          itemBuilder: (context, index) {
                            final field = matches[index];
                            return ListTile(
                              title: Text(field.title),
                              subtitle: field.title == field.name
                                  ? null
                                  : Text(field.name),
                              onTap: () => Navigator.pop(context, field),
                            );
                          },
                        )),
            ])),
      ),
    );
  }
}

class _FilterDialog extends StatefulWidget {
  final OwnerOlapField field;
  final OwnerOlapFilter? previous;

  const _FilterDialog({required this.field, this.previous});

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  final _form = GlobalKey<FormState>();
  late var _exclude = widget.previous?.exclude ?? false;
  late final _values =
      TextEditingController(text: widget.previous?.values.join('\n'));

  List<String> get _items => _values.text
      .split('\n')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();

  @override
  void dispose() {
    _values.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        title: Text(widget.field.title),
        content: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButton<bool>(
                  isExpanded: true,
                  value: _exclude,
                  items: const [
                    DropdownMenuItem(
                        value: false, child: OwnerText('Включить')),
                    DropdownMenuItem(
                        value: true, child: OwnerText('Исключить')),
                  ],
                  onChanged: (value) =>
                      setState(() => _exclude = value ?? false),
                ),
                const OwnerText(
                    'iiko не предоставляет список значений для этого поля.'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _values,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 3020,
                  decoration: InputDecoration(
                    labelText: _tr(context, 'По одному значению на строку'),
                    helperText: widget.field.type.toUpperCase() == 'PERCENT'
                        ? _tr(context, 'Доля: 0,9 = 90%')
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (_) => _items.isEmpty ||
                          _items.length > 20 ||
                          _items.any((item) => item.length > 150)
                      ? _tr(context,
                          'Укажите от 1 до 20 значений до 150 символов каждое.')
                      : null,
                ),
              ],
            )),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const OwnerText('Отмена')),
          FilledButton(
            onPressed: () {
              if (_form.currentState!.validate()) {
                Navigator.pop(context,
                    OwnerOlapFilter(widget.field.name, _exclude, _items));
              }
            },
            child: const OwnerText('Применить'),
          ),
        ],
      );
}

class _FilterChoices extends StatefulWidget {
  final OwnerOlapClient client;
  final OwnerOlapField field;
  final OwnerOlapFilter? previous;

  const _FilterChoices({
    required this.client,
    required this.field,
    this.previous,
  });

  @override
  State<_FilterChoices> createState() => _FilterChoicesState();
}

class _FilterChoicesState extends State<_FilterChoices> {
  late final _selected = {...?widget.previous?.values};
  late var _exclude = widget.previous?.exclude ?? false;
  final _labels = <String, String>{};
  List<OwnerOlapChoice> _choices = [];
  Set<String>? _restaurants;
  String _search = '';
  String? _error;
  bool _loading = false;
  int _request = 0;
  late DateTimeRange _period;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _period =
        DateTimeRange(start: DateUtils.addDaysToDate(today, -29), end: today);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final owner = OwnerScope.of(context);
    final active = owner.live && owner.workspaceId == widget.client.workspaceId;
    final ids = active ? owner.selectedRestaurantIds : <String>{};
    if (setEquals(_restaurants, ids)) return;
    _restaurants = ids;
    _labels.clear();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    final restaurants = _restaurants!;
    setState(() {
      _choices = [];
      _error = restaurants.isEmpty ? 'Выберите рестораны для отчёта.' : null;
      _loading = restaurants.isNotEmpty;
    });
    if (restaurants.isEmpty) return;
    try {
      final choices = await widget.client.filterValues(
          widget.field.name,
          restaurants,
          OwnerState.formatDate(_period.start),
          OwnerState.formatDate(_period.end));
      if (mounted && request == _request) {
        setState(() {
          _choices = choices;
          _labels.addEntries(
              choices.map((item) => MapEntry(item.value, item.label)));
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _loading = false;
          _error = _message(error);
        });
      }
    }
  }

  Future<void> _pickPeriod() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final period = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
      initialDateRange: _period,
      helpText: _tr(context, 'Период списка значений'),
      saveText: _tr(context, 'Применить'),
    );
    if (!mounted || period == null || period == _period) return;
    _period = period;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final hasScope = _restaurants?.isNotEmpty == true;
    final display = {for (final choice in _choices) choice.value: choice.label};
    for (final value in _selected) {
      display.putIfAbsent(value, () => _labels[value] ?? value);
    }
    final matches = display.entries
        .where((choice) =>
            choice.value.toLowerCase().contains(_search) ||
            choice.value != choice.key &&
                choice.key.toLowerCase().contains(_search))
        .toList();
    final dates =
        '${OwnerState.formatDate(_period.start)} – ${OwnerState.formatDate(_period.end)}';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
          heightFactor: .94,
          child: SafeArea(
            top: false,
            child: Column(children: [
              Expanded(
                  child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(
                      child: ListTile(
                    title: Text(widget.field.title,
                        style: Theme.of(context).textTheme.titleLarge),
                    trailing:
                        CloseButton(onPressed: () => Navigator.pop(context)),
                  )),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    sliver: SliverToBoxAdapter(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                  value: false, label: OwnerText('Включить')),
                              ButtonSegment(
                                  value: true, label: OwnerText('Исключить')),
                            ],
                            selected: {_exclude},
                            onSelectionChanged: (value) =>
                                setState(() => _exclude = value.single),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: hasScope ? _pickPeriod : null,
                            icon: const Icon(Icons.date_range_outlined),
                            label: Text(dates,
                                semanticsLabel:
                                    '${_tr(context, 'Период списка значений')}. $dates'),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              labelText: _tr(context, 'Поиск значения'),
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (value) => setState(
                                () => _search = value.trim().toLowerCase()),
                          ),
                        ])),
                  ),
                  if (_loading)
                    const SliverToBoxAdapter(child: LinearProgressIndicator()),
                  if (_error != null)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      sliver: SliverToBoxAdapter(
                          child: _OlapError(_error!,
                              onRetry: hasScope ? _load : null)),
                    )
                  else if (matches.isEmpty && !_loading)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      sliver: SliverToBoxAdapter(
                          child: OwnerText(_search.isEmpty
                              ? 'Нет значений за выбранный период.'
                              : 'Значения не найдены.')),
                    ),
                  SliverList.builder(
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final choice = matches[index];
                      final checked = _selected.contains(choice.key);
                      return CheckboxListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(choice.value),
                        value: checked,
                        onChanged: hasScope &&
                                (checked ||
                                    _selected.length <
                                        OwnerOlapFilter.maxValues)
                            ? (value) => setState(() {
                                  if (value == true) {
                                    _selected.add(choice.key);
                                  } else {
                                    _selected.remove(choice.key);
                                  }
                                })
                            : null,
                      );
                    },
                  ),
                ],
              )),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(children: [
                  Expanded(
                      child: Text(
                          '${_tr(context, 'Выбрано')} ${_selected.length}'
                          '${_selected.length >= OwnerOlapFilter.maxValues ? '/${OwnerOlapFilter.maxValues}' : ''}')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: !hasScope || _selected.isEmpty
                        ? null
                        : () => Navigator.pop(
                            context,
                            OwnerOlapFilter(widget.field.name, _exclude,
                                _selected.toList())),
                    child: const OwnerText('Применить'),
                  ),
                ]),
              ),
            ]),
          )),
    );
  }
}

class _ReportView extends StatefulWidget {
  final OwnerOlapClient client;
  final OwnerOlapTemplate report;

  const _ReportView({required this.client, required this.report});

  @override
  State<_ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<_ReportView> {
  DateTimeRange? _dates;
  Set<String> _restaurants = {};
  OwnerOlapTable? _result;
  String? _error;
  bool _loading = false;
  int _scopeVersion = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final owner = OwnerScope.of(context);
    final dates = owner.reportDates();
    _dates ??= DateTimeRange(
        start: DateTime.parse(dates['from']!),
        end: DateTime.parse(dates['to']!));
    final next = owner.live && owner.workspaceId == widget.client.workspaceId
        ? owner.selectedRestaurantIds
        : <String>{};
    if (next.length != _restaurants.length || !next.containsAll(_restaurants)) {
      _restaurants = next;
      _scopeVersion++;
      _result = null;
      _error = null;
      _loading = false;
    }
  }

  void _setDates(DateTimeRange range) => setState(() {
        _dates = range;
        _result = null;
        _error = null;
      });

  Future<void> _pickDates() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final first = DateTime(today.year - 5);
    final selected = _dates!;
    final initial =
        selected.start.isBefore(first) || selected.end.isAfter(today)
            ? null
            : selected;
    final range = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: today,
      initialDateRange: initial,
      helpText: _tr(context, 'Период отчёта'),
      saveText: _tr(context, 'Применить'),
    );
    if (mounted && range != null) _setDates(range);
  }

  Future<void> _run() async {
    final version = _scopeVersion;
    final dates = _dates!;
    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });
    try {
      final result = await widget.client.run(widget.report, _restaurants,
          OwnerState.formatDate(dates.start), OwnerState.formatDate(dates.end));
      final table = result
          .onlyFields([...widget.report.groups, ...widget.report.measures]);
      if (mounted && version == _scopeVersion) setState(() => _result = table);
    } catch (error) {
      if (mounted && version == _scopeVersion) {
        setState(() => _error = _message(error));
      }
    } finally {
      if (mounted && version == _scopeVersion) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final lastMonth = DateTimeRange(
      start: DateTime(today.year, today.month - 1, 1),
      end: DateTime(today.year, today.month, 0),
    );
    final selected = _dates!;
    final dateLabel = '${OwnerState.formatDate(selected.start)} – '
        '${OwnerState.formatDate(selected.end)}';
    final controls = <Widget>[
      const OwnerRestaurantPicker(),
      const SizedBox(height: 12),
      const OwnerHeading('Период отчёта'),
      Wrap(spacing: 8, runSpacing: 6, children: [
        ChoiceChip(
          label: const OwnerText('Прошлый месяц'),
          selected: selected == lastMonth,
          onSelected: _loading ? null : (_) => _setDates(lastMonth),
        ),
        OutlinedButton.icon(
          onPressed: _loading ? null : _pickDates,
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(dateLabel),
        ),
      ]),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: _loading || _restaurants.isEmpty ? null : _run,
        icon: const Icon(Icons.table_rows_outlined),
        label: OwnerText(_loading ? 'Формируем отчёт…' : 'Показать'),
      ),
      if (_restaurants.isEmpty)
        const OwnerText('Выберите рестораны для отчёта.'),
      const SizedBox(height: 12),
      if (_loading) const LinearProgressIndicator(),
      if (_error != null) _OlapError(_error!),
    ];
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: Text(widget.report.name)),
      body: !_currentWorkspace(context, widget.client)
          ? const Center(
              child: OwnerText('Нет доступа к выбранной организации.'))
          : result != null &&
                  result.rows.isNotEmpty &&
                  result.columns.isNotEmpty
              ? _ReportTable(
                  key: ObjectKey(result),
                  table: result,
                  groupCount: widget.report.groups.length,
                  controls: controls,
                )
              : OwnerScreenFrame(children: [
                  ...controls,
                  if (result != null)
                    const OwnerCard(
                        child: OwnerText('Нет данных для выбранного периода.')),
                ]),
    );
  }
}

class _ReportTable extends StatefulWidget {
  final OwnerOlapTable table;
  final int groupCount;
  final List<Widget> controls;

  const _ReportTable({
    super.key,
    required this.table,
    required this.groupCount,
    required this.controls,
  });

  @override
  State<_ReportTable> createState() => _ReportTableState();
}

class _ReportGroup {
  final int depth;
  final String label;
  final List<Object?>? values;
  final children = <String, _ReportGroup>{};

  _ReportGroup(this.depth, this.label, this.values);
}

class _ReportTableState extends State<_ReportTable> {
  final _horizontal = ScrollController();
  final _expanded = <_ReportGroup>{};
  final _branches = <_ReportGroup>[];
  late final _roots = _buildTree();

  Map<String, _ReportGroup> _buildTree() {
    final table = widget.table;
    final roots = <String, _ReportGroup>{};
    for (var index = 0; index < table.rows.length; index++) {
      final row = table.rows[index];
      final keys =
          index < table.groupKeys.length ? table.groupKeys[index] : null;
      var siblings = roots;
      final path = <String>[];
      for (var depth = 0; depth < widget.groupCount; depth++) {
        final key = keys != null && depth < keys.length
            ? keys[depth]
            : jsonEncode(row[depth]);
        path.add(key);
        final leaf = depth == widget.groupCount - 1;
        final node = siblings.putIfAbsent(key, () {
          final value = row[depth];
          final group = _ReportGroup(
            depth,
            value == null || value == '' ? '—' : value.toString(),
            leaf ? row.sublist(widget.groupCount) : table.subtotal(path),
          );
          if (!leaf) _branches.add(group);
          return group;
        });
        siblings = node.children;
      }
    }
    return roots;
  }

  Iterable<_ReportGroup> _visible(Iterable<_ReportGroup> groups) sync* {
    for (final group in groups) {
      yield group;
      if (_expanded.contains(group)) yield* _visible(group.children.values);
    }
  }

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  String _value(Object? value, OwnerOlapField field) {
    if (value == null) return '—';
    if (field.measure && field.type.toUpperCase() == 'PERCENT') {
      final numeric = value is num
          ? value
          : num.tryParse(value.toString().replaceAll(',', '.'));
      if (numeric != null) return '${(numeric * 100).toStringAsFixed(2)}%';
    }
    return value.toString();
  }

  Widget _tableSliver(BuildContext context, double width) {
    final table = widget.table;
    final groups = table.columns.take(widget.groupCount);
    final measures = table.columns.skip(widget.groupCount).toList();
    final visible = _visible(_roots.values).toList();
    final anyExpanded = visible.any(_expanded.contains);
    final labelWidth = (width * .52).clamp(138.0, width - 98 * measures.length);
    final valueWidth = (width - labelWidth) / measures.length;
    final totals =
        table.totals ?? (widget.groupCount == 0 ? table.rows.first : null);
    final showTotals = totals != null || table.totalsIncomplete;
    final theme = Theme.of(context);
    final divider = BorderSide(color: theme.dividerColor);
    Widget line(String label, List<String> values,
        {int depth = 0,
        bool bold = false,
        bool heading = false,
        Color? ink,
        bool? expanded}) {
      final style = TextStyle(
        color: ink,
        fontWeight: bold ? FontWeight.w700 : null,
      );
      return Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Padding(
              padding:
                  EdgeInsetsDirectional.fromSTEB(12 + 8.0 * depth, 10, 8, 10),
              child: Row(
                children: [
                  if (expanded != null) ...[
                    ExcludeSemantics(
                        child: Icon(
                      expanded ? Icons.expand_more : Icons.chevron_right,
                      size: 18,
                    )),
                    const SizedBox(width: 4),
                  ],
                  Expanded(child: Text(label, style: style)),
                ],
              ),
            ),
          ),
          for (final value in values)
            SizedBox(
              width: valueWidth,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 10, 12, 10),
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: heading
                      ? style
                      : style.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                ),
              ),
            ),
        ],
      );
    }

    List<String> displayValues(List<Object?>? values) => [
          for (var index = 0; index < measures.length; index++)
            _value(
                values != null && index < values.length ? values[index] : null,
                measures[index]),
        ];

    return SliverMainAxisGroup(slivers: [
      if (_branches.isNotEmpty)
        SliverToBoxAdapter(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => setState(() {
                if (anyExpanded) {
                  _expanded.clear();
                } else {
                  _expanded.addAll(_branches);
                }
              }),
              child: OwnerText(anyExpanded ? 'Свернуть всё' : 'Развернуть всё'),
            ),
          ),
        ),
      SliverToBoxAdapter(
        child: Semantics(
          header: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: OwnerPalette.raised(context),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: line(
              groups.isEmpty
                  ? _tr(context, 'Показатели')
                  : groups
                      .map((field) => field.restaurant
                          ? _tr(context, 'Ресторан')
                          : field.title)
                      .join(' → '),
              measures.map((field) => field.title).toList(),
              heading: true,
              bold: true,
            ),
          ),
        ),
      ),
      SliverList.builder(
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final group = visible[index];
          final branch = group.children.isNotEmpty;
          final color = branch && group.depth == 0
              ? OwnerPalette.raised(context)
              : OwnerPalette.surface(context);
          final expanded = _expanded.contains(group);
          final row = line(group.label, displayValues(group.values),
              depth: group.depth,
              bold: branch,
              expanded: branch ? expanded : null);
          return Container(
            key: ObjectKey(group),
            decoration:
                BoxDecoration(color: color, border: Border(top: divider)),
            child: branch
                ? Semantics(
                    button: true,
                    expanded: expanded,
                    child: Material(
                      color: color,
                      child: InkWell(
                        onTap: () => setState(() {
                          if (!_expanded.remove(group)) _expanded.add(group);
                        }),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: row,
                        ),
                      ),
                    ),
                  )
                : row,
          );
        },
      ),
      if (showTotals)
        SliverToBoxAdapter(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              border: Border(top: divider),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: line(_tr(context, 'Итого'), displayValues(totals),
                bold: true, ink: theme.colorScheme.onPrimaryContainer),
          ),
        ),
      if (table.totalsIncomplete)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 8),
            child: OwnerText('Некоторые итоги недоступны. Повторите запрос.'),
          ),
        ),
    ]);
  }

  Widget _controlsSliver() => SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        sliver: SliverToBoxAdapter(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: widget.controls,
        )),
      );

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: LayoutBuilder(builder: (context, constraints) {
          final available = constraints.maxWidth - 32;
          final minimum =
              138.0 + 98.0 * (widget.table.columns.length - widget.groupCount);
          if (minimum <= available) {
            return CustomScrollView(slivers: [
              _controlsSliver(),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: _tableSliver(context, available),
              ),
            ]);
          }
          return NestedScrollView(
            headerSliverBuilder: (_, __) => [_controlsSliver()],
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Scrollbar(
                controller: _horizontal,
                thumbVisibility: true,
                notificationPredicate: (notice) =>
                    notice.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _horizontal,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: minimum,
                    child: CustomScrollView(
                      primary: true,
                      slivers: [
                        _tableSliver(context, minimum),
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      );
}
