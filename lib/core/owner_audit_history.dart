/// Immutable verified POS audit timeline merge.
/// A partial/empty response must never erase events already fetched for the
/// same authorized workspace, department, cash terminal and order.
/// This cache must remain session-only and be cleared on sign-out.
String ownerPosAuditCacheKey(
    String workspace, String departmentId, String pluginId, String orderNum) =>
  'pos-audit:$workspace:$departmentId:$pluginId:$orderNum';

List<Map<String, dynamic>> mergeConfirmedAuditEvents(
    Iterable<Map<String,dynamic>> previous,
    Iterable<Map<String,dynamic>> incoming) {
  final merged=<String,Map<String,dynamic>>{};
  void add(Iterable<Map<String,dynamic>> events) {
    for(final row in events) {
      final id=(row['id']??'').toString().trim();
      final occurredAt=(row['occurredAt']??'').toString().trim();
      if(occurredAt.isEmpty) continue;
      final key=id.isNotEmpty?id:
        '${row['rawType']??''}:$occurredAt:${row['kind']??''}';
      // New, authenticated data may update a prior label, but absence from a
      // subsequent response is NOT evidence the old operation was undone.
      merged[key]=row;
    }
  }
  add(previous);
  add(incoming);
  final events=merged.values.toList();
  events.sort((a,b)=>
    (a['occurredAt']??'').toString()
      .compareTo((b['occurredAt']??'').toString()));
  return events;
}
