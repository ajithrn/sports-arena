/// Central configuration for the app.
/// No hardcoded API URLs — the user provides their domain during onboarding.
class AppConfig {
  // ──────────────────────────────────────────────
  // App Info
  // ──────────────────────────────────────────────
  static const String appName = 'Sports Arena';
  static const String appVersion = '1.1.1';

  // ──────────────────────────────────────────────
  // API Path Configuration (structure stays the same, domain is user-provided)
  // ──────────────────────────────────────────────
  static const String apiVersionPath = '/api/v1';
  static const String streamsPath = '/streams';
  static const String categoriesPath = '/categories';
  static const String embedPath = '/embed';

  // ──────────────────────────────────────────────
  // Cache Configuration
  // ──────────────────────────────────────────────
  /// How long to cache the streams list (in seconds)
  static const int streamsCacheDuration = 60;

  /// How long to cache the categories list (in seconds)
  static const int categoriesCacheDuration = 300;

  // ──────────────────────────────────────────────
  // Storage Keys
  // ──────────────────────────────────────────────
  static const String domainStorageKey = 'api_domain';
  static const String onboardingCompleteKey = 'onboarding_complete';

  // ──────────────────────────────────────────────
  // Update Configuration
  // ──────────────────────────────────────────────
  static const String githubRepo = 'ajithrn/sports-arena';
  static const String githubApiUrl = 'https://api.github.com/repos/ajithrn/sports-arena';
}
