import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/main.dart';

void main() {
  testWidgets('Smart Horeca Owner renders login design preview', (tester) async {
    await tester.pumpWidget(const SmartHorecaOwnerApp());
    expect(find.text('SMART HORECA'), findsOneWidget);
    expect(find.text('Посмотреть утверждённый дизайн'), findsOneWidget);
  });
}
