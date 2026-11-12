import 'dart:convert';

class OwnerSavedSnapshot {
  final Map<String, dynamic> data;
  final DateTime savedAt;
  const OwnerSavedSnapshot(this.data, this.savedAt);
}

/// Private app storage; activated only AFTER an authenticated bootstrap.
/// The binding includes user, workspace, authorized departments and source
/// revision. No tokens, credentials, AI conversations or receipt history.
class OwnerSnapshotStore {
  OwnerSnapshotStore({required this.read, required this.write,
    required this.remove, DateTime Function()? clock})
      : clock = clock ?? DateTime.now;
  final Future<String?> Function() read;
  final Future<void> Function(String) write;
  final Future<void> Function() remove;
  final DateTime Function() clock;
  static const maxAge = Duration(hours: 24);
  static const maxBytes = 1500000;
  final Map<String, OwnerSavedSnapshot> _entries = {};
  String? _binding;
  int _epoch = 0;
  Future<void> _tail = Future.value();

  bool _valid(OwnerSavedSnapshot entry) {
    final age = clock().difference(entry.savedAt);
    final source = DateTime.tryParse('${entry.data['updatedAt'] ?? ''}');
    return !age.isNegative && age <= maxAge && source != null &&
        clock().difference(source) >= Duration.zero &&
        clock().difference(source) <= maxAge && entry.data['success'] == true;
  }

  static bool _allowed(String key, Map<String, dynamic> data) =>
      key.startsWith('summary:') || key.startsWith('cash:') ||
      (key.startsWith('report:') && const {
        'sales', 'cash', 'foodCost', 'categories', 'dishes', 'discounts',
        'surcharges', 'pnl', 'inventory', 'movements',
      }.contains(data['kind']));

  Future<Map<String, OwnerSavedSnapshot>> activate(String binding) async {
    final epoch = ++_epoch;
    _binding = binding;
    _entries.clear();
    await _tail;
    try {
      final raw = await read();
      if (epoch != _epoch) return {};
      if (raw != null && utf8.encode(raw).length <= maxBytes) {
        final pack = jsonDecode(raw);
        if (pack is Map && pack['version'] == 1 &&
            pack['binding'] == binding && pack['entries'] is Map) {
          for (final item in (pack['entries'] as Map).entries) {
            final value = item.value;
            if (value is! Map || value['data'] is! Map<String, dynamic>) continue;
            final stamp = DateTime.tryParse('${value['savedAt']}');
            if (stamp == null) continue;
            final entry = OwnerSavedSnapshot(value['data'], stamp);
            if (_valid(entry) && _allowed('${item.key}', entry.data)) {
              _entries['${item.key}'] = entry;
            }
          }
        }
      }
    } catch (_) { /* Corrupt/unavailable storage never blocks the app. */ }
    if (epoch != _epoch) return {};
    // Rewrite removes another account's or expired snapshots immediately.
    await _persist();
    return Map.of(_entries);
  }

  Future<void> remember(String key, Map<String, dynamic> data) async {
    if (_binding == null || !_allowed(key, data)) return;
    final entry = OwnerSavedSnapshot(data, clock());
    if (!_valid(entry)) return;
    _entries.remove(key);
    _entries[key] = entry;
    while (_entries.length > 16) { _entries.remove(_entries.keys.first); }
    await _persist();
  }

  Future<void> _persist() {
    final binding = _binding;
    final epoch = _epoch;
    _entries.removeWhere((_, entry) => !_valid(entry));
    String encode() => jsonEncode({'version': 1, 'binding': binding,
      'entries': {for (final item in _entries.entries) item.key: {
        'savedAt': item.value.savedAt.toIso8601String(), 'data': item.value.data,
      }}});
    var encoded = encode();
    while (utf8.encode(encoded).length > maxBytes && _entries.isNotEmpty) {
      _entries.remove(_entries.keys.first);
      encoded = encode();
    }
    _tail = _tail.then((_) async {
      if (epoch == _epoch && binding != null) await write(encoded);
    }).catchError((Object _) {});
    return _tail;
  }

  Future<void> clear() {
    ++_epoch;
    _binding = null;
    _entries.clear();
    _tail = _tail.then((_) => remove()).catchError((Object _) {});
    return _tail;
  }
}
