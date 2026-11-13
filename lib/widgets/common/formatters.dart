/// Shared YouTube-style text and number formatters.
abstract final class AppFormatters {
  /// Formats an integer count into compact YouTube style (e.g. "1.2K", "45M", "1.5B").
  static String formatCount(int count) {
    if (count < 0) return '0';
    if (count < 1000) return count.toString();
    if (count < 1000000) {
      final k = count / 1000.0;
      final formatted = k >= 10 || count % 1000 < 100 ? k.toStringAsFixed(0) : k.toStringAsFixed(1);
      return '${formatted}K';
    }
    if (count < 1000000000) {
      final m = count / 1000000.0;
      final formatted = m >= 10 || count % 1000000 < 100000 ? m.toStringAsFixed(0) : m.toStringAsFixed(1);
      return '${formatted}M';
    }
    final b = count / 1000000000.0;
    return '${b.toStringAsFixed(1)}B';
  }

  /// Formats a duration into standard timestamp format:
  /// - Under 1 hour: "m:ss" (e.g. "3:45")
  /// - 1 hour or more: "h:mm:ss" (e.g. "1:04:22")
  static String formatDuration(Duration duration) {
    if (duration <= Duration.zero) return '0:00';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    final secondsStr = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      final minutesStr = minutes.toString().padLeft(2, '0');
      return '$hours:$minutesStr:$secondsStr';
    }
    return '$minutes:$secondsStr';
  }

  /// Convenience wrapper for seconds to duration string.
  static String formatDurationSeconds(int seconds) =>
      formatDuration(Duration(seconds: seconds < 0 ? 0 : seconds));

  /// Formats a past DateTime into relative YouTube-style time ago string.
  static String formatTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.isNegative || difference.inSeconds < 45) {
      return 'just now';
    }
    if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? 'minute' : 'minutes'} ago';
    }
    if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    }
    if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    }
    if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    }
    if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    }
    final years = (difference.inDays / 365).floor();
    return '$years ${years == 1 ? 'year' : 'years'} ago';
  }
}

