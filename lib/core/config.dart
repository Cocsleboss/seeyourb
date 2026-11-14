/// Build-time configuration, passed with `--dart-define-from-file=config/env.json`
/// (see config/env.example.json and the README).
abstract final class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Deep link used by auth emails (magic link, password reset, confirmation).
  /// Must be listed in Supabase → Authentication → URL Configuration.
  static const authRedirect = String.fromEnvironment('AUTH_REDIRECT', defaultValue: 'seeu://auth-callback');

  /// Base of shareable links ("Ajoute-moi sur SeeU : @andrea …").
  /// Use an https domain with App Links / Universal Links in production.
  static const shareLinkBase = String.fromEnvironment('SHARE_LINK_BASE', defaultValue: 'seeu://app');

  /// Link sent to people who don't have the app yet.
  static const appDownloadUrl = String.fromEnvironment('APP_DOWNLOAD_URL', defaultValue: 'https://seeu.app');

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
