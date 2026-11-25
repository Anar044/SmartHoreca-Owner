import 'dart:convert';
import 'package:http/http.dart' as http;

/// Reuses the connection and coalesces only concurrent, identical GETs.
/// Completed responses are never cached here; each refresh rechecks access.
class OwnerReadTransport {
  OwnerReadTransport({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, Future<http.Response>> _pending = {};

  Future<http.Response> get(Uri uri, {
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 50),
    bool streamReport = false,
  }) {
    final names = headers.keys.toList()..sort();
    // Includes authentication, workspace and restaurants. Never log this key.
    final key = jsonEncode([uri.toString(), timeout.inMilliseconds, streamReport, [
      for (final name in names) [name, headers[name]],
    ]]);
    final existing = _pending[key];
    if (existing != null) return existing;
    late final Future<http.Response> pending;
    final request = streamReport
        ? _report('GET', uri, headers, timeout)
        : _client.get(uri, headers: Map.of(headers)).timeout(timeout);
    pending = request.whenComplete(() {
      if (identical(_pending[key], pending)) _pending.remove(key);
    });
    _pending[key] = pending;
    return pending;
  }

  Future<http.Response> post(Uri uri, {
    required Map<String, String> headers, required String body,
    Duration timeout = const Duration(seconds: 120), bool streamReport = false,
  }) => streamReport
      ? _report('POST', uri, headers, timeout, body: body)
      : _client.post(uri, headers: headers, body: body).timeout(timeout);

  Future<http.Response> _report(
    String method, Uri uri, Map<String, String> headers, Duration timeout,
    {String? body}
  ) async {
    final request = http.Request(method, uri);
    request.headers.addAll({...headers, 'X-SH-Report-Stream': '1'});
    if (body != null) request.body = body;
    final reply = await _client.send(request).timeout(timeout);
    if (reply.headers['x-sh-report-stream'] != '1') {
      return http.Response.fromStream(reply).timeout(timeout);
    }
    final envelope = await utf8.decoder
        .bind(reply.stream.timeout(const Duration(seconds: 45))).join();
    try {
      final result = jsonDecode(envelope);
      if (result is Map && result['status'] is int && result['body'] is String) {
        return http.Response(result['body'] as String, result['status'] as int,
          headers: {'content-type': 'application/json; charset=utf-8'});
      }
    } on FormatException {
      // The last chunk is required before any report data is displayed.
    }
    throw http.ClientException('Incomplete report response.', uri);
  }

  void close() {
    _pending.clear();
    _client.close();
  }
}
