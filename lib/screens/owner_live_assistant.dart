import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../core/owner_voice_locale.dart';
import '../core/owner_ai_pdf.dart';
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
  final AudioRecorder _cloudRecorder = AudioRecorder();
  Timer? _recordingLimit;
  bool _cloudRecording = false;
  bool _transcribing = false;
  bool _exportingPdf = false;
  int _voiceGeneration = 0;
  final FlutterTts _tts = FlutterTts();
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
    unawaited(_recognizer.stop());
    unawaited(_tts.stop());
    _recordingLimit?.cancel();
    unawaited(_cloudRecorder.cancel());
    unawaited(_cloudRecorder.dispose());
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
      _recordingLimit?.cancel();
      ++_voiceGeneration;
      _cloudRecording = false;
      _transcribing = false;
      unawaited(_cloudRecorder.cancel());
      speaking = false;
      _speakingMessage = null;
      ++_speechToken;
      unawaited(_recognizer.stop());
      unawaited(_tts.stop());
    }
  }

  /// Azerbaijani is recorded locally and sent only after Stop is tapped.
  /// Native iOS recognition does not always include az-AZ; never silently
  /// substitute a Russian or English recognizer for Azerbaijani speech.
  Future<void> _toggleAzerbaijaniRecording() async {
    if (sending || _transcribing) return;
    final owner=OwnerScope.of(context);
    if(_cloudRecording){
      _recordingLimit?.cancel();
      final generation=_voiceGeneration;
      if(mounted)setState((){
        _cloudRecording=false;
        listening=false;
        _transcribing=true;
        error=null;
      });
      String? path;
      try{
        path=await _cloudRecorder.stop();
        if(path==null || path.isEmpty)throw Exception('EMPTY_RECORDING');
        if(owner.workspaceId==null)throw Exception('WORKSPACE_MISSING');
        final text=await OwnerBackend.transcribeAudio(
          workspaceId:owner.workspaceId!,
          departmentIds:owner.selectedRestaurantIds,
          audio:File(path),
          language:'az',
        );
        if(!mounted||generation!=_voiceGeneration)return;
        // The owner reviews or edits the text before pressing Send.
        controller.text=text;
        controller.selection=TextSelection.collapsed(offset:controller.text.length);
      } catch(e){
        if(mounted&&generation==_voiceGeneration){
          setState(()=>error=e is OwnerApiException
            ? '${e.message} (${e.code})'
            : 'Не удалось распознать азербайджанский голос. Повторите запись.');
        }
      } finally {
        if(path!=null&&path.isNotEmpty){
          try{await File(path).delete()}catch(_){}
        }
        if(mounted&&generation==_voiceGeneration)setState(()=>_transcribing=false);
      }
      return;
    }
    if(owner.workspaceId==null){
      setState(()=>error='Выберите организацию для голосового вопроса.');
      return;
    }
    await _stopSpeech();
    try{
      await _recognizer.stop();
      if(!await _cloudRecorder.hasPermission()){
        if(mounted)setState(()=>error='Разрешите доступ к микрофону в настройках iPhone.');
        return;
      }
      final temp=await getTemporaryDirectory();
      final path='${temp.path}/sh_owner_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _cloudRecorder.start(
        const RecordConfig(encoder:AudioEncoder.aacLc,bitRate:64000,
          sampleRate:24000,numChannels:1),
        path:path,
      );
      if(!mounted){await _cloudRecorder.cancel();return;}
      setState((){
        error=null;
        listening=true;
        _cloudRecording=true;
      });
      _recordingLimit?.cancel();
      _recordingLimit=Timer(const Duration(seconds:45),(){
        if(mounted&&_cloudRecording)unawaited(_toggleAzerbaijaniRecording());
      });
    }catch(_){
      if(mounted)setState((){
        listening=false;
        _cloudRecording=false;
        error='Не удалось записать голос. Проверьте разрешение на микрофон.';
      });
    }
  }

  Future<void> _copyAnswer(_OwnerAssistantMessage message) async {
    await Clipboard.setData(ClipboardData(text:message.text));
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:Text(OwnerL10n.tr(OwnerScope.of(context).language,
        'Ответ скопирован')),
    ));
  }

  Future<void> _shareAnswerPdf(_OwnerAssistantMessage message) async {
    if(_exportingPdf)return;
    setState(()=>_exportingPdf=true);
    try{
      await OwnerAiPdf.share(answer:message.text,chart:message.chart,report:message.report);
    }catch(_){
      if(mounted)setState(()=>error=OwnerL10n.tr(
        OwnerScope.of(context).language,
        'Не удалось создать PDF. Проверьте подключение и повторите.'));
    }finally{
      if(mounted)setState(()=>_exportingPdf=false);
    }
  }

  Future<void> _toggleListening() async {
    if (sending || _transcribing) return;
    final selectedLanguage = OwnerScope.of(context).language;
    if(OwnerVoiceLocale.languageCode(selectedLanguage)=='az'){
      await _toggleAzerbaijaniRecording();
      return;
    }
    if (listening) {
      await _recognizer.stop();
      if (mounted) setState(() => listening = false);
      return;
    }
    await _stopSpeech();
    if (!mounted) return;
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
      await _recognizer.stop();
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
    unawaited(_stopSpeech());
    ++_generation;
    setState(() {
      conversationId = null;
      conversation.clear();
      error = null;
      sending = false;
      listening = false;
      speaking = false;
      _speakingMessage = null;
    });
  }

  Future<void> _send([String? preset]) async {
    if (sending || _cloudRecording || _transcribing) return;
    final owner = OwnerScope.of(context);
    await _stopSpeech();
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
          speaking: speaking && identical(_speakingMessage, message),
          onSpeak: message.role == 'assistant'
              ? () => _readAnswer(message) : null,
          onCopy: message.role == 'assistant'
              ? () => _copyAnswer(message) : null,
          onPdf: message.role == 'assistant' && !_exportingPdf
              ? () => _shareAnswerPdf(message) : null,
          copyLabel: OwnerL10n.tr(state.language, 'Копировать ответ'),
          pdfLabel: OwnerL10n.tr(state.language, 'Экспорт в PDF'),
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
          Expanded(child: Text(OwnerL10n.tr(state.language,
             _cloudRecording
               ? 'Записываю азербайджанский голос. Нажмите Стоп.'
               : 'Слушаю… Нажми микрофон ещё раз, чтобы остановить.'))),
          TextButton(onPressed: _toggleListening,
             child: Text(OwnerL10n.tr(state.language,'Стоп'))),
        ])),
      ],
      const SizedBox(height: 12),
      if (_transcribing) const OwnerCard(child: Row(children: [
         SizedBox(width:18,height:18,
           child:CircularProgressIndicator(strokeWidth:2)),
         SizedBox(width:12),
         Expanded(child:Text('Распознаю азербайджанский голос через OpenAI…')),
       ])),
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
                onPressed: (sending || _transcribing) ? null : _toggleListening,
              ),
              IconButton(
                icon: const Icon(Icons.send_rounded),
                tooltip: 'Отправить',
                onPressed: (sending || _transcribing || _cloudRecording) ? null : _send,
              ),
            ],
          ),
        ),
        onSubmitted: (sending || _transcribing || _cloudRecording)
           ? null : (value) => _send(value),
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
