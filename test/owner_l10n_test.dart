import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_l10n.dart';

void main() {
  test('approved main navigation uses the selected language', () {
    expect(OwnerL10n.tr('Русский', 'Главная'), 'Главная');
    expect(OwnerL10n.tr('Azərbaycan', 'Главная'), 'Ana səhifə');
    expect(OwnerL10n.tr('English', 'Главная'), 'Home');
    expect(OwnerL10n.tr('Azərbaycan', 'Кассы'), 'Kassalar');
    expect(OwnerL10n.tr('English', 'Отчёты'), 'Reports');
  });

  test('profile theme and language controls are localized', () {
    for (final locale in ['Azərbaycan', 'English']) {
      for (final label in [
        'Профиль', 'Уведомления', 'Тема оформления', 'Светлая',
        'Тёмная', 'Автоматически', 'Язык интерфейса',
      ]) {
        expect(OwnerL10n.hasTranslation(locale, label), isTrue,
            reason: 'No $locale translation for $label');
      }
    }
  });

  test('untranslated business terms are not replaced with fake translations', () {
    expect(OwnerL10n.tr('English', 'Новый отчёт iiko'), 'Новый отчёт iiko');
  });
}
