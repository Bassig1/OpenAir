/// Built-in OAuth defaults for this private OpenAir build.
/// Web client ID is public-facing (embedded in the app); keep the Android
/// client + SHA-1 registered in Google Cloud Console.
class OAuthConfig {
  const OAuthConfig._();

  static const defaultWebClientId =
      '';

  static const androidPackageName = 'com.openair.openair';
  static const debugSha1 =
      '7E:94:37:DD:EF:47:05:C0:BC:CA:7C:15:A0:98:66:C7:23:03:6A:78';
}
