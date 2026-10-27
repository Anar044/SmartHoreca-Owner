import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_assistant_language.dart';

void main() {
  test('Azerbaijani instructions are explicit and reversible', () {
    const question = 'Bu gün restoranların satışları neçə manatdır?';
    final payload = OwnerAssistantLanguage.messageForServer(
        question, 'Azərbaycan');
    expect(payload, contains('Azerbaijani (az-AZ)'));
    expect(payload, contains(question));
    expect(OwnerAssistantLanguage.originalQuestion(payload), question);
    expect(OwnerAssistantLanguage.responseLocale('Azərbaycan'), 'az-AZ');
    expect(OwnerAssistantLanguage.languageCode('Azərbaycan'), 'az');
    expect(OwnerAssistantLanguage.withinLimit(question, 'Azərbaycan'), isTrue);
  });

  test('Russian questions are not modified', () {
    const question = 'Какая выручка сегодня?';
    expect(OwnerAssistantLanguage.messageForServer(question, 'Русский'),
        question);
    expect(OwnerAssistantLanguage.originalQuestion(question), question);
  });

  test('English response preference and request size are bounded', () {
    expect(OwnerAssistantLanguage.messageForServer('Sales', 'English'),
        contains('English (en-US)'));
    expect(OwnerAssistantLanguage.withinLimit(
        'x' * 4000, 'Azərbaycan'), isFalse);
  });
}
