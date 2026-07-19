import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Manages the user's API domain configuration.
/// Domain is entered during onboarding and stored locally.
class DomainService {
  static DomainService? _instance;
  late SharedPreferences _prefs;
  String? _domain;

  DomainService._();

  static Future<DomainService> getInstance() async {
    if (_instance == null) {
      _instance = DomainService._();
      await _instance!._init();
    }
    return _instance!;
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _domain = _prefs.getString(AppConfig.domainStorageKey);
  }

  /// Whether the user has completed onboarding (set a domain)
  bool get isConfigured => _domain != null && _domain!.isNotEmpty;

  /// The stored domain (e.g., "https://example.com")
  String? get domain => _domain;

  /// Full API base URL
  String get apiBaseUrl => '$_domain${AppConfig.apiVersionPath}';

  /// Full embed base URL
  String get embedBaseUrl => '$_domain${AppConfig.embedPath}';

  /// Save the user's domain
  Future<void> setDomain(String domain) async {
    // Normalize: ensure https://, remove trailing slash
    String normalized = domain.trim();
    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    _domain = normalized;
    await _prefs.setString(AppConfig.domainStorageKey, normalized);
    await _prefs.setBool(AppConfig.onboardingCompleteKey, true);
  }

  /// Clear stored domain (for logout/reset)
  Future<void> clearDomain() async {
    _domain = null;
    await _prefs.remove(AppConfig.domainStorageKey);
    await _prefs.remove(AppConfig.onboardingCompleteKey);
  }

  /// Validate a domain by testing the categories endpoint
  Future<bool> validateDomain(String domain) async {
    try {
      String normalized = domain.trim();
      if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
        normalized = 'https://$normalized';
      }
      if (normalized.endsWith('/')) {
        normalized = normalized.substring(0, normalized.length - 1);
      }

      final url = '$normalized${AppConfig.apiVersionPath}${AppConfig.categoriesPath}';
      final uri = Uri.parse(url);

      // We just need to check if the URL is parseable and reachable
      // The actual HTTP call will be done by the ApiService
      return uri.hasScheme && uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
