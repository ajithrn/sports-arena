import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/stream_model.dart';
import 'domain_service.dart';

class ApiService {
  final DomainService _domainService;

  // Simple in-memory cache
  final Map<String, _CacheEntry> _cache = {};

  /// HTTP timeout for all requests
  static const _timeout = Duration(seconds: 10);

  ApiService(this._domainService);

  String get _baseUrl => _domainService.apiBaseUrl;

  /// Common headers for all requests
  Map<String, String> get _headers => {
        'User-Agent': _userAgent,
        'Accept': 'application/json',
      };

  String get _userAgent {
    if (kIsWeb) return 'SportsArena/${AppConfig.appVersion} (Web)';
    final platform = defaultTargetPlatform.name;
    try {
      return 'SportsArena/${AppConfig.appVersion} ($platform; ${Platform.operatingSystemVersion})';
    } catch (_) {
      return 'SportsArena/${AppConfig.appVersion} ($platform)';
    }
  }

  /// Fetch all live streams, optionally filtered by category
  Future<List<SportStream>> getStreams({String? category}) async {
    final cacheKey = 'streams_${category ?? 'all'}';
    final cached = _getFromCache(cacheKey, AppConfig.streamsCacheDuration);
    if (cached != null) return cached as List<SportStream>;

    String url = '$_baseUrl${AppConfig.streamsPath}';
    if (category != null && category.isNotEmpty) {
      url += '?category=$category';
    }

    final response = await http
        .get(Uri.parse(url), headers: _headers)
        .timeout(_timeout);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final streams = (data['streams'] as List)
          .map((s) => SportStream.fromJson(s))
          .toList();
      _putInCache(cacheKey, streams);
      return streams;
    }
    throw ApiException('Failed to fetch streams: ${response.statusCode}');
  }

  /// Fetch a single stream by key
  Future<SportStream?> getStream(String streamKey) async {
    final cacheKey = 'stream_$streamKey';
    final cached = _getFromCache(cacheKey, AppConfig.streamsCacheDuration);
    if (cached != null) return cached as SportStream;

    final url = '$_baseUrl${AppConfig.streamsPath}/$streamKey';
    final response = await http
        .get(Uri.parse(url), headers: _headers)
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final stream = SportStream.fromJson(json.decode(response.body));
      _putInCache(cacheKey, stream);
      return stream;
    } else if (response.statusCode == 404) {
      return null;
    }
    throw ApiException('Failed to fetch stream: ${response.statusCode}');
  }

  /// Fetch all available categories
  Future<List<String>> getCategories() async {
    const cacheKey = 'categories';
    final cached = _getFromCache(cacheKey, AppConfig.categoriesCacheDuration);
    if (cached != null) return cached as List<String>;

    final url = '$_baseUrl${AppConfig.categoriesPath}';
    final response = await http
        .get(Uri.parse(url), headers: _headers)
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final categories = List<String>.from(data['categories']);
      _putInCache(cacheKey, categories);
      return categories;
    }
    throw ApiException('Failed to fetch categories: ${response.statusCode}');
  }

  /// Test connection to the configured domain
  Future<bool> testConnection() async {
    try {
      final url = '$_baseUrl${AppConfig.categoriesPath}';
      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Clear all cached data
  void clearCache() {
    _cache.clear();
  }

  // ── Cache helpers ──

  dynamic _getFromCache(String key, int maxAgeSeconds) {
    final entry = _cache[key];
    if (entry == null) return null;
    final age = DateTime.now().difference(entry.timestamp).inSeconds;
    if (age > maxAgeSeconds) {
      _cache.remove(key);
      return null;
    }
    return entry.data;
  }

  void _putInCache(String key, dynamic data) {
    _cache[key] = _CacheEntry(data: data, timestamp: DateTime.now());
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  _CacheEntry({required this.data, required this.timestamp});
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
