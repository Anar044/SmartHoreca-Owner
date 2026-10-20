import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_voice_locale.dart';

void main() {
  test('locale selection follows Russian, Azerbaijani and English UI', () {
    expect(OwnerVoiceLocale.ttsLocale('Русский'), 'ru-RU');
    expect(OwnerVoiceLocale.ttsLocale('Azərbaycan'), 'az-AZ');
    expect(OwnerVoiceLocale.ttsLocale('English'), 'en-US');
    expect(OwnerVoiceLocale.availableSpeechLocale(
        'Azərbaycan', ['ru-RU', 'az_AZ', 'en-US']), 'az_AZ');
  });

  test('never requests unavailable native speech recognition language', () {
    expect(OwnerVoiceLocale.availableSpeechLocale(
        'Azərbaycan', ['ru-RU','en-US']), isNull);
    expect(OwnerVoiceLocale.availableSpeechLocale(
        'Русский', ['ru-KZ','en-US']), 'ru-KZ');
  });
}
