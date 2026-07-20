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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<StreamsProvider>();
      final settings = context.read<SettingsProvider>();
      provider.loadCategories();
      provider.loadStreams();
      if (settings.defaultCategory != null) {
        provider.selectCategory(settings.defaultCategory);
      }
    });
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

    return Scaffold(
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
              return IconButton(
                icon: provider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: provider.isLoading ? null : () => provider.refresh(),
                tooltip: 'Refresh',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Consumer<StreamsProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // Category bar
              _buildCategoryBar(provider),
              // Stream grid
              Expanded(
                child: _buildContent(provider, crossAxisCount, isTv),
              ),
            ],
          );
        },
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

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label category, $count streams',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
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
      ),
    ),
    );
  }

  Widget _buildContent(
    StreamsProvider provider,
    int crossAxisCount,
    bool isTv,
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
    return RefreshIndicator(
      onRefresh: () => provider.refresh(),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isTv ? 1.0 : 0.85,
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
