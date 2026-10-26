import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/ui/owner_chat_bubble.dart';

void main() {
  testWidgets('user and assistant are visibly identified, with optional speech',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
      const OwnerChatBubble(role: 'user', text: 'Покажи продажи блюд'),
      OwnerChatBubble(
        role: 'assistant',
        text: 'Проверяю продажи за октябрь.',
        onSpeak: () {},
        onCopy: () {},
        onPdf: () {},
      ),
    ]))));
    expect(find.text('Вы'), findsOneWidget);
    expect(find.text('AI Smart Horeca'), findsOneWidget);
    expect(find.byType(SelectableText), findsNWidgets(2));
    expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
  });
}
