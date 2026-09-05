class TeamInfo {
  final String name;
  final String logo;

  TeamInfo({required this.name, required this.logo});

  factory TeamInfo.fromJson(Map<String, dynamic> json) {
    return TeamInfo(
      name: json['name'] ?? '',
      logo: json['logo'] ?? '',
    );
  }
}

/// A single playback source with a human-readable quality label.
///
/// Source URLs look like `.../embed/embed/{streamKey}{quality}` where the
/// quality suffix is e.g. `540p`, `1080p`, `2160p`, sometimes with a trailing
/// mirror digit (`1080p3`). This model parses that suffix into a friendly
/// label ("1080p", "4K", "Mirror 2", etc.).
class StreamSource {
  final String url;

  /// Friendly quality label shown in the picker, e.g. "1080p", "4K".
  final String label;

  /// Numeric resolution height for sorting (e.g. 1080). 0 if unknown.
  final int height;

  const StreamSource({
    required this.url,
    required this.label,
    required this.height,
  });

  /// Parse a source URL into a labeled source, using [streamKey] to strip the
  /// known prefix and [index]/[total] as fallbacks when no quality is found.
  factory StreamSource.fromUrl(
    String url,
    String streamKey, {
    required int index,
  }) {
    // The last path segment is `{streamKey}{qualitySuffix}` (e.g. skyf11080p).
    final lastSegment = url.split('/').where((s) => s.isNotEmpty).last;

    // Strip the streamKey prefix if present to isolate the quality suffix.
    String suffix = lastSegment;
    if (streamKey.isNotEmpty && lastSegment.startsWith(streamKey)) {
      suffix = lastSegment.substring(streamKey.length);
    }

    // Match a resolution like "1080p", "2160p", "540p" (optionally followed by
    // a mirror number like the "3" in "1080p3").
    final match = RegExp(r'(\d{3,4})p(\d*)').firstMatch(suffix);
    if (match != null) {
      final res = int.tryParse(match.group(1)!) ?? 0;
      final mirror = match.group(2) ?? '';
      final base = _friendlyResolution(res);
      final label = mirror.isNotEmpty ? '$base ($mirror)' : base;
      return StreamSource(url: url, label: label, height: res);
    }

    // No parseable quality — fall back to a generic label.
    return StreamSource(url: url, label: 'Source ${index + 1}', height: 0);
  }

  /// Convert a numeric resolution height to a friendly label.
  static String _friendlyResolution(int height) {
    switch (height) {
      case 2160:
        return '4K';
      case 1440:
        return '1440p';
      case 1080:
        return '1080p';
      case 720:
        return '720p';
      case 540:
        return '540p';
      case 480:
        return '480p';
      case 360:
        return '360p';
      default:
        return height > 0 ? '${height}p' : 'Auto';
    }
  }
}

class SportStream {
  final String id;
  final String name;
  final String category;
  final String league;
  final String streamKey;
  final int matchTimestamp;
  final int viewers;
  final bool isExternal;
  final String thumbnailUrl;

  /// All available playback sources (different qualities/mirrors).
  /// Populated from the single-stream endpoint's `sources` array.
  /// The streams-list endpoint does NOT include these, so a list item
  /// starts with an empty list until its detail is fetched.
  final List<String> sources;

  final TeamInfo? team1;
  final TeamInfo? team2;

  SportStream({
    required this.id,
    required this.name,
    required this.category,
    required this.league,
    required this.streamKey,
    required this.matchTimestamp,
    required this.viewers,
    required this.isExternal,
    required this.thumbnailUrl,
    this.sources = const [],
    this.team1,
    this.team2,
  });

  /// Primary embed URL used by the player (first available source).
  /// Empty string if no sources are available yet.
  String get embedUrl => sources.isNotEmpty ? sources.first : '';

  /// Whether this stream has any playable source.
  bool get hasSource => sources.isNotEmpty;

  /// Sources mapped to labeled quality options for the player's quality picker.
  /// Sorted highest resolution first; unknown-quality sources go last.
  List<StreamSource> get labeledSources {
    final list = <StreamSource>[];
    for (int i = 0; i < sources.length; i++) {
      list.add(StreamSource.fromUrl(sources[i], streamKey, index: i));
    }
    // Stable sort by resolution descending, keeping original order for ties
    // (so mirrors of the same quality stay grouped in their listed order).
    final indexed = list.asMap().entries.toList();
    indexed.sort((a, b) {
      final byHeight = b.value.height.compareTo(a.value.height);
      if (byHeight != 0) return byHeight;
      return a.key.compareTo(b.key);
    });
    return indexed.map((e) => e.value).toList();
  }

  /// The source to play by default. Prefers 1080p when available (best balance
  /// of quality and reliability), otherwise falls back to the highest quality.
  StreamSource? get defaultSource => sourceForPreferredHeight(1080);

  /// Pick the source matching the [preferredHeight] resolution.
  ///
  /// - [preferredHeight] == 0 → highest available.
  /// - Exact match wins.
  /// - Otherwise the closest quality at or below the preference (so a 720p
  ///   preference on a stream offering 1080p/540p picks 540p, not 1080p).
  /// - If nothing is at or below, falls back to the highest available.
  StreamSource? sourceForPreferredHeight(int preferredHeight) {
    final labeled = labeledSources; // sorted highest → lowest
    if (labeled.isEmpty) return null;
    if (preferredHeight <= 0) return labeled.first; // highest available

    // Exact match
    for (final s in labeled) {
      if (s.height == preferredHeight) return s;
    }
    // Closest at or below the preference (labeled is sorted descending, so the
    // first one <= preference is the highest that still fits under it).
    for (final s in labeled) {
      if (s.height > 0 && s.height <= preferredHeight) return s;
    }
    // Nothing at or below — give the highest available.
    return labeled.first;
  }

  factory SportStream.fromJson(Map<String, dynamic> json) {
    // The API returns playback URLs under `sources` (an array of quality
    // variants). Older/other shapes may use a single `embed_url` string —
    // support both so the player always gets a URL when one exists.
    final rawSources = json['sources'];
    final List<String> sources = rawSources is List
        ? rawSources.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];
    final singleEmbed = json['embed_url'];
    if (sources.isEmpty && singleEmbed is String && singleEmbed.isNotEmpty) {
      sources.add(singleEmbed);
    }

    return SportStream(
      id: json['id'] ?? json['stream_key'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      league: json['league'] ?? '',
      streamKey: json['stream_key'] ?? '',
      matchTimestamp: json['match_timestamp'] ?? 0,
      viewers: json['viewers'] ?? 0,
      isExternal: json['is_external'] ?? false,
      thumbnailUrl: json['thumbnail_url'] ?? '',
      sources: sources,
      team1: json['team1'] != null ? TeamInfo.fromJson(json['team1']) : null,
      team2: json['team2'] != null ? TeamInfo.fromJson(json['team2']) : null,
    );
  }

  /// Whether this match is currently live (timestamp is in the past)
  bool get isLive {
    final matchTime = DateTime.fromMillisecondsSinceEpoch(matchTimestamp * 1000);
    return DateTime.now().isAfter(matchTime);
  }

  /// Match start time as DateTime
  DateTime get matchTime {
    return DateTime.fromMillisecondsSinceEpoch(matchTimestamp * 1000);
  }
}
