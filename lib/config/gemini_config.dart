/// Project-level Gemini (Google AI) free-tier access for signed-in OpenAir users.
///
/// Google does not issue a personal AI Studio key per OAuth user. Instead OpenAir
/// uses this project key after Google Health sign-in so coaching is seamless.
/// Quota is shared across installs of this build — keep the app private.
class GeminiConfig {
  const GeminiConfig._();

  /// Generative Language API key for project vibrant-petal-503305-b8.
  static const defaultApiKey = 'AIzaSyBoP3HEOSn85X82FBSOzcmOKvnSHSm4D1g';

  static const modelName = 'gemini-2.0-flash';
}
