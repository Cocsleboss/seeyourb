// Date rules of SeeU (description §5.1, §5.4, §7 "Dates et heures").
// "Day" values are DateTime at local midnight; timestamps are local DateTimes.
import 'package:intl/intl.dart';

import '../core/i18n.dart';
import 'models.dart';
import 'text.dart';

/// Overridable clock (tests).
DateTime Function() clock = DateTime.now;

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime today() => dayOf(clock());

DateTime parseDay(String iso) {
  final p = iso.substring(0, 10).split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

String dayIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Calendar days between a and b (b - a), DST-safe.
int calendarDaysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

int daysFromToday(DateTime day) => calendarDaysBetween(today(), day);

/// Adds months the "real calendar" way: Jan 31 + 1 month = Feb 28 (or 29).
DateTime addMonths(DateTime d, int months) {
  final total = d.year * 12 + (d.month - 1) + months;
  final y = total ~/ 12;
  final m = total % 12 + 1;
  final lastDay = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d.day > lastDay ? lastDay : d.day);
}

DateTime addFrequency(DateTime day, int value, FrequencyUnit unit) => switch (unit) {
      FrequencyUnit.days => DateTime(day.year, day.month, day.day + value),
      FrequencyUnit.weeks => DateTime(day.year, day.month, day.day + 7 * value),
      FrequencyUnit.months => addMonths(day, value),
      FrequencyUnit.years => addMonths(day, 12 * value),
    };

/* ------------------------------------------------------------------ */
/*  Due dates                                                          */
/* ------------------------------------------------------------------ */

enum DueKind { overdue, today, soon, ok }

class DueInfo {
  const DueInfo({required this.kind, required this.days, required this.label, required this.short, required this.dueDate});
  final DueKind kind;

  /// Remaining days (negative = overdue).
  final int days;

  /// "En retard de 3 jours", "À revoir aujourd'hui", "À revoir dans 2 semaines"
  final String label;

  /// "-3 j", "Auj.", "5 j", "2 mois"
  final String short;
  final DateTime dueDate;
}

/// A snooze pushes the computed due date later (never earlier).
DateTime effectiveDueDate(HasDue c) {
  final s = c.snoozeUntil;
  if (s != null && s.isAfter(c.nextDueDate)) return s;
  return c.nextDueDate;
}

DueInfo dueInfo(HasDue c) {
  final due = effectiveDueDate(c);
  final days = daysFromToday(due);
  if (days < 0) {
    return DueInfo(kind: DueKind.overdue, days: days, dueDate: due, label: tr.dueOverdue(humanizeDays(-days)), short: '-${shortDays(-days)}');
  }
  if (days == 0) {
    return DueInfo(kind: DueKind.today, days: 0, dueDate: due, label: tr.dueToday, short: tr.dueTodayShort);
  }
  return DueInfo(
    kind: days <= 7 ? DueKind.soon : DueKind.ok,
    days: days,
    dueDate: due,
    label: tr.dueIn(humanizeDays(days)),
    short: shortDays(days),
  );
}

int _jsRound(double x) => (x + 0.5).floor();

/// 3 → "3 jours", 15 → "2 semaines", 95 → "3 mois", 400 → "1 an", 550 → "1 an et demi"
String humanizeDays(int n) {
  n = n.abs();
  if (n < 14) return tr.nDays(n);
  if (n < 60) return tr.nWeeks(_jsRound(n / 7));
  if (n < 350) {
    final m = _jsRound(n / 30.44);
    return tr.nMonths(m < 2 ? 2 : m);
  }
  final years = (n / 365.25).floor();
  final rest = n - years * 365.25;
  if (years >= 1 && rest >= 140 && rest < 230) return tr.nYearsHalf(years);
  var y = _jsRound(n / 365.25);
  if (y < 1) y = 1;
  return tr.nYears(y);
}

String shortDays(int n) {
  n = n.abs();
  if (n < 14) return tr.shortDays(n);
  if (n < 60) return tr.shortWeeks(_jsRound(n / 7));
  if (n < 350) {
    final m = _jsRound(n / 30.44);
    return tr.shortMonths(m < 2 ? 2 : m);
  }
  var y = _jsRound(n / 365.25);
  if (y < 1) y = 1;
  return tr.shortYears(y);
}

