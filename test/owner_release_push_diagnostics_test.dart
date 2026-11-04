import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_state.dart';
import 'package:smart_horeca_owner/screens/profile_screen.dart';

void main() {
  testWidgets('live owner exposes safe push diagnostics in release UI',
      (tester) async {
    final state = OwnerState()
      ..live = true
      ..stage = OwnerStage.shell;
    addTearDown(state.dispose);
    await tester.pumpWidget(OwnerScope(
      state: state,
      child: const MaterialApp(home: OwnerNotificationsScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Проверить подключение push'), findsOneWidget);
    expect(find.text('Складские предупреждения'), findsNothing);
    expect(find.text('Низкий остаток'), findsNothing);
    // Disabled when Firebase isn't configured, but diagnostic isn't
    // silently hidden solely because the app is an App Store release.
  });
}
