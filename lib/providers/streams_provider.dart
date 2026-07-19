import 'package:flutter/material.dart';
import '../models/stream_model.dart';
import '../models/category_model.dart';
import '../services/api_service.dart';
import '../services/domain_service.dart';

enum SortOption {
  viewers,     // Most viewers first
  matchTime,   // Soonest/live first
  name,        // Alphabetical
  league,      // Group by league
}

class StreamsProvider extends ChangeNotifier {
  late ApiService _apiService;

  List<SportStream> _streams = [];
  List<SportCategory> _categories = [];
  String? _selectedCategory;
  SortOption _sortOption = SortOption.viewers;
  bool _isLoading = false;
  String? _error;

  StreamsProvider(DomainService domainService) {
    _apiService = ApiService(domainService);
  }

  // Getters
  List<SportStream> get streams => _streams;
  List<SportCategory> get categories => _categories;
  String? get selectedCategory => _selectedCategory;
  SortOption get sortOption => _sortOption;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Streams filtered by selected category and sorted
  List<SportStream> get filteredStreams {
    List<SportStream> result;
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      result = List.from(_streams);
    } else {
      result = _streams.where((s) => s.category == _selectedCategory).toList();
    }
    return _applySorting(result);
  }

  List<SportStream> _applySorting(List<SportStream> streams) {
    switch (_sortOption) {
      case SortOption.viewers:
        streams.sort((a, b) => b.viewers.compareTo(a.viewers));
        break;
      case SortOption.matchTime:
        streams.sort((a, b) => a.matchTimestamp.compareTo(b.matchTimestamp));
        break;
      case SortOption.name:
        streams.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SortOption.league:
        streams.sort((a, b) {
          final leagueCompare = a.league.compareTo(b.league);
          if (leagueCompare != 0) return leagueCompare;
          return b.viewers.compareTo(a.viewers);
        });
        break;
    }
    return streams;
  }

  /// Get stream count per category
  int streamCountForCategory(String category) {
    return _streams.where((s) => s.category == category).length;
  }

  /// Set sort option
  void setSortOption(SortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  /// Load categories from API
  Future<void> loadCategories() async {
    try {
      final categoryNames = await _apiService.getCategories();
      _categories = categoryNames.map((n) => SportCategory.fromName(n)).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Load streams from API
  Future<void> loadStreams() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _streams = await _apiService.getStreams();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Refresh all data
  Future<void> refresh() async {
    _apiService.clearCache();
    await Future.wait([loadCategories(), loadStreams()]);
  }

  /// Select a category filter (null = all)
  void selectCategory(String? category) {
    if (_selectedCategory == category) {
      _selectedCategory = null;
    } else {
      _selectedCategory = category;
    }
    notifyListeners();
  }
}
