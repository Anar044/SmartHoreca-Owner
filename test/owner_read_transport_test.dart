import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_horeca_owner/core/owner_read_transport.dart';

void main() {
  final uri = Uri.parse('https://example.invalid/api/mobile/v1/summary');
  final headers = {'Authorization': 'Bearer fixture',
    'X-SH-Workspace-Id': 'workspace', 'X-SH-Department-Ids': 'one,two'};

  test('concurrent same-scope reads share transport; refresh reads again', () async {
    var calls = 0;
    var gate = Completer<http.Response>();
    final transport = OwnerReadTransport(client: MockClient((_) {
      calls++;
      return gate.future;
    }));
    final first = transport.get(uri, headers: headers);
    final second = transport.get(uri, headers: Map.fromEntries(
      headers.entries.toList().reversed));
    expect(identical(first, second), isTrue);
    gate.complete(http.Response('{"success":true}', 200));
    await Future.wait([first, second]);
    expect(calls, 1);
    gate = Completer<http.Response>();
    final refresh = transport.get(uri, headers: headers);
    gate.complete(http.Response('{"success":true}', 200));
    await refresh;
    expect(calls, 2);
    transport.close();
  });

  test('token, workspace, departments and query never share a response', () async {
    var calls = 0;
    final gate = Completer<http.Response>();
    final transport = OwnerReadTransport(client: MockClient((_) {
      calls++;
      return gate.future;
    }));
    final reads = [transport.get(uri, headers: headers)];
    for (final name in headers.keys) {
      reads.add(transport.get(uri, headers: {...headers, name: 'other'}));
    }
    reads.add(transport.get(uri.replace(queryParameters: {'from': '2026-11-12'}),
      headers: headers));
    gate.complete(http.Response('{}', 200));
    await Future.wait(reads);
    expect(calls, 5);
    transport.close();
  });

  test('failure is released and POST is never shared or replayed', () async {
    var calls = 0;
    final transport = OwnerReadTransport(client: MockClient((_) async {
      if (++calls == 1) throw http.ClientException('offline');
      return http.Response('{}', 200);
    }));
    await expectLater(transport.get(uri, headers: headers), throwsA(isA<http.ClientException>()));
    await transport.get(uri, headers: headers);
    await Future.wait([
      transport.post(uri, headers: headers, body: '{}'),
      transport.post(uri, headers: headers, body: '{}'),
    ]);
    expect(calls, 4);
    transport.close();
  });
}
