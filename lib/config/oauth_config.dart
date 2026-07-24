/// OAuth defaults for OpenAir.
///
/// Public GitHub stays empty. Your Web Client ID lives in [LocalSecrets] on this
/// machine (skip-worktree), or pass `--dart-define=GOOGLE_WEB_CLIENT_ID=...`.
///
/// Keep the Android package + SHA-1 registered in Google Cloud Console.
import 'local_secrets.dart';

class OAuthConfig {
  const OAuthConfig._();

  static const defaultWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: LocalSecrets.googleWebClientId,
  );

  static const androidPackageName = 'com.openair.openair';
  static const debugSha1 =
      '7E:94:37:DD:EF:47:05:C0:BC:CA:7C:15:A0:98:66:C7:23:03:6A:78';
}
