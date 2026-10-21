import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/ui/owner_speech_stop_banner.dart';

void main() {
  testWidgets('Stop is visible and cancels speech immediately', (tester) async {
    var active = true;
    var stops = 0;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: Stack(children: [
            const Center(child: Text('A very long assistant answer')),
            if (active)
              Positioned(
                left: 16, right: 16, bottom: 12,
                child: OwnerSpeechStopBanner(onStop: () {
                  stops++;
                  setState(() => active = false);
                }),
              ),
          ]),
        ),
      ),
    ));
    expect(find.text('Стоп'), findsOneWidget);
    expect(find.byKey(const Key('owner-tts-stop')), findsOneWidget);
    await tester.tap(find.byKey(const Key('owner-tts-stop')));
    await tester.pump();
    expect(stops, 1);
    expect(find.byKey(const Key('owner-tts-stop')), findsNothing);
  });
}
