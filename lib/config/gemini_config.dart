/// Project-level Gemini (Google AI) free-tier access for signed-in OpenAir users.
///
/// Google does not issue a personal AI Studio key per OAuth user. Instead OpenAir
/// uses this project key after Google Health sign-in so coaching is seamless.
/// Quota is shared across installs of this build — keep the app private.
class GeminiConfig {
  const GeminiConfig._();

  /// Generative Language API key for project YOUR_GCP_PROJECT.
  static const defaultApiKey = 'REDACTED_GEMINI_KEY';

  static const modelName = 'gemini-2.0-flash';
}
