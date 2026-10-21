import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../core/owner_voice_locale.dart';
import 'owner_assistant_visuals.dart';
import '../ui/owner_text.dart';
import '../core/owner_backend.dart';
import '../core/owner_state.dart';
import '../core/owner_theme.dart';
import '../core/owner_l10n.dart';
import '../ui/owner_components.dart';
import '../ui/owner_chat_bubble.dart';

class _OwnerAssistantMessage {
  final String role;
  final String text;
  final Map<String, dynamic>? chart;
  final Map<String, dynamic>? report;
  final bool chartMissing;
  final List<Map<String,dynamic>> sourceWarnings;
  const _OwnerAssistantMessage(this.role, this.text,
      {this.chart, this.report, this.chartMissing = false,
       this.sourceWarnings = const []});
}

class OwnerLiveAssistantScreen extends StatefulWidget {
  const OwnerLiveAssistantScreen({super.key});
  @override
  State<OwnerLiveAssistantScreen> createState() =>
      _OwnerLiveAssistantScreenState();
}

class _OwnerLiveAssistantScreenState extends State<OwnerLiveAssistantScreen> {
  final controller = TextEditingController();
  final stt.SpeechToText _recognizer = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final List<_OwnerAssistantMessage> conversation = [];
  bool listening = false;
  bool speaking = false;
  String? modelName;
  bool sending = false;
  String? error;
  String? conversationId;
  String _scopeKey = '';
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => speaking = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => speaking = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => speaking = false);
    });
  }

  @override
  void dispose() {
    unawaited(_recognizer.stop());
    unawaited(_tts.stop());
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
      listening = false;
      speaking = false;
      modelName = null;
      unawaited(_recognizer.stop());
      unawaited(_tts.stop());
      unawaited(_fetchModel(owner.workspaceId, owner.selectedRestaurantIds, _generation));
    }
  }

  Future<void> _fetchModel(
    String? workspaceId, Set<String> departmentIds, int generation) async {
    if (workspaceId == null || departmentIds.isEmpty) return;
    try {
      final data = await OwnerBackend.getJson(
        '/api/mobile/v1/assistant',
        workspaceId: workspaceId,
        departmentIds: departmentIds,
        query: const {'action':'status'},
      );
      if (!mounted || generation != _generation) return;
      final model = (data['model'] ?? '').toString().trim();
      if (model.isNotEmpty) setState(() => modelName = model);
    } catch (_) {
      // The assistant remains usable if the optional model badge fails.
    }
  }

  Future<void> _toggleListening() async {
    if (sending) return;
    final selectedLanguage = OwnerScope.of(context).language;
    if (listening) {
      await _recognizer.stop();
      if (mounted) setState(() => listening = false);
      return;
    }
    await _tts.stop();
    if (mounted) setState(() => speaking = false);
    try {
      final ready = await _recognizer.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => listening = false);
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              listening = false;
              error = 'Не удалось распознать речь: ${e.errorMsg}.';
            });
          }
        },
      );
      if (!ready) {
        if (mounted) {
          setState(() =>
            error = 'Распознавание речи недоступно. Проверь разрешения микрофона и речи в настройках iPhone.');
        }
        return;
      }
      final locales = await _recognizer.locales();
      final locale = OwnerVoiceLocale.availableSpeechLocale(
        selectedLanguage, locales.map((l) => l.localeId));
      if (!mounted) return;
      setState(() {
        error = null;
        listening = true;
      });
      await _recognizer.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: locale,
          partialResults: true,
          cancelOnError: true,
        ),
        onResult: (result) {
          if (!mounted) return;
          controller.text = result.recognizedWords;
          controller.selection = TextSelection.collapsed(
            offset: controller.text.length);
          if (result.finalResult) {
            setState(() => listening = false);
          }
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          listening = false;
          error = 'Не удалось включить микрофон. Проверь разрешения в настройках устройства.';
        });
      }
    }
  }

  Future<void> _readAnswer(String text) async {
    final locale = OwnerVoiceLocale.ttsLocale(OwnerScope.of(context).language);
    if (speaking) {
      await _tts.stop();
      if (mounted) setState(() => speaking = false);
      return;
    }
    await _recognizer.stop();
    if (!mounted) return;
    // Spoken text is only delivered to the device OS TTS; do not send
    // confidential restaurant answers to a new third-party endpoint.
    try {
      final installed = await _tts.isLanguageAvailable(locale);
      if (installed != true) {
        if (mounted) {
          setState(() =>
            error = 'На устройстве не найден голос для языка $locale. Установи голос в настройках iPhone.');
        }
        return;
      }
      await _tts.setLanguage(locale);
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      if (!mounted) return;
      setState(() {
        speaking = true;
        error = null;
      });
      final spoken = text.replaceAll(RegExp(r'[*#_`]+'), '');
      await _tts.speak(spoken.length > 3000
          ? spoken.substring(0, 3000) : spoken);
    } catch (_) {
      if (mounted) {
        setState(() {
          speaking = false;
          error = 'Не удалось озвучить ответ. Проверь настройки речи устройства.';
        });
      }
    }
  }

  Future<void> _refreshCurrentConversation() async {
    final id = conversationId;
    if (id != null && id.isNotEmpty) {
      await _openChat(id);
    } else if (mounted) {
      setState(() => error = null);
    }
  }

  Future<void> _showHistory() async {
    final owner = OwnerScope.of(context);
    final workspace = owner.workspaceId;
    if (workspace == null) return;
    final generation = _generation;
    try {
      final data = await OwnerBackend.getJson(
        '/api/mobile/v1/assistant',
        workspaceId: workspace,
        departmentIds: owner.selectedRestaurantIds,
        query: {'action': 'conversations'},
      );
      if (!mounted || generation != _generation) return;
      final chats = (data['conversations'] as List? ?? [])
          .whereType<Map<String, dynamic>>().toList();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(18),
              children: [
                const OwnerHeading('История диалогов'),
                const SizedBox(height: 12),
                if (chats.isEmpty)
                  const Text('Пока нет сохранённых разговоров.'),
                for (final chat in chats)
                  ListTile(
                    leading: const Icon(Icons.chat_outlined),
                    title: Text((chat['title'] ?? 'Новый чат').toString()),
                    subtitle: Text((chat['updated_at'] ?? '').toString()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openChat((chat['id'] ?? '').toString());
                    },
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => error = e is OwnerApiException
            ? e.message : 'Не удалось получить историю разговоров.');
      }
    }
  }

  Future<void> _openChat(String id) async {
    if (id.isEmpty) return;
    final owner = OwnerScope.of(context);
    if (owner.workspaceId == null) return;
    final generation = _generation;
    try {
      final result = await OwnerBackend.getJson(
        '/api/mobile/v1/assistant',
        workspaceId: owner.workspaceId,
        departmentIds: owner.selectedRestaurantIds,
        query: {'action':'messages','conversationId':id},
      );
      if (!mounted || generation != _generation) return;
      final messages = (result['messages'] as List? ?? [])
          .whereType<Map<String,dynamic>>()
          .where((m) => m['role'] == 'user' || m['role'] == 'assistant')
          .map((m) {
            final meta = OwnerAssistantVisuals.structured(m['meta']);
            return _OwnerAssistantMessage(
              m['role'].toString(), (m['content'] ?? '').toString(),
              chart: OwnerAssistantVisuals.structured(meta?['chart']),
              report: OwnerAssistantVisuals.structured(meta?['report']),
              sourceWarnings: (meta?['sourceWarnings'] as List? ?? [])
                  .whereType<Map<String,dynamic>>().toList(),
            );
          }).toList();
      setState(() {
        conversationId = id;
        conversation
          ..clear()
          ..addAll(messages);
        error = null;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => error = e is OwnerApiException
            ? e.message : 'Не удалось открыть разговор.');
      }
    }
  }

  void _newConversation() {
    unawaited(_recognizer.stop());
    unawaited(_tts.stop());
    ++_generation;
    setState(() {
      conversationId = null;
      conversation.clear();
      error = null;
      sending = false;
      listening = false;
      speaking = false;
    });
  }

  Future<void> _send([String? preset]) async {
    if (sending) return;
    final owner = OwnerScope.of(context);
    await _recognizer.stop();
    if (!mounted) return;
    setState(() => listening = false);
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
      conversation.add(_OwnerAssistantMessage('user', message));
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
        conversation.add(_OwnerAssistantMessage(
          'assistant',
          (result['answer'] ?? 'AI не вернул текст ответа.').toString(),
          chart: OwnerAssistantVisuals.structured(result['chart']),
          report: OwnerAssistantVisuals.structured(result['report']),
          sourceWarnings: (result['sourceWarnings'] as List? ?? [])
              .whereType<Map<String,dynamic>>().toList(),
          chartMissing: RegExp(
            r'график|диаграм|chart|graph|diaqram|qrafik',
            caseSensitive: false,
          ).hasMatch(message) && result['chart'] == null,
        ));
      });
    } catch (e) {
      if (!mounted || current != _generation) return;
      setState(() => error = e is OwnerApiException
          ? '${e.message} (${e.code})'
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
    return OwnerScreenFrame(onRefresh: _refreshCurrentConversation, children: [
      const OwnerRestaurantPicker(),
      const SizedBox(height: 12),
      const OwnerHeading('AI Smart Horeca Assistant'),
      if (modelName != null) ...[
        const SizedBox(height: 4),
        Text('Модель: $modelName · Только чтение',
          style: TextStyle(fontSize: 11, color: OwnerPalette.muted(context))),
      ],
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _showHistory,
            icon: const Icon(Icons.history, size: 18),
            label: Text(OwnerL10n.tr(state.language, 'История диалогов')),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          tooltip: OwnerL10n.tr(state.language, 'Новый чат'),
          onPressed: _newConversation,
          icon: const Icon(Icons.add_comment_outlined),
        ),
      ]),
      const SizedBox(height: 12),
      if (conversation.isEmpty) ...[
        OwnerCard(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(OwnerL10n.tr(state.language, 'Популярные вопросы'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            for (final question in const [
              'Какая выручка сегодня по выбранным ресторанам?',
              'Сравни выручку ресторанов за 7 дней и покажи график',
              'Покажи топ-5 блюд по выручке за сегодня',
              'Какие товары заканчиваются?',
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
        OwnerChatBubble(
          role: message.role,
          text: message.text,
          speaking: speaking && message.role == 'assistant',
          onSpeak: message.role == 'assistant'
              ? () => _readAnswer(message.text) : null,
        ),
        if (message.role == 'assistant' &&
            (message.chart != null || message.report != null))
          OwnerAssistantVisuals(chart: message.chart, report: message.report),
        if (message.role == 'assistant' &&
            message.sourceWarnings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 5, bottom: 7),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded,
                color: OwnerPalette.warning, size: 17),
              const SizedBox(width: 8),
              Expanded(child: Text(
                message.sourceWarnings
                    .map((item) => (item['code'] ?? 'SOURCE_UNAVAILABLE').toString())
                    .toSet().join(', ') +
                    ' — источник не вернул полный отчёт. '
                    'Попробуйте повторить вопрос позже.',
                style: TextStyle(fontSize: 12,
                  color: OwnerPalette.muted(context)),
              )),
            ]),
          ),
        if (message.chartMissing)
          OwnerCard(child: Row(children: [
            const Icon(Icons.info_outline, color: OwnerPalette.warning),
            const SizedBox(width: 9),
            Expanded(child: Text(OwnerL10n.tr(state.language,
              'AI вернул только текст. Числовые данные диаграммы не получены.'))),
          ])),
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
      if (listening) ...[
        const SizedBox(height: 8),
        OwnerCard(child: Row(children: [
          const Icon(Icons.mic, color: Colors.redAccent),
          const SizedBox(width: 8),
          const Expanded(child: Text('Слушаю… Нажми микрофон ещё раз, чтобы остановить.')),
          TextButton(onPressed: _toggleListening, child: const Text('Стоп')),
        ])),
      ],
      const SizedBox(height: 12),
      TextField(
        controller: controller,
        minLines: 1, maxLines: 5,
        decoration: InputDecoration(
          hintText: OwnerL10n.tr(state.language, 'Напишите вопрос...'),
          prefixIcon: const Icon(Icons.smart_toy_outlined),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(listening ? Icons.stop_circle_outlined
                    : Icons.mic_none_rounded,
                    color: listening ? Colors.redAccent
                        : OwnerPalette.accent(context)),
                tooltip: listening ? 'Остановить запись' : 'Голосовой вопрос',
                onPressed: sending ? null : _toggleListening,
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded),
                tooltip: 'Отправить',
                onPressed: sending ? null : _send,
              ),
            ],
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
