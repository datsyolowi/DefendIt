import 'package:intl/intl.dart';

class DateFormatters {
  DateFormatters._();

  static String time(DateTime d) => DateFormat('h:mm a').format(d);

  static String shortDay(DateTime d) => DateFormat('EEE, MMM d').format(d);

  static String range(DateTime start, int mins) =>
      '${time(start)} – ${time(start.add(Duration(minutes: mins)))}';

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String dayHeader(DateTime d) {
    final now = DateTime.now();
    if (sameDay(d, now)) return 'Today · ${shortDay(d)}';
    if (sameDay(d, now.add(const Duration(days: 1)))) {
      return 'Tomorrow · ${shortDay(d)}';
    }
    return DateFormat('EEEE, MMM d').format(d);
  }

  static String greeting([DateTime? now]) {
    final h = (now ?? DateTime.now()).hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  /// Short countdown label for the hero card.
  static String until(DateTime start, int durationMins) {
    final now = DateTime.now();
    final end = start.add(Duration(minutes: durationMins));
    if (!now.isBefore(start) && now.isBefore(end)) return 'Happening now';

    final diff = start.difference(now);
    if (diff.inMinutes < 60) {
      final mins = diff.inMinutes < 1 ? 1 : diff.inMinutes;
      return 'In $mins min';
    }
    if (sameDay(start, now)) return 'In ${diff.inHours} h';

    final days = DateTime(start.year, start.month, start.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    return days == 1 ? 'Tomorrow' : 'In $days days';
  }
}