/// (2, months) → "tous les 2 mois" ; (1, weeks) → "toutes les semaines"
String frequencyLabel(int value, FrequencyUnit unit) => switch (unit) {
      FrequencyUnit.days => tr.everyDays(value),
      FrequencyUnit.weeks => tr.everyWeeks(value),
      FrequencyUnit.months => tr.everyMonths(value),
      FrequencyUnit.years => tr.everyYears(value),
    };

String unitLabel(FrequencyUnit unit, int value) => switch (unit) {
      FrequencyUnit.days => tr.unitDays(value),
      FrequencyUnit.weeks => tr.unitWeeks(value),
      FrequencyUnit.months => tr.unitMonths(value),
      FrequencyUnit.years => tr.unitYears(value),
    };

/* ------------------------------------------------------------------ */
/*  Formatting                                                         */
/* ------------------------------------------------------------------ */

/// 12 nov. 2026
String formatDate(DateTime d) => DateFormat.yMMMd().format(d);

/// "9 nov." this year, "9 nov. 2025" otherwise (short lists).
String formatDateShort(DateTime d) => d.year == clock().year ? DateFormat.MMMd().format(d) : DateFormat.yMMMd().format(d);

/// sam. 14 nov. 2026
String formatDateMedium(DateTime d) => DateFormat.yMMMEd().format(d);

/// mercredi 12 novembre 2026
String formatDateLong(DateTime d) => DateFormat.yMMMMEEEEd().format(d);

/// Mercredi 12 novembre
String formatDayMonth(DateTime d) => capitalize(DateFormat.MMMMEEEEd().format(d));

/// 18:30
String formatTime(DateTime d) => DateFormat.jm().format(d);

/// Vendredi 4 décembre à 01:15
String formatDayTime(DateTime d) => tr.dayAtTime(formatDayMonth(d), formatTime(d));

/// NOV
String monthShort(DateTime d) => DateFormat.MMM().format(d).replaceAll('.', '').toUpperCase();

/// Novembre 2026
String monthLabel(DateTime d) => capitalize(DateFormat.yMMMM().format(d));

/// "Aujourd'hui" / "Demain" / "Hier" / "Mercredi 18 novembre"
String relativeDayLabel(DateTime d) {
  final diff = calendarDaysBetween(today(), d);
  if (diff == 0) return tr.today;
  if (diff == 1) return tr.tomorrow;
  if (diff == -1) return tr.yesterday;
  return formatDayMonth(d);
}

/// Next quarter hour (strictly after now), used to prefill forms.
DateTime nextQuarterHour([DateTime? from]) {
  final d = from ?? clock();
  final base = DateTime(d.year, d.month, d.day, d.hour);
  final q = (((d.minute + 1) / 15).ceil()) * 15;
  return base.add(Duration(minutes: q));
}

/* ------------------------------------------------------------------ */
/*  Birthdays                                                          */
/* ------------------------------------------------------------------ */

bool isLeapYear(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

/// Birthday date in a given year (Feb 29 → Feb 28 on non-leap years).
DateTime birthdayInYear(DateTime birthday, int year) {
  if (birthday.month == 2 && birthday.day == 29 && !isLeapYear(year)) return DateTime(year, 2, 28);
  return DateTime(year, birthday.month, birthday.day);
}

class BirthdayInfo {
  const BirthdayInfo(this.days, this.age);

  /// Days until the next birthday (0 = today).
  final int days;

  /// Age reached on that birthday.
  final int age;

  /// Age is only shown when plausible (1..119).
  bool get showAge => age >= 1 && age <= 119;
}

BirthdayInfo? nextBirthday(DateTime? birthday) {
  if (birthday == null) return null;
  final t = today();
  var next = birthdayInYear(birthday, t.year);
  if (next.isBefore(t)) next = birthdayInYear(birthday, t.year + 1);
  return BirthdayInfo(calendarDaysBetween(t, next), next.year - birthday.year);
}

/// Greeting by hour: "Bonne nuit" <5h, "Bonjour" <12h, "Bon après-midi" <18h, else "Bonsoir".
String greeting([DateTime? at]) {
  final h = (at ?? clock()).hour;
  if (h < 5) return tr.greetingNight;
  if (h < 12) return tr.greetingMorning;
  if (h < 18) return tr.greetingAfternoon;
  return tr.greetingEvening;
}
