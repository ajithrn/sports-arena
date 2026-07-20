import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/streams_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/stream_card.dart';
import '../../widgets/loading_grid.dart';
import '../../utils/platform_utils.dart';
import '../player/player_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _autoRefreshTimer;
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<StreamsProvider>();
      final settings = context.read<SettingsProvider>();
      provider.loadCategories();
      provider.loadStreams();
      _lastRefresh = DateTime.now();
      if (settings.defaultCategory != null) {
        provider.selectCategory(settings.defaultCategory);
      }
      _setupAutoRefresh(settings);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _setupAutoRefresh(SettingsProvider settings) {
    _autoRefreshTimer?.cancel();
    if (!settings.autoRefresh) return;

    _autoRefreshTimer = Timer.periodic(
      Duration(seconds: settings.refreshIntervalSeconds),
      (_) {
        if (!mounted) return;
        final provider = context.read<StreamsProvider>();
        if (!provider.isLoading) {
          provider.refresh();
          _lastRefresh = DateTime.now();
        }
      },
    );
  }

  /// Debounced manual refresh — prevents spamming within 5 seconds
  void _handleManualRefresh() {
    if (_lastRefresh != null &&
        DateTime.now().difference(_lastRefresh!).inSeconds < 5) {
      return; // Cooldown active
    }
    final provider = context.read<StreamsProvider>();
    if (!provider.isLoading) {
      provider.refresh();
      _lastRefresh = DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTv = PlatformUtils.isTv;
    final screenWidth = MediaQuery.of(context).size.width;

    int crossAxisCount;
    if (isTv) {
      crossAxisCount = 4;
    } else if (screenWidth > 1200) {
      crossAxisCount = 4;
    } else if (screenWidth > 800) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 2;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Exit App'),
            content: const Text('Are you sure you want to exit?'),
            actions: [
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
        if (shouldExit == true && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.sports, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text(
              'Sports Arena',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          _buildSortIconButton(),
          Consumer<StreamsProvider>(
            builder: (context, provider, _) {
              String tooltip = 'Refresh';
              if (_lastRefresh != null) {
                final ago = DateTime.now().difference(_lastRefresh!).inSeconds;
                if (ago < 60) {
                  tooltip = 'Updated ${ago}s ago';
                } else {
                  tooltip = 'Updated ${ago ~/ 60}m ago';
                }
              }
              return IconButton(
                icon: provider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: provider.isLoading ? null : _handleManualRefresh,
                tooltip: tooltip,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final settings = context.read<SettingsProvider>();
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              // Re-setup auto-refresh in case settings changed
              if (mounted) {
                _setupAutoRefresh(settings);
              }
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Consumer<StreamsProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // Connection error banner
              if (provider.error != null && !provider.isLoading)
                MaterialBanner(
                  content: const Text('Unable to connect to server'),
                  leading: const Icon(Icons.wifi_off, color: Colors.orange),
                  backgroundColor: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
                  actions: [
                    TextButton(
                      onPressed: _handleManualRefresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              // Category bar
              _buildCategoryBar(provider),
              // Stream grid
              Expanded(
                child: _buildContent(provider, crossAxisCount, isTv, screenWidth),
              ),
            ],
          );
        },
      ),
    ),
    );
  }

  Widget _buildSortIconButton() {
    return Consumer<StreamsProvider>(
      builder: (context, provider, child) {
        return PopupMenuButton<SortOption>(
          icon: const Icon(Icons.sort),
          tooltip: 'Sort',
          onSelected: (option) => provider.setSortOption(option),
          itemBuilder: (_) => [
            _sortMenuItem(SortOption.viewers, 'Most Viewers', Icons.visibility, provider),
            _sortMenuItem(SortOption.matchTime, 'Match Time', Icons.schedule, provider),
            _sortMenuItem(SortOption.name, 'Name (A-Z)', Icons.sort_by_alpha, provider),
            _sortMenuItem(SortOption.league, 'League', Icons.emoji_events, provider),
          ],
        );
      },
    );
  }

  PopupMenuItem<SortOption> _sortMenuItem(
    SortOption option,
    String label,
    IconData icon,
    StreamsProvider provider,
  ) {
    final isSelected = provider.sortOption == option;
    return PopupMenuItem(
      value: option,
      child: Row(
        children: [
          Icon(icon, size: 18, color: isSelected ? Theme.of(context).colorScheme.primary : null),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.primary),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryBar(StreamsProvider provider) {
    if (provider.categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        physics: const BouncingScrollPhysics(),
        children: [
          // "All" chip
          _buildCategoryTab(
            label: 'All',
            icon: Icons.sports,
            isSelected: provider.selectedCategory == null,
            count: provider.streams.length,
            onTap: () => provider.selectCategory(null),
          ),
          const SizedBox(width: 8),
          // Category chips
          ...provider.categories.map((category) {
            final count = provider.streamCountForCategory(category.name);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildCategoryTab(
                label: category.displayName,
                icon: category.icon,
                isSelected: provider.selectedCategory == category.name,
                count: count,
                onTap: () => provider.selectCategory(category.name),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required int count,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isTv = PlatformUtils.isTv;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label category, $count streams',
      child: Builder(
        builder: (context) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              borderRadius: BorderRadius.circular(20),
              focusColor: colorScheme.primary.withValues(alpha: 0.3),
              onFocusChange: (_) {
                // Trigger rebuild for focus state
                (context as Element).markNeedsBuild();
              },
              child: Builder(
                builder: (innerContext) {
                  final hasFocus = Focus.of(innerContext).hasFocus;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: hasFocus
                            ? Colors.white
                            : isSelected
                                ? colorScheme.primary
                                : colorScheme.outline.withValues(alpha: 0.3),
                        width: hasFocus ? 2.5 : 1,
                      ),
                      boxShadow: hasFocus && isTv
                          ? [
                              BoxShadow(
                                color: colorScheme.primary.withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 16,
                          color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                          ),
                        ),
                        if (count > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.onPrimary.withValues(alpha: 0.2)
                                  : colorScheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    StreamsProvider provider,
    int crossAxisCount,
    bool isTv,
    double screenWidth,
  ) {
    if (provider.isLoading) {
      return LoadingGrid(crossAxisCount: crossAxisCount);
    }
    if (provider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load streams',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              provider.error!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => provider.refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (provider.filteredStreams.isEmpty) {
      final hasFilter = provider.selectedCategory != null;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilter ? Icons.filter_alt_off : Icons.sports,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilter
                  ? 'No streams in this category'
                  : 'No streams available',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              hasFilter
                  ? 'Try selecting a different category or view all streams'
                  : 'Check back later for live events',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (hasFilter)
              FilledButton.tonalIcon(
                onPressed: () => provider.selectCategory(null),
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Show all streams'),
              )
            else
              OutlinedButton.icon(
                onPressed: () => provider.refresh(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
              ),
          ],
        ),
      );
    }
    // Calculate card height dynamically based on available width
    final gridWidth = screenWidth - 32 - (crossAxisCount - 1) * 12; // padding + gaps
    final cardWidth = gridWidth / crossAxisCount;
    final thumbnailHeight = cardWidth * 9 / 16; // 16:9
    final infoHeight = isTv ? 100.0 : 90.0; // text (up to 2 lines) + badge + padding
    final cardHeight = thumbnailHeight + infoHeight;

    return RefreshIndicator(
      onRefresh: () => provider.refresh(),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: cardHeight,
        ),
        itemCount: provider.filteredStreams.length,
        itemBuilder: (context, index) {
          final stream = provider.filteredStreams[index];
          return StreamCard(
            stream: stream,
            isTvLayout: isTv,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlayerScreen(stream: stream),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
