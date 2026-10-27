import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../core/owner_voice_locale.dart';
import '../core/owner_voice_recording.dart';
import '../core/owner_assistant_language.dart';
import '../core/owner_assistant_charts.dart';
import '../core/owner_ai_export.dart';
import 'owner_assistant_visuals.dart';
import '../ui/owner_text.dart';
import '../core/owner_backend.dart';
import '../core/owner_state.dart';
import '../core/owner_theme.dart';
import '../core/owner_l10n.dart';
import '../ui/owner_components.dart';
import '../ui/owner_chat_bubble.dart';
import '../ui/owner_speech_stop_banner.dart';

class _OwnerAssistantMessage {
  final String role;
  final String text;
  final Map<String, dynamic>? chart;
  final List<Map<String, dynamic>> charts;
  final Map<String, dynamic>? report;
  final bool chartMissing;
  final List<Map<String,dynamic>> sourceWarnings;
  const _OwnerAssistantMessage(this.role, this.text,
      {this.chart, this.charts = const [], this.report,
       this.chartMissing = false,
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
  final FlutterTts _tts = FlutterTts();
  final AudioRecorder _cloudRecorder = AudioRecorder();
  bool _transcribing = false;
  DateTime? _recordingStartedAt;
  final List<_OwnerAssistantMessage> conversation = [];
  bool listening = false;
  bool speaking = false;
  _OwnerAssistantMessage? _speakingMessage;
  int _speechToken = 0;
  bool sending = false;
  String? error;
  String? conversationId;
  String _scopeKey = '';
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _tts.setCompletionHandler(_finishSpeech);
    _tts.setCancelHandler(_finishSpeech);
    _tts.setErrorHandler((_) => _finishSpeech);
  }

  void _finishSpeech() {
    if (!mounted || !speaking) return;
    setState(() {
      speaking = false;
      _speakingMessage = null;
    });
  }

  /// Invalidate pending async TTS setup BEFORE awaiting native stop.
  /// The button updates immediately, even if the iOS speaker is busy.
  Future<void> _stopSpeech() async {
    ++_speechToken;
    if (mounted && (speaking || _speakingMessage != null)) {
      setState(() {
        speaking = false;
        _speakingMessage = null;
      });
    }
    await _tts.stop();
  }

  @override
  void dispose() {
    ++_speechToken;
    unawaited(_tts.stop());
    unawaited(_closeCloudRecorder());
    controller.dispose();
    super.dispose();
  }

  Future<void> _cancelCloudRecording() async {
    try { await _cloudRecorder.cancel(); } catch (_) {}
  }

  Future<void> _closeCloudRecorder() async {
    await _cancelCloudRecording();
    await _cloudRecorder.dispose();
  }

  /// Always record explicitly into a well-formed WAV for language-agnostic
  /// transcription. No phone or app locale is used for speech recognition.
  Future<void> _startCloudListening() async {
    final generation = _generation;
    try {
      if (!await _cloudRecorder.hasPermission()) {
        if (mounted) {
          setState(() => error = OwnerL10n.tr(
            OwnerScope.of(context).language, 'Нет разрешения на микрофон.'));
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/sh-owner-voice-'
          '${DateTime.now().microsecondsSinceEpoch}.wav';
      await _cloudRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
      _recordingStartedAt = DateTime.now();
      if (!mounted || generation != _generation) {
        await _cancelCloudRecording();
        return;
      }
      setState(() {
        error = null;
        listening = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          listening = false;
          error = OwnerL10n.tr(OwnerScope.of(context).language,
              'Не удалось начать запись голоса.');
        });
      }
    }
  }

  Future<void> _finishCloudListening() async {
    final generation = _generation;
    setState(() {
      listening = false;
      _transcribing = true;
    });
    String? path;
    try {
      final startedAt = _recordingStartedAt;
      _recordingStartedAt = null;
      if (startedAt == null ||
          DateTime.now().difference(startedAt) <
              OwnerVoiceRecording.minDuration) {
        await _cancelCloudRecording();
        throw const OwnerApiException('VOICE_TOO_SHORT',
          'Слишком короткая запись. Говорите не менее одной секунды.', 422);
      }
      // AVAudioRecorder/Android must finalize the RIFF/WAV header before upload.
      path = await _cloudRecorder.stop();
      if (path == null || !await OwnerVoiceRecording.hasValidWavFile(path)) {
        throw const OwnerApiException('VOICE_INVALID_WAV',
          'Не удалось сохранить голосовой вопрос. Попробуйте ещё раз.', 422);
      }
      final transcript = await OwnerBackend.transcribeVoice(path);
      if (!mounted || generation != _generation) return;
      setState(() {
        controller.text = transcript;
        controller.selection = TextSelection.collapsed(
          offset: controller.text.length);
        error = null;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        final language = OwnerScope.of(context).language;
        setState(() => error = e is OwnerApiException
          ? OwnerL10n.tr(language, e.message)
          : OwnerL10n.tr(language,
              'Не удалось распознать голосовой вопрос.'));
      }
    } finally {
      if (path != null) {
        try { await File(path).delete(); } catch (_) {}
      }
      if (mounted && generation == _generation) {
        setState(() => _transcribing = false);
      }
    }
  }

  Future<void> _copyAnswer(_OwnerAssistantMessage message) async {
    await OwnerAiExport.copyAnswerWithVisuals(
      answer: message.text,
      report: message.report,
      charts: message.charts,
      chart: message.chart,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(OwnerL10n.tr(OwnerScope.of(context).language,
        'Ответ скопирован')),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _exportAnswerPdf(_OwnerAssistantMessage message) async {
    try {
      await OwnerAiExport.shareAnswerPdf(
        answer: message.text,
        report: message.report,
        chart: message.chart,
        charts: message.charts,
      );
    } catch (_) {
      if (mounted) {
        setState(() => error = OwnerL10n.tr(
          OwnerScope.of(context).language,
          'Не удалось создать PDF. Проверьте соединение и повторите.'));
      }
    }
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
      _transcribing = false;
      _recordingStartedAt = null;
      unawaited(_cancelCloudRecording());
      speaking = false;
      _speakingMessage = null;
      ++_speechToken;
      unawaited(_tts.stop());
    }
  }

  Future<void> _toggleListening() async {
    if (sending || _transcribing) return;
    if (listening) {
      await _finishCloudListening();
      return;
    }
    await _stopSpeech();
    if (!mounted) return;
    // Always use one multilingual transcription pipeline. Neither the app
    // language nor the iPhone/Android speech locale selects the input language.
    await _startCloudListening();
  }

  Future<void> _readAnswer(_OwnerAssistantMessage message) async {
    if (speaking && identical(_speakingMessage, message)) {
      await _stopSpeech();
      return;
    }

    // Another answer may be playing. Never allow two speeches to overlap.
    await _stopSpeech();
    if (!mounted) return;
    final locale = OwnerVoiceLocale.ttsLocale(OwnerScope.of(context).language);
    final requestToken = ++_speechToken;
    setState(() {
      speaking = true; // Show Stop even while iOS prepares the voice.
      _speakingMessage = message;
      error = null;
    });

    bool stillCurrent() => mounted && requestToken == _speechToken;
    try {
      if (!stillCurrent()) return;
      final installed = await _tts.isLanguageAvailable(locale);
      if (!stillCurrent()) return;
      if (installed != true) {
        _finishSpeech();
        setState(() => error =
          'На устройстве не найден голос для языка $locale. Установи голос в настройках iPhone.');
        return;
      }
      await _tts.setLanguage(locale);
      if (!stillCurrent()) return;
      await _tts.setSpeechRate(0.48);
      if (!stillCurrent()) return;
      await _tts.setVolume(1.0);
      if (!stillCurrent()) return;
      final spoken = message.text.replaceAll(RegExp(r'[*#_`]+'), '');
      if (spoken.isEmpty) {
        _finishSpeech();
        return;
      }
      // Keep 3,000-char limit; the Stop banner stays available at all times.
      await _tts.speak(spoken.length > 3000
          ? spoken.substring(0, 3000) : spoken);
    } catch (_) {
      if (stillCurrent()) {
        _finishSpeech();
        setState(() =>
          error = 'Не удалось озвучить ответ. Проверь настройки речи устройства.');
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
                  const OwnerText('Пока нет сохранённых разговоров.'),
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
    await _stopSpeech();
    if (!mounted) return;
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
              m['role'].toString(),
              m['role'] == 'user'
                ? OwnerAssistantLanguage.originalQuestion(
                    (m['content'] ?? '').toString())
                : (m['content'] ?? '').toString(),
              chart: OwnerAssistantVisuals.structured(meta?['chart']),
              charts: OwnerAssistantCharts.fromApi(
                meta?['charts'], meta?['chart']),
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
    unawaited(_cancelCloudRecording());
    unawaited(_stopSpeech());
    ++_generation;
    setState(() {
      conversationId = null;
      conversation.clear();
      error = null;
      sending = false;
      listening = false;
      _transcribing = false;
      _recordingStartedAt = null;
      speaking = false;
      _speakingMessage = null;
    });
  }

  Future<void> _send([String? preset]) async {
    if (sending || _transcribing || listening) return;
    final owner = OwnerScope.of(context);
    await _stopSpeech();
    if (!mounted) return;
    setState(() => listening = false);
    final message = (preset ?? controller.text).trim();
    if (message.isEmpty || owner.workspaceId == null) return;

    // A follow-up asking to visualize already-rendered verified report rows
    // is fulfilled locally, without a fresh AI or accounting-server query.
    // The active conversation is reset whenever workspace/restaurants change.
    if (OwnerAssistantCharts.isPreviousReportChartRequest(message) &&
        conversation.isNotEmpty) {
      Map<String, dynamic>? precedingReport;
      for (final prior in conversation.reversed) {
        if (prior.role == 'assistant' && prior.report != null) {
          precedingReport = prior.report;
          break;
        }
      }
      final graph = OwnerAssistantCharts.fromReport(precedingReport);
      if (graph != null) {
        final answer = switch (OwnerVoiceLocale.languageCode(owner.language)) {
          'az' => 'Qrafik əvvəlki təsdiqlənmiş hesabatın sətirləri üzrə quruldu.',
          'en' => 'Chart created from the previously verified report rows.',
          _ => 'График построен по строкам предыдущего проверенного отчёта.',
        };
        setState(() {
          conversation.add(_OwnerAssistantMessage('user', message));
          conversation.add(_OwnerAssistantMessage('assistant', answer,
            charts: [graph]));
          controller.clear();
          error = null;
        });
        return;
      }
    }
    if (!OwnerAssistantLanguage.withinLimit(message, owner.language)) {
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
          'message': OwnerAssistantLanguage.messageForServer(
            message, owner.language),
          'language': 'auto',
          'responseLanguage': 'auto',
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
          charts: OwnerAssistantCharts.fromApi(
            result['charts'], result['chart']),
          report: OwnerAssistantVisuals.structured(result['report']),
          sourceWarnings: (result['sourceWarnings'] as List? ?? [])
              .whereType<Map<String,dynamic>>().toList(),
          chartMissing: RegExp(
            r'график|диаграм|chart|graph|diaqram|qrafik',
            caseSensitive: false,
          ).hasMatch(message) &&
              OwnerAssistantCharts.fromApi(
                result['charts'], result['chart']).isEmpty,
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
    return Stack(children: [
      OwnerScreenFrame(onRefresh: _refreshCurrentConversation, children: [
      const OwnerRestaurantPicker(),
      const SizedBox(height: 12),
      const OwnerHeading('AI Smart Horeca Assistant'),
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
                onPressed: sending ? null :
                    () => _send(OwnerL10n.tr(state.language, question)),
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
          userLabel: OwnerL10n.tr(state.language, 'Вы'),
          speaking: speaking && identical(_speakingMessage, message),
          onSpeak: message.role == 'assistant'
              ? () => _readAnswer(message) : null,
          onCopy: message.role == 'assistant'
              ? () => _copyAnswer(message) : null,
          onPdf: message.role == 'assistant'
              ? () => _exportAnswerPdf(message) : null,
          copyTooltip: OwnerL10n.tr(state.language, 'Скопировать ответ'),
          pdfTooltip: OwnerL10n.tr(state.language, 'Экспорт в PDF'),
          speakTooltip: OwnerL10n.tr(state.language, 'Озвучить ответ'),
          stopSpeakTooltip: OwnerL10n.tr(state.language,
            'Остановить озвучивание'),
        ),
        if (message.role == 'assistant' &&
            (message.chart != null || message.charts.isNotEmpty ||
             message.report != null))
          OwnerAssistantVisuals(
            chart: message.chart,
            charts: message.charts,
            report: message.report,
            onCopy: () => _copyAnswer(message),
            onPdf: () => _exportAnswerPdf(message),
            copyTooltip: OwnerL10n.tr(state.language, 'Скопировать ответ'),
            pdfTooltip: OwnerL10n.tr(state.language, 'Экспорт в PDF'),
          ),
        if (message.role == 'assistant' &&
            message.sourceWarnings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 5, bottom: 7),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded,
                color: OwnerPalette.warning, size: 17),
              const SizedBox(width: 8),
              Expanded(child: Text(
                 OwnerL10n.tr(state.language,
                   'Часть данных недоступна. Повторите запрос позже.'),
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
      if (_transcribing)
        const OwnerCard(child: Row(children: [
          SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          OwnerText('Распознаём голосовой вопрос…'),
        ])),
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
          const Expanded(child: OwnerText('Слушаю… Нажми микрофон ещё раз, чтобы остановить.')),
          TextButton(onPressed: _toggleListening, child: const OwnerText('Стоп')),
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
                tooltip: OwnerL10n.tr(state.language,
                  listening ? 'Остановить запись' : 'Голосовой вопрос'),
                onPressed: sending || _transcribing ? null : _toggleListening,
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded),
                tooltip: OwnerL10n.tr(state.language, 'Отправить'),
                onPressed: sending || _transcribing ? null : _send,
              ),
            ],
          ),
        ),
        onSubmitted: sending || _transcribing ? null : (value) => _send(value),
      ),
      const SizedBox(height: 6),
      OwnerText('Только аналитика. Изменение документов и настроек через AI запрещено.',
        style: TextStyle(fontSize: 11,
          color: OwnerPalette.muted(context))),
      const SizedBox(height: 15),
      ]),
      if (speaking)
        Positioned(
          left: 16, right: 16, bottom: 12,
          child: OwnerSpeechStopBanner(
            onStop: () => unawaited(_stopSpeech()),
          ),
        ),
    ]);
  }
}
