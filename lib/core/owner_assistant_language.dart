import 'owner_voice_locale.dart';

/// The mobile assistant endpoint currently persists only the message body.
/// Preserve the original question in the UI, and send an explicit language
/// preference so older servers also receive it without a backend deploy.
class OwnerAssistantLanguage {
  const OwnerAssistantLanguage._();

  static const _azHint =
      '\n\n[AI response language: Azerbaijani (az-AZ). Reply in natural '
      'Azerbaijani only; use Azerbaijani in report titles, chart titles, '
      'table headings and explanations. Keep numbers unchanged.]';
  static const _enHint =
      '\n\n[AI response language: English (en-US). Reply in English, '
      'including reports and charts. Keep numbers unchanged.]';

  static String languageCode(String selected) =>
      OwnerVoiceLocale.languageCode(selected);

  static String responseLocale(String selected) =>
      OwnerVoiceLocale.ttsLocale(selected);

  /// Speech and typed questions are answered in their own language.
  /// Changing the UI language must not force answers or tool queries into AZ/RU/EN.
  /// The verified server already tells the model to answer in the user's
  /// language. Do not add an app-locale hint to the question.
  static String messageForServer(String question, String selected) =>
      question.trim();

  static String originalQuestion(String stored) {
    for (final suffix in [_azHint, _enHint]) {
      if (stored.endsWith(suffix)) {
        return stored.substring(0, stored.length - suffix.length);
      }
    }
    return stored;
  }

  static bool withinLimit(String question, String selected) =>
      messageForServer(question, selected).length <= 4000;
}
