/// OAuth defaults for OpenAir.
///
/// Do not commit your Web Client ID. Pass it at build time or paste it in Settings:
/// `flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=....apps.googleusercontent.com`
///
/// Keep the Android package + SHA-1 registered in Google Cloud Console.
class OAuthConfig {
  const OAuthConfig._();

  /// Empty in the public repo. Personal / local builds inject via dart-define.
  static const defaultWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  static const androidPackageName = 'com.openair.openair';
  static const debugSha1 =
      '7E:94:37:DD:EF:47:05:C0:BC:CA:7C:15:A0:98:66:C7:23:03:6A:78';
}
