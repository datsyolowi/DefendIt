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
}