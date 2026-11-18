import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_assistant_client.dart';
import 'package:smart_horeca_owner/core/owner_backend.dart';

const id = 'c0b6aef2-e7cd-4b35-a80d-dd31ab1c1b28';

void main() {
  testWidgets('a successful report can take longer than the former 120 seconds',
      (tester) async {
    Map<String, dynamic>? received;
    final client = OwnerAssistantClient(
      post: (_) => Future.delayed(const Duration(seconds: 180),
          () => {'success': true, 'answer': 'verified'}),
      read: (_) async =>
          throw StateError('successful submission must not poll'),
      requestId: () => id,
    );
    final work = client
        .send({'action': 'message', 'message': 'cost >50%'}).then(
            (v) => received = v);
    await tester.pump(const Duration(seconds: 121));
    expect(received, isNull);
    await tester.pump(const Duration(seconds: 60));
    await work;
    expect(received?['answer'], 'verified');
  });

  test('transport loss reconciles the exact saved answer without a second POST',
      () async {
    var now = DateTime.utc(2026, 11, 18), posts = 0, polls = 0;
    final queries = <Map<String, dynamic>>[];
    final client = OwnerAssistantClient(
        requestId: () => id,
        clock: () => now,
        delay: (d) async {
          now = now.add(d);
        },
        post: (p) async {
          posts++;
          expect(p['requestId'], id);
          throw TimeoutException('lost response');
        },
        read: (q) async {
          queries.add(q);
          if (q['action'] == 'requestStatus') {
            return ++polls < 3
                ? {'state': 'pending'}
                : {'state': 'completed', 'conversationId': 'verified-chat'};
          }
          return {
            'messages': [
              {
                'role': 'assistant',
                'content': 'correct',
                'meta': {
                  'requestId': id,
                  'report': {
                    'rows': [
                      ['dish', 51]
                    ]
                  },
                  'charts': [
                    {'series': []}
                  ]
                }
              },
              {
                'role': 'assistant',
                'content': 'unrelated latest answer',
                'meta': {'requestId': 'another-request'}
              },
            ]
          };
        });
    final result =
        await client.send({'action': 'message', 'message': 'question'});
    expect(posts, 1);
    expect(result['answer'], 'correct');
    expect(result['conversationId'], 'verified-chat');
    expect(result['report'], {
      'rows': [
        ['dish', 51]
      ]
    });
    expect(result['charts'], hasLength(1));
    expect(
        queries
            .where((q) => q['action'] == 'requestStatus')
            .every((q) => q['requestId'] == id),
        isTrue);
  });

  test('access denial is final and never turns into a retry or another answer',
      () async {
    var reads = 0;
    final client = OwnerAssistantClient(
        post: (_) async =>
            throw const OwnerApiException('FORBIDDEN', 'denied', 403),
        read: (_) async {
          reads++;
          return {};
        });
    await expectLater(
        client.send({}),
        throwsA(
            isA<OwnerApiException>().having((e) => e.status, 'status', 403)));
    expect(reads, 0);
  });

  test(
      'a completed status without the matching assistant message is not accepted',
      () async {
    var now = DateTime.utc(2026), posts = 0;
    final client = OwnerAssistantClient(
        requestId: () => id,
        clock: () => now,
        budget: const Duration(seconds: 7),
        delay: (d) async {
          now = now.add(d);
        },
        post: (_) async {
          posts++;
          throw const OwnerApiException('NETWORK_UNAVAILABLE', 'lost', 503);
        },
        read: (q) async => q['action'] == 'requestStatus'
            ? {'state': 'completed', 'conversationId': 'c'}
            : {
                'messages': [
                  {
                    'role': 'assistant',
                    'content': 'wrong',
                    'meta': {'requestId': 'other'}
                  }
                ]
              });
    await expectLater(
        client.send({}),
        throwsA(isA<OwnerApiException>()
            .having((e) => e.code, 'code', 'AI_RESULT_UNCONFIRMED')));
    expect(posts, 1);
    expect(now, DateTime.utc(2026).add(const Duration(seconds: 7)));
  });

  test('changing workspace or conversation stops reconciliation', () async {
    var active = true, reads = 0;
    final client = OwnerAssistantClient(post: (_) async {
      active = false;
      throw TimeoutException('lost');
    }, read: (_) async {
      reads++;
      return {};
    });
    await expectLater(
        client.send({}, isActive: () => active),
        throwsA(isA<OwnerApiException>()
            .having((e) => e.code, 'code', 'AI_REQUEST_CANCELLED')));
    expect(reads, 0);
  });

  test('a known source failure is not replayed or polled as transport loss',
      () async {
    final client = OwnerAssistantClient(
        post: (_) async => throw const OwnerApiException(
            'AI_SOURCE_TIMEOUT', 'source stopped', 504),
        read: (_) async =>
            throw StateError('must not poll a completed failure'));
    await expectLater(
        client.send({}),
        throwsA(isA<OwnerApiException>()
            .having((e) => e.code, 'code', 'AI_SOURCE_TIMEOUT')));
  });

  test('correlation IDs are valid v4 UUIDs and never reused', () {
    final ids = List.generate(100, (_) => OwnerAssistantClient.newRequestId());
    expect(ids.toSet(), hasLength(100));
    expect(
        ids.every((v) => RegExp(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(v)),
        isTrue);
  });
}
