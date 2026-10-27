import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_state.dart';
import 'package:smart_horeca_owner/screens/auth_screens.dart';
import 'package:smart_horeca_owner/ui/owner_components.dart';

const releaseMode = !bool.fromEnvironment(
  'SH_ENABLE_DEMO', defaultValue: true);

void main() {
  testWidgets('signed App Store build has no design-demo banner or preview login',
      (tester) async {
    final owner = OwnerState();
    addTearDown(owner.dispose);
    await tester.pumpWidget(OwnerScope(
      state: owner,
      child: const MaterialApp(home: Scaffold(body: OwnerDemoNotice())),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Демо дизайна'), findsNothing);
    await tester.pumpWidget(OwnerScope(
      state: owner,
      child: const MaterialApp(home: OwnerSignInScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Посмотреть утверждённый дизайн'), findsNothing);
  }, skip: !releaseMode);
}
