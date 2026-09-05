import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _defaultCategoryKey = 'default_category';
  static const String _autoRefreshKey = 'auto_refresh';
  static const String _refreshIntervalKey = 'refresh_interval';
  static const String _proxyEnabledKey = 'proxy_enabled';
  static const String _dohServerKey = 'doh_server';
  static const String _preferredQualityKey = 'preferred_quality';

  /// Available DoH server presets (only servers supporting JSON API)
  static const Map<String, String> dohServers = {
    'Cloudflare': 'https://cloudflare-dns.com/dns-query',
    'Cloudflare (IP)': 'https://1.1.1.1/dns-query',
    'Google': 'https://dns.google/resolve',
    'Google (IP)': 'https://8.8.8.8/resolve',
    'NextDNS': 'https://dns.nextdns.io/dns-query',
  };

  /// Preferred default playback quality, as a resolution height.
  /// 0 means "Highest available". The player picks the closest matching
  /// source, falling back to the highest available when there's no exact match.
  static const Map<String, int> qualityOptions = {
    'Highest available': 0,
    '4K (2160p)': 2160,
    '1080p': 1080,
    '720p': 720,
    '540p': 540,
  };

  late SharedPreferences _prefs;
  ThemeMode _themeMode = ThemeMode.dark;
  String? _defaultCategory;
  bool _autoRefresh = false;
  int _refreshIntervalSeconds = 60;
  bool _proxyEnabled = true;
  String _dohServer = 'https://cloudflare-dns.com/dns-query';
  int _preferredQuality = 1080; // default to 1080p

  // Getters
  ThemeMode get themeMode => _themeMode;
  String? get defaultCategory => _defaultCategory;
  bool get autoRefresh => _autoRefresh;
  int get refreshIntervalSeconds => _refreshIntervalSeconds;
  bool get proxyEnabled => _proxyEnabled;
  String get dohServer => _dohServer;

  /// Preferred playback quality as a resolution height (0 = highest available).
  int get preferredQuality => _preferredQuality;

  /// Friendly name for the current preferred quality.
  String get preferredQualityName {
    for (final entry in qualityOptions.entries) {
      if (entry.value == _preferredQuality) return entry.key;
    }
    return 'Highest available';
  }

  /// Friendly name for the current DoH server
  String get dohServerName {
    for (final entry in dohServers.entries) {
      if (entry.value == _dohServer) return entry.key;
    }
    return 'Custom';
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
  }

  void _loadSettings() {
    final themeIndex = _prefs.getInt(_themeKey) ?? 2; // default dark
    _themeMode = ThemeMode.values[themeIndex];
    _defaultCategory = _prefs.getString(_defaultCategoryKey);
    _autoRefresh = _prefs.getBool(_autoRefreshKey) ?? false;
    _refreshIntervalSeconds = _prefs.getInt(_refreshIntervalKey) ?? 60;
    _proxyEnabled = _prefs.getBool(_proxyEnabledKey) ?? true;
    final savedDoh = _prefs.getString(_dohServerKey);
    if (savedDoh != null && dohServers.containsValue(savedDoh)) {
      _dohServer = savedDoh;
    } else {
      // Default to Cloudflare IP — most reliable across all platforms
      // including Android emulators where domain-based DoH may be slow
      _dohServer = 'https://cloudflare-dns.com/dns-query';
    }
    final savedQuality = _prefs.getInt(_preferredQualityKey);
    if (savedQuality != null && qualityOptions.containsValue(savedQuality)) {
      _preferredQuality = savedQuality;
    } else {
      _preferredQuality = 1080; // default 1080p
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt(_themeKey, mode.index);
    notifyListeners();
  }

  Future<void> setDefaultCategory(String? category) async {
    _defaultCategory = category;
    if (category == null) {
      await _prefs.remove(_defaultCategoryKey);
    } else {
      await _prefs.setString(_defaultCategoryKey, category);
    }
    notifyListeners();
  }

  Future<void> setAutoRefresh(bool value) async {
    _autoRefresh = value;
    await _prefs.setBool(_autoRefreshKey, value);
    notifyListeners();
  }

  Future<void> setRefreshInterval(int seconds) async {
    _refreshIntervalSeconds = seconds;
    await _prefs.setInt(_refreshIntervalKey, seconds);
    notifyListeners();
  }

  Future<void> setProxyEnabled(bool value) async {
    _proxyEnabled = value;
    await _prefs.setBool(_proxyEnabledKey, value);
    notifyListeners();
  }

  Future<void> setDohServer(String url) async {
    _dohServer = url;
    await _prefs.setString(_dohServerKey, url);
    notifyListeners();
  }

  Future<void> setPreferredQuality(int height) async {
    _preferredQuality = height;
    await _prefs.setInt(_preferredQualityKey, height);
    notifyListeners();
  }
}
