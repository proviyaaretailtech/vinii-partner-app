/// Build-time configuration, passed as `--dart-define` flags by
/// `tool/run_local.sh` (which refuses any key not listed here).
///
/// Only values that are safe inside a shipped app belong here. The Supabase
/// publishable key is public by design; a service-role key or database
/// password must never reach this class.
///
/// There is no sample-data mode: every screen shows the organization's real
/// rows from Supabase, or an honest empty state.
class AppConfig {
  const AppConfig({
    required this.appEnv,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.partnerApiBaseUrl,
    required this.storefrontBaseUrl,
    this.mediaBaseUrl = '',
  });

  /// `local`, `staging` or `production`. Shown in Settings → About.
  final String appEnv;

  final String supabaseUrl;
  final String supabasePublishableKey;

  /// One Local's server, which owns the partner order actions
  /// (`/api/partner/*`). Empty means delivery orders are unavailable and the
  /// Orders tab says so.
  final String partnerApiBaseUrl;

  /// Where the published guest storefront lives, e.g. `https://vinii.app`.
  /// The organization's slug is appended: `https://vinii.app/s/<slug>`.
  final String storefrontBaseUrl;

  /// The Master (VINII OS) public origin that serves storefront pictures
  /// uploaded in the CMS, at `<origin>/media/<path>`. Empty means bucket
  /// pictures are not shown (a phone has no "same origin") and the guest
  /// runtime draws its illustrated fallbacks; full https picture URLs still
  /// show.
  final String mediaBaseUrl;

  /// This build's own version. Compared with the organization's
  /// `min_app_version` at boot (the update gate).
  static const appVersion = '0.1.0';

  /// The `+1` in pubspec's `0.1.0+1`; sent as `x-runtime` (contract R7).
  static const buildNumber = '1';

  bool get isConfigured => missingSettings.isEmpty;

  /// The boot screen names exactly which value is missing instead of the app
  /// failing later.
  List<String> get missingSettings => [
    if (supabaseUrl.isEmpty) 'SUPABASE_URL',
    if (supabasePublishableKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
  ];

  /// Supabase project host, e.g. `ywylhzcxuoeilygzdonx.supabase.co`, shown in
  /// Settings → About so support can tell which database a phone uses.
  String get databaseHost => Uri.tryParse(supabaseUrl)?.host ?? '';

  factory AppConfig.fromDartDefines() => const AppConfig(
    appEnv: String.fromEnvironment('APP_ENV', defaultValue: 'local'),
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    partnerApiBaseUrl: String.fromEnvironment('PARTNER_API_BASE_URL'),
    storefrontBaseUrl: String.fromEnvironment(
      'STOREFRONT_BASE_URL',
      defaultValue: 'https://vinii.app',
    ),
    mediaBaseUrl: String.fromEnvironment('MEDIA_BASE_URL'),
  );
}
