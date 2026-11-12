import 'dart:convert';
import 'package:http/http.dart' as http;

/// Reuses the connection and coalesces only concurrent, identical GETs.
/// Completed responses are never cached here; each refresh rechecks access.
class OwnerReadTransport {
  OwnerReadTransport({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, Future<http.Response>> _pending = {};

  Future<http.Response> get(Uri uri, {required Map<String, String> headers}) {
    final names = headers.keys.toList()..sort();
    // Includes authentication, workspace and restaurants. Never log this key.
    final key = jsonEncode([uri.toString(), [
      for (final name in names) [name, headers[name]],
    ]]);
    final existing = _pending[key];
    if (existing != null) return existing;
    late final Future<http.Response> pending;
    pending = _client.get(uri, headers: Map.of(headers))
        .timeout(const Duration(seconds: 50)).whenComplete(() {
      if (identical(_pending[key], pending)) _pending.remove(key);
    });
    _pending[key] = pending;
    return pending;
  }

  Future<http.Response> post(Uri uri, {
    required Map<String, String> headers, required String body,
  }) => _client.post(uri, headers: headers, body: body);

  void close() {
    _pending.clear();
    _client.close();
  }
}
