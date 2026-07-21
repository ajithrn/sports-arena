import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/stream_model.dart';
import '../models/category_model.dart';
import '../utils/time_utils.dart';

class StreamCard extends StatefulWidget {
  final SportStream stream;
  final VoidCallback onTap;
  final bool isTvLayout;

  const StreamCard({
    super.key,
    required this.stream,
    required this.onTap,
    this.isTvLayout = false,
  });

  @override
  State<StreamCard> createState() => _StreamCardState();
}

class _StreamCardState extends State<StreamCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  SportStream get stream => widget.stream;
  bool get isTvLayout => widget.isTvLayout;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${stream.name}, ${stream.league}, ${stream.isLive ? "live now" : "upcoming"}, ${TimeUtils.formatViewers(stream.viewers)} viewers',
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: _isHovered || _isFocused
              ? (Matrix4.identity()..scaleByDouble(1.03, 1.03, 1.0, 1.0))
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: _isHovered || _isFocused ? 8 : 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: _isFocused
                  ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
                  : BorderSide.none,
            ),
            child: InkWell(
              onTap: widget.onTap,
              onFocusChange: (focused) => setState(() => _isFocused = focused),
              hoverColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              focusColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail / Team logos section
                  _buildThumbnail(context),
                  // Info section
                  Padding(
                    padding: EdgeInsets.all(isTvLayout ? 16 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stream.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isTvLayout ? 18 : 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildLeagueBadge(context),
                            const Spacer(),
                            if (stream.viewers > 0) _buildViewerCount(context),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background - thumbnail or team logos
          if (stream.team1 != null && stream.team2 != null)
            _buildTeamVsLayout(context)
          else
            _buildThumbnailImage(),
          // Live badge
          Positioned(
            top: 8,
            left: 8,
            child: _buildLiveBadge(context),
          ),
          // Category badge
          Positioned(
            top: 8,
            right: 8,
            child: _buildCategoryBadge(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamVsLayout(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(child: _buildTeamLogo(stream.team1!)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'VS',
              style: TextStyle(
                fontSize: isTvLayout ? 24 : 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          Flexible(child: _buildTeamLogo(stream.team2!)),
        ],
      ),
    );
  }

  Widget _buildTeamLogo(TeamInfo team) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CachedNetworkImage(
          imageUrl: team.logo,
          width: isTvLayout ? 56 : 40,
          height: isTvLayout ? 56 : 40,
          placeholder: (_, _) => const Icon(Icons.sports, size: 40),
          errorWidget: (_, _, _) => const Icon(Icons.sports, size: 40),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: isTvLayout ? 100 : 80,
          child: Text(
            team.name,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: isTvLayout ? 12 : 10),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnailImage() {
    return CachedNetworkImage(
      imageUrl: stream.thumbnailUrl,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(
        color: Colors.grey[800],
        child: const Center(child: Icon(Icons.live_tv, size: 48, color: Colors.white54)),
      ),
      errorWidget: (_, _, _) => Container(
        color: Colors.grey[800],
        child: const Center(child: Icon(Icons.live_tv, size: 48, color: Colors.white54)),
      ),
    );
  }

  Widget _buildLiveBadge(BuildContext context) {
    final timeText = TimeUtils.formatMatchTime(stream.matchTimestamp);
    final isLive = timeText == 'LIVE';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLive ? Colors.red : Colors.black87,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            timeText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        stream.league,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLeagueBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        SportCategory.fromName(stream.category).displayName,
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildViewerCount(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.visibility, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          TimeUtils.formatViewers(stream.viewers),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
