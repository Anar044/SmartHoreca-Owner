import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/ui/owner_chat_bubble.dart';

void main() {
  testWidgets('Only assistant messages display export buttons', (tester) async {
    var copied = 0;
    var shared = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(
      children: [
        const OwnerChatBubble(role: 'user', text: 'Sual'),
        OwnerChatBubble(role: 'assistant', text: 'Cavab',
          onCopy: () => copied++,
          onPdf: () => shared++),
      ],
    ))));
    expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.copy_outlined));
    await tester.tap(find.byIcon(Icons.picture_as_pdf_outlined));
    expect(copied, 1);
    expect(shared, 1);
  });
}
