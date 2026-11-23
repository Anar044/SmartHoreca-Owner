import 'dart:math';

import 'owner_backend.dart';

class OwnerOlapField {
  final String name;
  final String title;
  final String type;
  final bool group;
  final bool measure;
  final bool filter;
  final bool restaurant;

  const OwnerOlapField({
    required this.name,
    required this.title,
    required this.type,
    this.group = false,
    this.measure = false,
    this.filter = false,
    this.restaurant = false,
  });

  factory OwnerOlapField.fromJson(Map<String, dynamic> json) => OwnerOlapField(
        name: json['name'] as String,
        title: json['title'] as String,
        type: json['type'] as String,
        group: json['group'] == true,
        measure: json['measure'] == true,
        filter: json['filter'] == true,
        restaurant: json['restaurant'] == true,
      );
}

class OwnerOlapFilter {
  final String field;
  final bool exclude;
  final List<String> values;

  const OwnerOlapFilter(this.field, this.exclude, this.values);

  factory OwnerOlapFilter.fromJson(Map<String, dynamic> json) =>
      OwnerOlapFilter(json['field'] as String, json['operator'] == 'exclude',
          List<String>.from(json['values'] as List));

  Map<String, Object> toJson() => {
        'field': field,
        'operator': exclude ? 'exclude' : 'include',
        'values': values,
      };
}

class OwnerOlapTemplate {
  final String id;
  final int version;
  final String name;
  final List<String> groups;
  final List<String> measures;
  final List<OwnerOlapFilter> filters;

  const OwnerOlapTemplate({
    required this.id,
    required this.version,
    required this.name,
    required this.groups,
    required this.measures,
    required this.filters,
  });

  factory OwnerOlapTemplate.draft() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return OwnerOlapTemplate(
      id: '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
          '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}',
      version: 0,
      name: '',
      groups: [],
      measures: [],
      filters: [],
    );
  }

  factory OwnerOlapTemplate.fromJson(Map<String, dynamic> json) =>
      OwnerOlapTemplate(
        id: json['id'] as String,
        version: json['version'] as int,
        name: json['name'] as String,
        groups: List<String>.from(json['groups'] as List),
        measures: List<String>.from(json['measures'] as List),
        filters: (json['filters'] as List)
            .cast<Map<String, dynamic>>()
            .map(OwnerOlapFilter.fromJson)
            .toList(),
      );

  Map<String, Object> definition() => {
        'name': name,
        'groups': groups,
        'measures': measures,
        'filters': filters.map((filter) => filter.toJson()).toList(),
      };
}

class OwnerOlapTable {
  final List<OwnerOlapField> columns;
  final List<List<Object?>> rows;

  const OwnerOlapTable(this.columns, this.rows);

  factory OwnerOlapTable.fromJson(Map<String, dynamic> json) => OwnerOlapTable(
        (json['columns'] as List)
            .cast<Map<String, dynamic>>()
            .map(OwnerOlapField.fromJson)
            .toList(),
        (json['rows'] as List).cast<List>().map(List<Object?>.from).toList(),
      );
}

class OwnerOlapClient {
  static const _path = OwnerBackend.olapReportsPath;
  final String workspaceId;

  const OwnerOlapClient(this.workspaceId);

  Future<List<OwnerOlapTemplate>> list() async {
    final data = await OwnerBackend.getJson(_path, workspaceId: workspaceId);
    return (data['templates'] as List)
        .cast<Map<String, dynamic>>()
        .map(OwnerOlapTemplate.fromJson)
        .toList();
  }

  Future<List<OwnerOlapField>> fields() async {
    final data = await OwnerBackend.getJson(_path,
        workspaceId: workspaceId,
        query: {'action': 'fields'},
        retryTransient: false);
    return (data['fields'] as List)
        .cast<Map<String, dynamic>>()
        .map(OwnerOlapField.fromJson)
        .toList();
  }

  Future<OwnerOlapTemplate> save(OwnerOlapTemplate template) async {
    final data = await _post('save', template, template.definition());
    return OwnerOlapTemplate.fromJson(data['template'] as Map<String, dynamic>);
  }

  Future<void> delete(OwnerOlapTemplate template) async {
    await _post('delete', template, {});
  }

  Future<OwnerOlapTable> run(OwnerOlapTemplate template,
      Set<String> restaurants, String from, String to) async {
    final data = await _post('run', template, {'from': from, 'to': to},
        restaurants: restaurants);
    return OwnerOlapTable.fromJson(data);
  }

  Future<Map<String, dynamic>> _post(
          String action, OwnerOlapTemplate template, Map<String, Object> data,
          {Set<String> restaurants = const {}}) =>
      OwnerBackend.postJson(
        _path,
        workspaceId: workspaceId,
        departmentIds: restaurants,
        payload: {
          'action': action,
          'id': template.id,
          'version': template.version,
          ...data
        },
        timeout: action == 'run'
            ? const Duration(minutes: 5)
            : const Duration(seconds: 45),
        timeoutMessage:
            'Сервер Smart Horeca не ответил вовремя. Повторите запрос.',
      );
}
