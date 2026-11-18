/// Build-time configuration, passed with `--dart-define-from-file=config/env.json`
/// (see config/env.example.json and the README).
abstract final class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Deep link used by auth emails (magic link, password reset, confirmation).
  /// Must be listed in Supabase → Authentication → URL Configuration.
  static const authRedirect = String.fromEnvironment('AUTH_REDIRECT', defaultValue: 'seeu://auth-callback');

  /// The SeeU website (no trailing slash): shared links are https links to it
  /// (`https://<site>/@andrea`, `https://<site>/j/<token>`). The site shows the
  /// page, then opens the app with the same path on [appLinkBase] (or the stores).
  /// The domain isn't chosen yet: set WEBSITE_URL in config/env.json, and the
  /// same host in android/gradle.properties (seeu.linkHost) and Xcode
  /// (Associated Domains). See docs/WEBSITE.md.
  static const websiteUrl = String.fromEnvironment('WEBSITE_URL', defaultValue: 'https://seeu.app');

  /// The app's own scheme: `seeu://app/<same path>` opens the app directly.
  static const appLinkBase = 'seeu://app';

  /// Show the seeu:// version of a shared link next to the https one (to test
  /// opening the app before the website exists).
  static const showAppLinks = bool.fromEnvironment('SHOW_APP_LINKS', defaultValue: true);

  /// Link sent to people who don't have the app yet.
  static const appDownloadUrl = String.fromEnvironment('APP_DOWNLOAD_URL', defaultValue: 'https://seeu.app');

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
