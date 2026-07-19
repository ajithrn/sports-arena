import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _defaultCategoryKey = 'default_category';
  static const String _autoRefreshKey = 'auto_refresh';
  static const String _refreshIntervalKey = 'refresh_interval';

  late SharedPreferences _prefs;
  ThemeMode _themeMode = ThemeMode.dark;
  String? _defaultCategory;
  bool _autoRefresh = false;
  int _refreshIntervalSeconds = 60;

  // Getters
  ThemeMode get themeMode => _themeMode;
  String? get defaultCategory => _defaultCategory;
  bool get autoRefresh => _autoRefresh;
  int get refreshIntervalSeconds => _refreshIntervalSeconds;

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
}
