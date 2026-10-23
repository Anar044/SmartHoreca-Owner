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

  test('cash, receipts, reports and stock core labels have AZ and EN values', () {
    for (final language in ['Azərbaycan', 'English']) {
      for (final label in [
        'Обзор', 'Оплаты', 'Смены', 'Чеки', 'Смена', 'Чек',
        'История смен', 'Способы оплаты', 'Состав чека',
        'Продажи и выручка', 'Блюда и категории',
        'Остатки на складах', 'График', 'Таблица', 'Итого',
        'В наличии', 'Ниже минимума', 'Популярные вопросы',
        'В приложении будут показаны данные выбранных подразделений.',
        'Отчёт пока не подключён',
      ]) {
        expect(OwnerL10n.hasTranslation(language, label), isTrue,
          reason: 'Missing $language: $label');
      }
    }
  });

  test('demo prefix and split tenders translate without changing amounts', () {
    expect(OwnerL10n.previewLabel('English', 'Касса 2'), 'Register 2');
    expect(OwnerL10n.previewLabel('English', 'Смена №12548'),
        'Shift №12548');
    expect(OwnerL10n.previewLabel('English', 'Чек №25680'),
        'Receipt №25680');
    expect(OwnerL10n.previewLabel('Azərbaycan', 'Чек №25680'),
        'Çek №25680');
    expect(OwnerL10n.previewTender('English', 'Карта + Наличные'),
        'Card + Cash');
    expect(OwnerL10n.previewTender('Azərbaycan', 'Карта + Наличные'),
        'Kart + Nağd');
  });

  test('warehouse unit abbreviations are localized only in the demo', () {
    expect(OwnerL10n.previewQuantity('English', '12,5 кг'), '12,5 kg');
    expect(OwnerL10n.previewQuantity('Azərbaycan', '8,0 кг'), '8,0 kq');
    expect(OwnerL10n.previewQuantity('Русский', '-1,0 кг'), '-1,0 кг');
    expect(OwnerL10n.previewQuantity('English', 'Tomato'), 'Tomato');
  });

  test('warehouse hints exist in both translations', () {
    for (final language in ['English', 'Azərbaycan']) {
      for (final key in [
        'Поиск товара, кода...', 'Требуют проверки', 'Порог настроен'
      ]) {
        expect(OwnerL10n.hasTranslation(language, key), isTrue);
      }
    }
  });

  test('untranslated business terms are not replaced with fake translations', () {
    expect(OwnerL10n.tr('English', 'Новый отчёт iiko'), 'Новый отчёт iiko');
  });
  test('release notifications and live screens have AZ and EN labels', () {
    for (final locale in ['Azərbaycan', 'English']) {
      for (final label in [
        'Уведомления SH Owner',
        'События касс',
        'Применена скидка',
        'Удалена скидка',
        'Отменён пречек',
        'Удалено блюдо',
        'Сторнирован чек',
        'Получать уведомления',
        'Не уведомлять',
        'Уведомления временно недоступны',
        'Часть данных недоступна. Повторите запрос позже.',
        'Сервис временно недоступен. Попробуйте позже.',
        'Загружаем отчёт…',
        'Получаем данные подключённых касс…',
        'Данные ещё не загружены.',
      ]) {
        expect(OwnerL10n.hasTranslation(locale, label), isTrue,
          reason: 'Missing $locale release label: $label');
      }
    }
  });

}
