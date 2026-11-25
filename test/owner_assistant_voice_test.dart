import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_state.dart';
import 'package:smart_horeca_owner/core/owner_theme.dart';
import 'package:smart_horeca_owner/core/owner_voice_recording.dart';
import 'package:smart_horeca_owner/screens/owner_live_assistant.dart';

void main() {
  testWidgets('Delete preserves the draft; Stop makes a transcript editable',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final messenger = tester.binding.defaultBinaryMessenger;
    const recorder = MethodChannel('com.llfbandit.record/messages');
    const tts = MethodChannel('flutter_tts');
    const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
    final temp = Directory.systemTemp.createTempSync('owner-voice-test-');
    addTearDown(() => temp.deleteSync(recursive: true));
    String? recordingPath;
    final recordings = <File>[];
    final recorderEvents = <MethodChannel>[];
    messenger.setMockMethodCallHandler(tts, (_) async => 1);
    messenger.setMockMethodCallHandler(pathProvider, (_) async => temp.path);
    messenger.setMockMethodCallHandler(recorder, (call) async {
      switch (call.method) {
        case 'create':
          final id = (call.arguments as Map)['recorderId'];
          final events = MethodChannel('com.llfbandit.record/events/$id');
          messenger.setMockMethodCallHandler(events, (_) async => null);
          recorderEvents.add(events);
          return null;
        case 'hasPermission':
          return true;
        case 'start':
          recordingPath = '${temp.path}/recording-${recordings.length}.wav';
          final bytes = Uint8List(OwnerVoiceRecording.minBytes)
            ..setRange(0, 4, 'RIFF'.codeUnits)
            ..setRange(8, 12, 'WAVE'.codeUnits);
          recordings.add(File(recordingPath!)..writeAsBytesSync(bytes));
          return null;
        case 'stop':
          return recordingPath;
      }
      return null;
    });
    addTearDown(() {
      for (final channel in [recorder, tts, pathProvider, ...recorderEvents]) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });

    final owner = OwnerState()
      ..live = true
      ..workspaceId = 'test-workspace'
      ..language = 'Русский';
    addTearDown(owner.dispose);
    final transcription = Completer<void>();
    final recognitionPaths = <String>[];
    await tester.pumpWidget(OwnerScope(
      state: owner,
      child: MaterialApp(
        theme: OwnerPalette.dark,
        home: Scaffold(body: OwnerLiveAssistantScreen(
          transcribeVoice: (path) async {
            recognitionPaths.add(path);
            transcription.complete();
            return 'Сколько было продаж';
          },
        )),
      ),
    ));
    await tester.pumpAndSettle();

    final mic = find.byTooltip('Голосовой вопрос');
    final delete = find.byTooltip('Удалить запись');
    final stop = find.ancestor(
      of: find.text('Стоп'),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    final editor = find.byType(TextField);
    final send = find.byTooltip('Отправить');
    await tester.enterText(editor, 'Мой черновик');
    await tester.tap(mic);
    await tester.pumpAndSettle();

    expect(delete, findsOneWidget);
    expect(stop, findsOneWidget);
    expect(tester.getCenter(delete).dx, lessThan(tester.getCenter(stop).dx));
    expect(tester.getCenter(stop).dx, closeTo(160, 1));
    expect(tester.getSize(delete).width, greaterThanOrEqualTo(44));
    expect(mic, findsNothing);
    expect(send, findsNothing);

    await tester.runAsync(() async {
      await tester.tap(delete);
      await _waitForDeletion(recordings.single);
    });
    await tester.pumpAndSettle();
    expect(recognitionPaths, isEmpty);
    expect(tester.widget<TextField>(editor).controller!.text, 'Мой черновик');

    await tester.tap(mic);
    await tester.pumpAndSettle();
    expect(recordings, hasLength(2));
    await tester.runAsync(() async {
      await Future<void>.delayed(OwnerVoiceRecording.minDuration + const Duration(milliseconds: 50));
      await tester.tap(stop);
    });
    for (var attempt = 0; attempt < 80 && !transcription.isCompleted; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
    }
    expect(transcription.isCompleted, isTrue);
    await tester.runAsync(() => _waitForDeletion(recordings.last));
    await tester.pumpAndSettle();
    expect(recognitionPaths, [recordings.last.path]);
    expect(tester.widget<TextField>(editor).readOnly, isFalse);
    expect(tester.widget<TextField>(editor).controller!.text, 'Сколько было продаж');
    expect(find.text('Вы'), findsNothing);

    const edited = 'Сколько было продаж вчера?';
    await tester.enterText(editor, edited);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(editor).controller!.text, isEmpty);
    expect(find.text(edited), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

Future<void> _waitForDeletion(File file) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (await file.exists()) {
    if (DateTime.now().isAfter(deadline)) fail('Temporary recording was not deleted');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
