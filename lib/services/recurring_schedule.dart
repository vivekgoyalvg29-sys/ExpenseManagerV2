/// Recurrence kinds for [RecurringExpense] master rows.
abstract class RecurringScheduleKind {
  static const String monthlyDay = 'monthly_day';
  static const String monthlyWeekday = 'monthly_weekday';
  static const String weekly = 'weekly';
}

DateTime recurringDateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int _lastDayOfMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Clamps [desiredDay] to the last day of the month when needed (e.g. 31 → Feb 28).
DateTime dayInMonthClamped(int year, int month, int desiredDay) {
  final last = _lastDayOfMonth(year, month);
  final d = desiredDay > last ? last : desiredDay;
  return DateTime(year, month, d);
}

/// [ordinal]: 1 = first, 2 = second, … 4 = fourth, -1 = last in month.
DateTime? nthWeekdayInMonth(int year, int month, int weekday, int ordinal) {
  assert(weekday >= DateTime.monday && weekday <= DateTime.sunday);
  if (ordinal == -1) {
    final lastDay = _lastDayOfMonth(year, month);
    for (var day = lastDay; day >= 1; day--) {
      final dt = DateTime(year, month, day);
      if (dt.weekday == weekday) return recurringDateOnly(dt);
    }
    return null;
  }
  final first = DateTime(year, month, 1);
  var diff = (weekday - first.weekday + 7) % 7;
  var candidate = DateTime(year, month, 1 + diff);
  candidate = candidate.add(Duration(days: (ordinal - 1) * 7));
  if (candidate.month != month) return null;
  return recurringDateOnly(candidate);
}

DateTime nextWeekdayOnOrAfter(DateTime from, int weekday) {
  final start = recurringDateOnly(from);
  final diff = (weekday - start.weekday + 7) % 7;
  return start.add(Duration(days: diff));
}

/// JSON: `{ "day": int }` — day of month 1–31 (clamped).
Map<String, dynamic> scheduleMonthlyDayJson(int day) => {'day': day};

/// JSON: `{ "ordinal": int, "weekday": int }` — weekday Mon=1 … Sun=7.
Map<String, dynamic> scheduleMonthlyWeekdayJson({
  required int ordinal,
  required int weekday,
}) =>
    {'ordinal': ordinal, 'weekday': weekday};

/// JSON: `{ "weekday": int }`.
Map<String, dynamic> scheduleWeeklyJson(int weekday) => {'weekday': weekday};

String describeSchedule(String kind, Map<String, dynamic> json) {
  switch (kind) {
    case RecurringScheduleKind.monthlyDay:
      final d = (json['day'] as num?)?.toInt() ?? 1;
      return 'Day $d of each month';
    case RecurringScheduleKind.monthlyWeekday:
      final ord = (json['ordinal'] as num?)?.toInt() ?? 1;
      final wd = (json['weekday'] as num?)?.toInt() ?? DateTime.monday;
      final name = _weekdayName(wd);
      if (ord == -1) return 'Last $name of each month';
      final ordName = _ordinalName(ord);
      return '$ordName $name of each month';
    case RecurringScheduleKind.weekly:
      final wd = (json['weekday'] as num?)?.toInt() ?? DateTime.monday;
      return 'Every ${_weekdayName(wd)}';
    default:
      return kind;
  }
}

String _ordinalName(int n) {
  switch (n) {
    case 1:
      return 'First';
    case 2:
      return 'Second';
    case 3:
      return 'Third';
    case 4:
      return 'Fourth';
    default:
      return '$n-th';
  }
}

String _weekdayName(int weekday) {
  const names = [
    '',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  if (weekday < 1 || weekday > 7) return 'weekday';
  return names[weekday];
}

/// Yields each scheduled occurrence from [createdAt] through [until] inclusive,
/// only on or after [createdAt] (date) and on or before [until] (date).
Iterable<DateTime> occurrencesForMaster({
  required String kind,
  required Map<String, dynamic> scheduleJson,
  required DateTime createdAt,
  required DateTime until,
}) sync* {
  final created = recurringDateOnly(createdAt);
  final end = recurringDateOnly(until);

  switch (kind) {
    case RecurringScheduleKind.monthlyDay:
      final desiredDay = (scheduleJson['day'] as num?)?.toInt() ?? 1;
      var y = created.year;
      var m = created.month;
      final endYm = end.year * 12 + end.month;
      while (y * 12 + m <= endYm) {
        final d = dayInMonthClamped(y, m, desiredDay);
        if (!d.isBefore(created) && !d.isAfter(end)) yield d;
        if (m == 12) {
          m = 1;
          y++;
        } else {
          m++;
        }
      }
      break;

    case RecurringScheduleKind.monthlyWeekday:
      final ordinal = (scheduleJson['ordinal'] as num?)?.toInt() ?? 1;
      final weekday = (scheduleJson['weekday'] as num?)?.toInt() ?? DateTime.monday;
      var y = created.year;
      var m = created.month;
      final endYm = end.year * 12 + end.month;
      while (y * 12 + m <= endYm) {
        final d = nthWeekdayInMonth(y, m, weekday, ordinal);
        if (d != null && !d.isBefore(created) && !d.isAfter(end)) yield d;
        if (m == 12) {
          m = 1;
          y++;
        } else {
          m++;
        }
      }
      break;

    case RecurringScheduleKind.weekly:
      final weekday = (scheduleJson['weekday'] as num?)?.toInt() ?? DateTime.monday;
      var d = nextWeekdayOnOrAfter(created, weekday);
      while (!d.isAfter(end)) {
        if (!d.isBefore(created)) yield d;
        d = d.add(const Duration(days: 7));
      }
      break;
  }
}
