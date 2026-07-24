/// Gemini (Google AI) access for OpenAir coaching.
///
/// Do not commit API keys. Pass one at build time or paste it in Settings:
/// `flutter run --dart-define=GEMINI_API_KEY=your_key`
class GeminiConfig {
  const GeminiConfig._();

  /// Empty by default for the public repo. Personal builds can inject a key.
  static const defaultApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  /// Prefer alias models that route to available capacity; fall back on 429/404.
  static const modelName = 'gemini-flash-latest';

  static const modelFallbacks = <String>[
    'gemini-flash-latest',
    'gemini-2.0-flash-lite',
    'gemini-2.0-flash',
    'gemini-2.5-flash',
  ];
}
