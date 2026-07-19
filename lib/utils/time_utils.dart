import 'package:intl/intl.dart';

class TimeUtils {
  /// Format a unix timestamp to a readable date/time string
  static String formatMatchTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final diff = dt.difference(now);

    if (diff.isNegative) {
      // Match has started
      return 'LIVE';
    } else if (diff.inMinutes < 60) {
      return 'Starts in ${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return 'Starts in ${diff.inHours}h ${diff.inMinutes % 60}m';
    } else {
      return DateFormat('MMM d, h:mm a').format(dt.toLocal());
    }
  }

  /// Format viewer count (e.g., 1.2K)
  static String formatViewers(int viewers) {
    if (viewers >= 1000000) {
      return '${(viewers / 1000000).toStringAsFixed(1)}M';
    } else if (viewers >= 1000) {
      return '${(viewers / 1000).toStringAsFixed(1)}K';
    }
    return viewers.toString();
  }
}
