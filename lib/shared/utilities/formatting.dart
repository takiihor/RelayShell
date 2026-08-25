import '../../l10n/app_localizations.dart';

/// Human-readable byte sizes for file listings and transfers.
String formatBytes(int? bytes, {int decimals = 1}) {
  if (bytes == null) return '—';
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB', 'PB'];
  var size = bytes / 1024;
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return '${size.toStringAsFixed(decimals)} ${units[unit]}';
}

/// Relative time for "last used" labels.
///
/// Coarse on purpose: the exact minute a session was touched is noise, while
/// "8 min ago" versus "yesterday" is what decides whether the user taps it.
String formatRelativeTime(AppLocalizations l10n, DateTime? time) {
  if (time == null) return '';
  final difference = DateTime.now().difference(time);

  if (difference.inSeconds < 60) return l10n.timeJustNow;
  if (difference.inMinutes < 60) {
    return l10n.timeMinutesAgo(difference.inMinutes);
  }
  if (difference.inHours < 24) return l10n.timeHoursAgo(difference.inHours);
  if (difference.inDays == 1) return l10n.timeYesterday;
  if (difference.inDays < 30) return l10n.timeDaysAgo(difference.inDays);

  final months = (difference.inDays / 30).floor();
  if (months < 12) return l10n.timeDaysAgo(difference.inDays);
  return '${time.year}-${_two(time.month)}-${_two(time.day)}';
}

/// Absolute date and time, for file listings where precision matters.
String formatDateTime(DateTime? time) {
  if (time == null) return '—';
  final now = DateTime.now();
  final sameYear = time.year == now.year;
  final date = sameYear
      ? '${_two(time.month)}-${_two(time.day)}'
      : '${time.year}-${_two(time.month)}-${_two(time.day)}';
  return '$date ${_two(time.hour)}:${_two(time.minute)}';
}

/// POSIX permission bits as `rwxr-xr-x`.
String formatPermissions(int? mode) {
  if (mode == null) return '';
  const flags = ['x', 'w', 'r'];
  final buffer = StringBuffer();
  for (var group = 2; group >= 0; group--) {
    for (var bit = 2; bit >= 0; bit--) {
      final isSet = (mode >> (group * 3 + bit)) & 1 == 1;
      buffer.write(isSet ? flags[bit] : '-');
    }
  }
  return buffer.toString();
}

/// Shortens a long path for a one-line label, keeping both ends readable.
String shortenPath(String path, {int maxLength = 40}) {
  if (path.length <= maxLength) return path;
  final segments = path.split('/');
  if (segments.length <= 2) {
    return '…${path.substring(path.length - maxLength + 1)}';
  }
  final tail = segments.sublist(segments.length - 2).join('/');
  return '…/$tail';
}

String _two(int value) => value.toString().padLeft(2, '0');
