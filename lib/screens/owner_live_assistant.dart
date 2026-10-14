import 'package:flutter/material.dart';
import '../ui/owner_text.dart';
import '../core/owner_backend.dart';
import '../core/owner_state.dart';
import '../core/owner_theme.dart';
import '../core/owner_l10n.dart';
import '../ui/owner_components.dart';

class OwnerLiveAssistantScreen extends StatefulWidget {
  const OwnerLiveAssistantScreen({super.key});
  @override
  State<OwnerLiveAssistantScreen> createState() =>
      _OwnerLiveAssistantScreenState();
}

class _OwnerLiveAssistantScreenState extends State<OwnerLiveAssistantScreen> {
  final controller = TextEditingController();
  final List<(String, String)> conversation = [];
  bool sending = false;
  String? error;
  String? conversationId;
  String _scopeKey = '';
  int _generation = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final owner = OwnerScope.of(context);
    final ids = owner.selectedRestaurantIds.toList()..sort();
    final scope = '${owner.workspaceId}:${ids.join(',')}';
    if (_scopeKey != scope) {
      _scopeKey = scope;
      ++_generation;
      conversation.clear();
      conversationId = null;
      error = null;
      sending = false;
    }
  }

  Future<void> _send([String? preset]) async {
    if (sending) return;
    final owner = OwnerScope.of(context);
    final message = (preset ?? controller.text).trim();
    if (message.isEmpty || owner.workspaceId == null) return;
    if (message.length > 4000) {
      setState(() => error = 'Вопрос должен быть короче 4000 символов.');
      return;
    }
    final current = _generation;
    final workspaceId = owner.workspaceId!;
    final restaurantIds = owner.selectedRestaurantIds.toList();
    setState(() {
      conversation.add(('user', message));
      controller.clear();
      error = null;
      sending = true;
    });
    try {
      final result = await OwnerBackend.postJson(
        '/api/mobile/v1/assistant',
        workspaceId: workspaceId,
        departmentIds: restaurantIds,
        payload: {
          'action': 'message',
          'message': message,
          if (conversationId != null) 'conversationId': conversationId,
        },
      );
      if (!mounted || current != _generation) return;
      setState(() {
        conversationId = result['conversationId']?.toString();
        conversation.add((
          'assistant',
          (result['answer'] ?? 'AI не вернул текст ответа.').toString(),
        ));
      });
    } catch (e) {
      if (!mounted || current != _generation) return;
      setState(() => error = e is OwnerApiException ? e.message
          : 'Не удалось получить ответ AI Smart Horeca Assistant.');
    } finally {
      if (mounted && current == _generation) {
        setState(() => sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = OwnerScope.of(context);
    return OwnerScreenFrame(children: [
      const OwnerRestaurantPicker(),
      const SizedBox(height: 12),
      const OwnerHeading('AI Smart Horeca Assistant'),
      const SizedBox(height: 12),
      if (conversation.isEmpty) ...[
        OwnerCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(OwnerL10n.tr(state.language, 'Популярные вопросы'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            for (final question in const [
              'Какая выручка сегодня?',
              'Сравни продажи ресторанов',
              'Какие товары заканчиваются?',
              'Покажи топ-5 блюд',
            ]) ...[
              OutlinedButton(
                onPressed: sending ? null : () => _send(question),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(OwnerL10n.tr(state.language, question)),
                ),
              ),
              const SizedBox(height: 7),
            ],
          ],
        )),
      ],
      for (final message in conversation) ...[
        Align(
          alignment: message.$1 == 'user'
              ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: OwnerCard(child: Text(message.$2)),
          ),
        ),
        const SizedBox(height: 8),
      ],
      if (sending) const OwnerCard(child: Row(children: [
        SizedBox(width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 12),
        OwnerText('AI анализирует данные Smart Horeca…'),
      ])),
      if (error != null) ...[
        const SizedBox(height: 8),
        OwnerCard(child: Row(children: [
          const Icon(Icons.error_outline, color: OwnerPalette.error),
          const SizedBox(width: 9),
          Expanded(child: Text(error!)),
        ])),
      ],
      const SizedBox(height: 12),
      TextField(
        controller: controller,
        minLines: 1, maxLines: 5,
        decoration: InputDecoration(
          hintText: OwnerL10n.tr(state.language, 'Напишите вопрос...'),
          prefixIcon: const Icon(Icons.smart_toy_outlined),
          suffixIcon: IconButton(
            icon: const Icon(Icons.send_rounded),
            tooltip: 'Отправить',
            onPressed: sending ? null : _send,
          ),
        ),
        onSubmitted: sending ? null : (value) => _send(value),
      ),
      const SizedBox(height: 6),
      OwnerText('Только аналитика. Изменение документов и настроек через AI запрещено.',
        style: TextStyle(fontSize: 11,
          color: OwnerPalette.muted(context))),
      const SizedBox(height: 15),
    ]);
  }
}
