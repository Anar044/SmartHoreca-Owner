/// Locale selection for the native voice recognizer and speech synthesizer.
/// Recognition locales are device-dependent; never assume az-AZ is installed.
class OwnerVoiceLocale {
  static String languageCode(String selected) {
    final s = selected.toLowerCase();
    if (s.contains('az') || s.contains('азер') || s.contains('azer') ||
        s.contains('azərbaycan')) {
      return 'az';
    }
    if (s.contains('en') || s.contains('англ') || s.contains('english')) {
      return 'en';
    }
    return 'ru';
  }

  static String ttsLocale(String selected) {
    switch (languageCode(selected)) {
      case 'az': return 'az-AZ';
      case 'en': return 'en-US';
      default: return 'ru-RU';
    }
  }

  /// Return a supported installed recognizer locale, never a fictitious one.
  /// If the preferred app language is unavailable, let the OS decide.
  static String? availableSpeechLocale(String language, Iterable<String> ids) {
    final localeList = ids.toList(growable: false);
    final preferred = ttsLocale(language).toLowerCase();
    for (final id in localeList) {
      if (id.toLowerCase().replaceAll('_','-') == preferred.toLowerCase()) {
        return id;
      }
    }
    final prefix = '${languageCode(language)}-';
    for (final id in localeList) {
      if (id.toLowerCase().replaceAll('_','-').startsWith(prefix)) return id;
    }
    return null;
  }
}
