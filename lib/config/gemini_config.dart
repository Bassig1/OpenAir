/// Gemini (Google AI) access for OpenAir coaching.
///
/// Public GitHub stays empty. Your keys live in [LocalSecrets] on this machine
/// (skip-worktree), or pass `--dart-define=GEMINI_API_KEY=...`.
import 'local_secrets.dart';

class GeminiConfig {
  const GeminiConfig._();

  static const defaultApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: LocalSecrets.geminiApiKey,
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
