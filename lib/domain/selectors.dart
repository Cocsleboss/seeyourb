// Pure list computations used by Home and Contacts screens.
import 'dates.dart';
import 'models.dart';
import 'text.dart';

/// "À recontacter": overdue, today, within 7 days, or marked "à voir bientôt".
/// Marked contacts first, then from most overdue to least urgent.
List<Contact> toRecontact(List<Contact> contacts) {
  final list = contacts.where((c) => c.seeSoon || dueInfo(c).days <= 7).toList();
  list.sort((a, b) {
    if (a.seeSoon != b.seeSoon) return a.seeSoon ? -1 : 1;
    final d = dueInfo(a).days.compareTo(dueInfo(b).days);
    return d != 0 ? d : compareNames(a.name, b.name);
  });
  return list;
}

/// True when the contact is in "À recontacter" only because it is marked.
bool onlyMarked(Contact c) => c.seeSoon && dueInfo(c).days > 7;

int overdueCount(List<Contact> contacts) => contacts.where((c) => dueInfo(c).kind == DueKind.overdue).length;

/// Contacts whose birthday is today.
List<Contact> birthdaysToday(List<Contact> contacts) =>
    contacts.where((c) => nextBirthday(c.birthday)?.days == 0).toList()..sort((a, b) => compareNames(a.name, b.name));

/// Birthdays in 1..7 days, soonest first.
List<(Contact, BirthdayInfo)> birthdaysThisWeek(List<Contact> contacts) {
  final out = <(Contact, BirthdayInfo)>[];
  for (final c in contacts) {
    final b = nextBirthday(c.birthday);
    if (b != null && b.days >= 1 && b.days <= 7) out.add((c, b));
  }
  out.sort((a, b) => a.$2.days.compareTo(b.$2.days));
  return out;
}

/// Contacts list groups when sorted by due date.
class DueGroups {
  DueGroups(this.overdue, this.thisWeek, this.upToDate);
  final List<Contact> overdue;
  final List<Contact> thisWeek;
  final List<Contact> upToDate;
}

DueGroups groupByDue(List<Contact> contacts) {
  final sorted = [...contacts]..sort((a, b) {
      final d = dueInfo(a).days.compareTo(dueInfo(b).days);
      return d != 0 ? d : compareNames(a.name, b.name);
    });
  return DueGroups(
    sorted.where((c) => dueInfo(c).days < 0).toList(),
    sorted.where((c) => dueInfo(c).days >= 0 && dueInfo(c).days <= 7).toList(),
    sorted.where((c) => dueInfo(c).days > 7).toList(),
  );
}

bool contactMatches(Contact c, String query) => matchesAny([c.name, ...c.categories, c.notes], query);

/// Categories actually used, sorted.
List<String> usedCategories(List<Contact> contacts) {
  final set = contacts.expand((c) => c.categories).toSet().toList();
  set.sort(compareNames);
  return set;
}

/// Groups timestamps-bearing items by a key while keeping input order.
List<(K, List<T>)> groupOrdered<T, K>(Iterable<T> items, K Function(T) key) {
  final out = <(K, List<T>)>[];
  for (final it in items) {
    final k = key(it);
    if (out.isNotEmpty && out.last.$1 == k) {
      out.last.$2.add(it);
    } else {
      out.add((k, [it]));
    }
  }
  return out;
}
