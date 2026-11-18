import 'dart:async';
import 'dart:math';
import 'owner_backend.dart';

typedef AssistantCall = Future<Map<String, dynamic>> Function(
    Map<String, dynamic>);

/// One message submission, followed only by scoped reads after transport loss.
/// Reconciliation finds this request's saved answer, never another chat's last
/// message. It cannot restart a report or extend its original wall-clock budget.
class OwnerAssistantClient {
  OwnerAssistantClient({
    required this.post,
    required this.read,
    DateTime Function()? clock,
    Future<void> Function(Duration)? delay,
    String Function()? requestId,
    this.budget = const Duration(minutes: 7),
    this.pollInterval = const Duration(seconds: 3),
  })  : clock = clock ?? DateTime.now,
        delay = delay ?? Future<void>.delayed,
        requestId = requestId ?? newRequestId;

  static const postTimeout = Duration(seconds: 390);
  final AssistantCall post;
  final AssistantCall read;
  final DateTime Function() clock;
  final Future<void> Function(Duration) delay;
  final String Function() requestId;
  final Duration budget, pollInterval;

  static String newRequestId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  static bool _uncertain(OwnerApiException e) => [
        'API_TIMEOUT',
        'NETWORK_UNAVAILABLE',
        'HTTP_502',
        'HTTP_503',
        'HTTP_504',
        'HTTP_520',
        'HTTP_522',
        'HTTP_524'
      ].contains(e.code);

  Future<Map<String, dynamic>> send(Map<String, dynamic> payload,
      {bool Function()? isActive}) async {
    final id = requestId(), deadline = clock().add(budget);
    bool active() => isActive?.call() ?? true;
    void check() {
      if (!active()) {
        throw const OwnerApiException(
            'AI_REQUEST_CANCELLED', 'Контекст диалога изменился.', 409);
      }
    }

    Duration remaining() => deadline.difference(clock());
    Future<Map<String, dynamic>> get(Map<String, dynamic> query) {
      check();
      final left = remaining();
      if (left <= Duration.zero) throw _pending();
      return read(query).timeout(left < const Duration(seconds: 15)
          ? left
          : const Duration(seconds: 15));
    }

    check();
    try {
      final answer = await post({...payload, 'requestId': id})
          .timeout(budget < postTimeout ? budget : postTimeout);
      check();
      return answer;
    } on TimeoutException {
      // The server may already have accepted the single submission.
    } on OwnerApiException catch (e) {
      if (!_uncertain(e)) rethrow;
    }
    while (remaining() > Duration.zero) {
      check();
      try {
        final status = await get({'action': 'requestStatus', 'requestId': id});
        check();
        if (status['state'] == 'cancelled') {
          throw const OwnerApiException(
              'AI_REQUEST_CANCELLED', 'Формирование отчёта остановлено.', 409);
        }
        if (status['state'] == 'completed') {
          final conversationId = status['conversationId'];
          if (conversationId is String && conversationId.isNotEmpty) {
            final data = await get(
                {'action': 'messages', 'conversationId': conversationId});
            check();
            for (final item in (data['messages'] as List? ?? []).reversed) {
              if (item is! Map || item['role'] != 'assistant') continue;
              final meta = item['meta'];
              if (meta is! Map || meta['requestId'] != id) continue;
              return {
                'success': true,
                'requestId': id,
                'conversationId': conversationId,
                'answer': item['content'] ?? '',
                'kind': meta['kind'] ?? 'text',
                'report': meta['report'],
                'chart': meta['chart'],
                'charts': meta['charts'] ?? [],
                'sourceWarnings': meta['sourceWarnings'] ?? []
              };
            }
          }
        }
      } on TimeoutException {
        // A status read is safe to retry; the message POST is never replayed.
      } on OwnerApiException catch (e) {
        if (!_uncertain(e)) rethrow;
      }
      if (remaining() <= Duration.zero) break;
      await delay(remaining() < pollInterval ? remaining() : pollInterval);
    }
    throw _pending();
  }

  static OwnerApiException _pending() => const OwnerApiException(
      'AI_RESULT_UNCONFIRMED',
      'Не удалось подтвердить результат запроса. '
          'Проверьте историю диалога перед повторной отправкой.',
      504);
}
