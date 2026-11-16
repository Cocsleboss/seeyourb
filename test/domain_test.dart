import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:seeu/core/i18n.dart';
import 'package:seeu/domain/contact_import.dart';
import 'package:seeu/domain/dates.dart';
import 'package:seeu/domain/models.dart';
import 'package:seeu/domain/selectors.dart';
import 'package:seeu/domain/text.dart';

Contact contact(String name, {required DateTime due, DateTime? snooze, bool seeSoon = false, DateTime? birthday}) => Contact(
      id: name,
      userId: 'u',
      name: name,
      lastMeetingDate: DateTime(2026, 1, 1),
      frequencyValue: 1,
      frequencyUnit: FrequencyUnit.months,
      nextDueDate: due,
      snoozeUntil: snooze,
      seeSoon: seeSoon,
      birthday: birthday,
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    applyLanguage('fr');
  });
  setUp(() => clock = () => DateTime(2026, 11, 14, 20, 15));
  tearDown(() => clock = DateTime.now);

  group('addFrequency', () {
    test('real calendar months', () {
      expect(addFrequency(DateTime(2027, 1, 31), 1, FrequencyUnit.months), DateTime(2027, 2, 28));
      expect(addFrequency(DateTime(2028, 1, 31), 1, FrequencyUnit.months), DateTime(2028, 2, 29));
      expect(addFrequency(DateTime(2026, 11, 12), 2, FrequencyUnit.months), DateTime(2027, 1, 12));
      expect(addFrequency(DateTime(2028, 2, 29), 1, FrequencyUnit.years), DateTime(2029, 2, 28));
      expect(addFrequency(DateTime(2026, 3, 28), 2, FrequencyUnit.days), DateTime(2026, 3, 30));
      expect(addFrequency(DateTime(2026, 10, 20), 2, FrequencyUnit.weeks), DateTime(2026, 11, 3));
    });
  });

  group('humanizeDays', () {
    test('rounding rules', () {
      expect(humanizeDays(1), '1 jour');
      expect(humanizeDays(3), '3 jours');
      expect(humanizeDays(13), '13 jours');
      expect(humanizeDays(15), '2 semaines');
      expect(humanizeDays(28), '4 semaines');
      expect(humanizeDays(59), '8 semaines');
      expect(humanizeDays(60), '2 mois');
      expect(humanizeDays(95), '3 mois');
      expect(humanizeDays(349), '11 mois');
      expect(humanizeDays(400), '1 an');
      expect(humanizeDays(550), '1 an et demi');
      expect(humanizeDays(800), '2 ans');
    });
    test('short', () {
      expect(shortDays(3), '3 j');
      expect(shortDays(20), '3 sem.');
      expect(shortDays(65), '2 mois');
    });
  });

  group('dueInfo', () {
    test('kinds and labels', () {
      final over = dueInfo(contact('a', due: DateTime(2026, 11, 11)));
      expect(over.kind, DueKind.overdue);
      expect(over.label, 'En retard de 3 jours');
      expect(over.short, '-3 j');
      final t = dueInfo(contact('b', due: DateTime(2026, 11, 14)));
      expect(t.kind, DueKind.today);
      expect(t.short, 'Auj.');
      final soon = dueInfo(contact('c', due: DateTime(2026, 11, 19)));
      expect(soon.kind, DueKind.soon);
      expect(soon.label, 'À revoir dans 5 jours');
      expect(dueInfo(contact('d', due: DateTime(2026, 11, 22))).kind, DueKind.ok);
    });
    test('snooze only pushes later', () {
      final c = contact('a', due: DateTime(2026, 11, 11), snooze: DateTime(2026, 11, 21));
      expect(effectiveDueDate(c), DateTime(2026, 11, 21));
      final c2 = contact('a', due: DateTime(2026, 11, 11), snooze: DateTime(2026, 11, 1));
      expect(effectiveDueDate(c2), DateTime(2026, 11, 11));
    });
  });

  test('frequencyLabel', () {
    expect(frequencyLabel(1, FrequencyUnit.weeks), 'toutes les semaines');
    expect(frequencyLabel(3, FrequencyUnit.weeks), 'toutes les 3 semaines');
    expect(frequencyLabel(2, FrequencyUnit.months), 'tous les 2 mois');
    expect(frequencyLabel(1, FrequencyUnit.years), 'tous les ans');
  });

  group('birthdays', () {
    test('next birthday and age', () {
      final b = nextBirthday(DateTime(2003, 11, 29))!;
      expect(b.days, 15);
      expect(b.age, 23);
      expect(nextBirthday(DateTime(1996, 11, 14))!.days, 0);
      expect(nextBirthday(DateTime(1996, 11, 13))!.days, 364);
    });
    test('Feb 29 celebrated Feb 28 on non-leap years', () {
      clock = () => DateTime(2027, 2, 28, 9);
      expect(nextBirthday(DateTime(2000, 2, 29))!.days, 0);
      clock = () => DateTime(2028, 2, 28, 9);
      expect(nextBirthday(DateTime(2000, 2, 29))!.days, 1);
    });
    test('implausible ages hidden', () {
      expect(const BirthdayInfo(3, 0).showAge, isFalse);
      expect(const BirthdayInfo(3, 30).showAge, isTrue);
    });
  });

  test('greeting', () {
    expect(greeting(DateTime(2026, 1, 1, 4)), 'Bonne nuit');
    expect(greeting(DateTime(2026, 1, 1, 11)), 'Bonjour');
    expect(greeting(DateTime(2026, 1, 1, 17)), 'Bon après-midi');
    expect(greeting(DateTime(2026, 1, 1, 18)), 'Bonsoir');
  });

  test('formatting', () {
    expect(formatDate(DateTime(2026, 11, 12)), '12 nov. 2026');
    expect(formatDateLong(DateTime(2026, 11, 12)), 'jeudi 12 novembre 2026');
    expect(formatDayMonth(DateTime(2026, 11, 14)), 'Samedi 14 novembre');
    expect(relativeDayLabel(DateTime(2026, 11, 15, 9)), 'Demain');
    expect(relativeDayLabel(DateTime(2026, 11, 13, 9)), 'Hier');
    expect(monthShort(DateTime(2026, 11, 14)), 'NOV');
    expect(monthLabel(DateTime(2026, 11, 14)), 'Novembre 2026');
  });

  test('nextQuarterHour', () {
    expect(nextQuarterHour(DateTime(2026, 1, 1, 10, 0)), DateTime(2026, 1, 1, 10, 15));
    expect(nextQuarterHour(DateTime(2026, 1, 1, 10, 7)), DateTime(2026, 1, 1, 10, 15));
    expect(nextQuarterHour(DateTime(2026, 1, 1, 10, 52)), DateTime(2026, 1, 1, 11, 0));
  });

  group('text', () {
    test('accent-insensitive search', () {
      expect(matchesQuery('Hélène', 'helene'), isTrue);
      expect(matchesQuery('Hélène Dupont', 'DUP'), isTrue);
      expect(matchesQuery('Paul', 'marie'), isFalse);
      expect(matchesQuery(null, ''), isTrue);
    });
    test('initials', () {
      expect(initials('Marie Dupont'), 'MD');
      expect(initials('Cocsi_bucci'), 'CO');
      expect(initials(''), '?');
    });
    test('usernames', () {
      expect(normalizeUsername('@Élodie Martin!'), 'elodiemartin');
      expect(usernameFormatError('ab'), isNotNull);
      expect(usernameFormatError('_abc'), isNotNull);
      expect(usernameFormatError('marie.d'), isNull);
      expect(suggestUsername('jean.pierre@mail.com'), 'jean.pierre');
      expect(suggestUsername('Jean Pierre'), 'jean.pierre');
    });
    test('joinNames', () {
      expect(joinNames(['A']), 'A');
      expect(joinNames(['A', 'B', 'C']), 'A, B et C');
      expect(joinNames(['A', 'B', 'C', 'D', 'E']), 'A, B, C et 2 autres');
    });
    test('rdvTitle', () {
      expect(rdvTitle(null, ['Marie', 'Paul']), 'Avec Marie, Paul');
      expect(rdvTitle(null, ['A', 'B', 'C', 'D']), 'Avec A, B et 2 autres');
      expect(rdvTitle(' Poker ', ['A']), 'Poker');
    });
  });

  group('import', () {
    test('phone key keeps last 9 digits', () {
      expect(phoneKey('06 12 34 56 78'), phoneKey('+33 6 12 34 56 78'));
      expect(phoneKey('0033612345678'), '612345678');
      expect(phoneKey('123'), isNull);
    });
    test('dedupe against app and within selection', () {
      final list = [
        ImportedContact(key: '1', name: 'Hélène', phone: '0612345678'),
        ImportedContact(key: '2', name: 'Paul', phone: '+33 6 12 34 56 78'),
        ImportedContact(key: '3', name: 'Léa', email: 'LEA@x.fr'),
        ImportedContact(key: '4', name: 'lea'),
        ImportedContact(key: '5', name: 'Marc', email: 'marc@x.fr'),
      ];
      final r = dedupeImported(list, [(name: 'helene', phone: null, email: null), (name: 'Zoé', phone: null, email: 'marc@x.fr')]);
      expect(r.fresh.map((c) => c.key), ['2', '3']);
      expect(r.alreadyThere, 2);
      expect(r.duplicates, 1);
    });
  });

  group('selectors', () {
    test('toRecontact ordering', () {
      final list = toRecontact([
        contact('far', due: DateTime(2027, 1, 1)),
        contact('marked', due: DateTime(2027, 1, 1), seeSoon: true),
        contact('soon', due: DateTime(2026, 11, 18)),
        contact('late', due: DateTime(2026, 11, 1)),
      ]);
      expect(list.map((c) => c.name), ['marked', 'late', 'soon']);
      expect(onlyMarked(list.first), isTrue);
    });
    test('groupByDue', () {
      final g = groupByDue([
        contact('a', due: DateTime(2026, 11, 1)),
        contact('b', due: DateTime(2026, 11, 14)),
        contact('c', due: DateTime(2026, 11, 21)),
        contact('d', due: DateTime(2026, 11, 22)),
      ]);
      expect(g.overdue.length, 1);
      expect(g.thisWeek.map((c) => c.name), ['b', 'c']);
      expect(g.upToDate.map((c) => c.name), ['d']);
    });
    test('birthdays', () {
      final cs = [
        contact('today', due: DateTime(2027), birthday: DateTime(1990, 11, 14)),
        contact('in3', due: DateTime(2027), birthday: DateTime(1990, 11, 17)),
        contact('in10', due: DateTime(2027), birthday: DateTime(1990, 11, 24)),
      ];
      expect(birthdaysToday(cs).map((c) => c.name), ['today']);
      expect(birthdaysThisWeek(cs).map((e) => e.$1.name), ['in3']);
    });
  });

  test('events still choosing a date never ask "did it happen?"', () {
    Rendezvous rdv({required bool slots}) => Rendezvous(
          id: 'x',
          userId: 'me',
          appointmentAt: DateTime(2026, 11, 13, 12),
          status: RdvStatus.planifie,
          eventId: 'e',
          event: EventInfo(id: 'e', organizerId: 'me', slotsOpen: slots),
        );
    final now = DateTime(2026, 11, 14, 20);
    expect(rdv(slots: false).needsConfirmation(now), isTrue);
    expect(rdv(slots: true).needsConfirmation(now), isFalse);
  });

  test('best timeslots: most available, maybe counts half, ties kept', () {
    EventSlot s(String id, int yes, int maybe) => EventSlot(id: id, startsAt: DateTime(2026, 12, 1), yes: yes, maybe: maybe);
    expect(bestSlots([s('a', 2, 1), s('b', 3, 0), s('c', 1, 2)]).map((x) => x.id), ['b']);
    expect(bestSlots([s('a', 2, 2), s('b', 3, 0)]).map((x) => x.id), ['a', 'b']);
    expect(bestSlots([s('a', 0, 0)]), isEmpty);
  });

  test('normalizeLink accepts links without https and rejects text', () {
    expect(normalizeLink('www.poker.be'), 'https://www.poker.be');
    expect(normalizeLink('poker.be/soiree'), 'https://poker.be/soiree');
    expect(normalizeLink('http://a.com'), 'http://a.com');
    expect(normalizeLink('HTTPS://X.org/a?b=1'), 'HTTPS://X.org/a?b=1');
    expect(normalizeLink('chez moi'), isNull);
    expect(normalizeLink('abc'), isNull);
  });
}
