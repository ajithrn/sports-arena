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
  final String embedUrl;
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
    required this.embedUrl,
    this.team1,
    this.team2,
  });

  factory SportStream.fromJson(Map<String, dynamic> json) {
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
      embedUrl: json['embed_url'] ?? '',
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
