/// Small, explicit owner UI localization catalog.
///
/// Only labels with approved translations are routed through this catalog.
/// Other screens will be localized in later milestones; do not silently
/// claim an entire locale is finished when strings are still Russian.
class OwnerL10n {
  const OwnerL10n._();

  static const Map<String, Map<String, String>> _translations = {
    'Azərbaycan': {
      'Главная': 'Ana səhifə',
      'Кассы': 'Kassalar',
      'Отчёты': 'Hesabatlar',
      'Ваш бизнес под контролем': 'Biznesiniz nəzarətinizdə',
      'Уведомления': 'Bildirişlər',
      'Профиль': 'Profil',
      'Мои рестораны': 'Restoranlarım',
      'Владелец ресторана': 'Restoran sahibi',
      'Настройки владельца': 'Sahib ayarları',
      'Тема оформления': 'Görünüş mövzusu',
      'Светлая': 'Açıq',
      'Тёмная': 'Qaranlıq',
      'Автоматически': 'Avtomatik',
      'Язык интерфейса': 'İnterfeys dili',
      'Безопасность': 'Təhlükəsizlik',
      'Авторизация и биометрия подключаются отдельно':
          'Giriş və biometrik qoruma ayrıca qoşulacaq',
      'Выйти из демо': 'Demodan çıx',
      'Выйти': 'Çıxış',
      'Ваш бизнес всегда под контролем': 'Biznesiniz hər zaman nəzarətinizdə',
      'Вход в аккаунт': 'Hesaba giriş',
      'Пароль': 'Şifrə',
      'Войти': 'Daxil ol',
      'Посмотреть утверждённый дизайн': 'Təsdiqlənmiş dizayna bax',
      'Выбор ресторанов': 'Restoran seçimi',
      'Выберите рестораны': 'Restoranları seçin',
      'Выбрать все': 'Hamısını seç',
      'Применить': 'Tətbiq et',
      'Доступно': 'Mövcuddur',
      'Обзор бизнеса': 'Biznes icmalı',
      'Все рестораны': 'Bütün restoranlar',
      'Сегодня': 'Bu gün',
      'Вчера': 'Dünən',
      '7 дней': '7 gün',
      'Месяц': 'Ay',
      'Выручка': 'Satış gəliri',
      'Чеков': 'Çeklər',
      'Средний чек': 'Orta çek',
      'Валовая прибыль': 'Ümumi mənfəət',
      'Валовая прибыль*': 'Ümumi mənfəət*',
      'Выручка по ресторанам': 'Restoranlar üzrə satış',
      'Популярные блюда': 'Populyar yeməklər',
      'Выручка по дням': 'Günlər üzrə satış',
      'Выручка по часам': 'Saatlar üzrə satış',
      'Выручка по неделям': 'Həftələr üzrə satış',
      'Выбран': 'Seçilib',
      'Повторить': 'Yenidən cəhd et',
      'Демо дизайна • данные условные, API пока не подключён':
          'Dizayn nümunəsi • məlumatlar şərtidir, API qoşulmayıb',
      'Перевод остальных разделов находится в разработке':
          'Digər bölmələrin tərcüməsi hazırlanır',
      'Русский': 'Русский',
      'Azərbaycan': 'Azərbaycan',
      'English': 'English',
    },
    'English': {
      'Главная': 'Home',
      'Кассы': 'Registers',
      'Отчёты': 'Reports',
      'Ваш бизнес под контролем': 'Your business at a glance',
      'Уведомления': 'Notifications',
      'Профиль': 'Profile',
      'Мои рестораны': 'My restaurants',
      'Владелец ресторана': 'Restaurant owner',
      'Настройки владельца': 'Owner settings',
      'Тема оформления': 'Appearance',
      'Светлая': 'Light',
      'Тёмная': 'Dark',
      'Автоматически': 'System',
      'Язык интерфейса': 'App language',
      'Безопасность': 'Security',
      'Авторизация и биометрия подключаются отдельно':
          'Sign-in and biometric security are coming later',
      'Выйти из демо': 'Exit preview',
      'Выйти': 'Sign out',
      'Ваш бизнес всегда под контролем': 'Your business, always in view',
      'Вход в аккаунт': 'Sign in',
      'Пароль': 'Password',
      'Войти': 'Sign in',
      'Посмотреть утверждённый дизайн': 'View approved design',
      'Выбор ресторанов': 'Select restaurants',
      'Выберите рестораны': 'Select restaurants',
      'Выбрать все': 'Select all',
      'Применить': 'Apply',
      'Доступно': 'Available',
      'Обзор бизнеса': 'Business overview',
      'Все рестораны': 'All restaurants',
      'Сегодня': 'Today',
      'Вчера': 'Yesterday',
      '7 дней': '7 days',
      'Месяц': 'Month',
      'Выручка': 'Revenue',
      'Чеков': 'Checks',
      'Средний чек': 'Average check',
      'Валовая прибыль': 'Gross profit',
      'Валовая прибыль*': 'Gross profit*',
      'Выручка по ресторанам': 'Revenue by restaurant',
      'Популярные блюда': 'Top dishes',
      'Выручка по дням': 'Daily revenue',
      'Выручка по часам': 'Hourly revenue',
      'Выручка по неделям': 'Weekly revenue',
      'Выбран': 'Selected',
      'Повторить': 'Retry',
      'Демо дизайна • данные условные, API пока не подключён':
          'Design preview • illustrative data; API not connected',
      'Перевод остальных разделов находится в разработке':
          'Translation of other sections is still in progress',
      'Русский': 'Русский',
      'Azərbaycan': 'Azərbaycan',
      'English': 'English',
    },
  };

  static String tr(String language, String sourceRussian) =>
      _translations[language]?[sourceRussian] ?? sourceRussian;

  static bool hasTranslation(String language, String sourceRussian) =>
      language == 'Русский' ||
      (_translations[language]?.containsKey(sourceRussian) ?? false);
}
