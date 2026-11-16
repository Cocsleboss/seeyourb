// "Mon agenda" calendar: one week (always visible, compact), expandable to the
// month. Days with events have dots; past days are greyed. Tap a coming day to
// filter the list below; tap a past day with events to open it in the history.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../ui/kit.dart';
import 'to_fix.dart';

/// Day picked in the calendar (null: all upcoming events).
final agendaDayProvider = NotifierProvider<AgendaDayNotifier, DateTime?>(AgendaDayNotifier.new);

class AgendaDayNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;
  void set(DateTime? d) => state = d;
}

DateTime _monday(DateTime d) => dayOf(d).subtract(Duration(days: (d.weekday + 6) % 7));

class AgendaCalendar extends ConsumerStatefulWidget {
  const AgendaCalendar({super.key, required this.planned, this.held = const {}});

  /// Proposed days of events still choosing their date (hollow rings).
  final Map<DateTime, HeldDay> held;

  /// My planned events (upcoming and not yet confirmed).
  final List<Rendezvous> planned;

  @override
  ConsumerState<AgendaCalendar> createState() => _AgendaCalendarState();
}

class _AgendaCalendarState extends ConsumerState<AgendaCalendar> {
  bool _month = false;
  late DateTime _anchor = today();

  void _shift(int delta) => setState(() {
        _anchor = _month ? DateTime(_anchor.year, _anchor.month + delta, 1) : _anchor.add(Duration(days: 7 * delta));
      });

  void _toggleMonth() => setState(() {
        _month = !_month;
        // back to the week of the selected day (or today) when collapsing
        if (!_month) _anchor = ref.read(agendaDayProvider) ?? today();
      });

  void _tap(DateTime day, bool hasPast) {
    final t = today();
    if (day.isBefore(t)) {
      if (hasPast) context.push('/history/day/${dayIso(day)}');
      return;
    }
    final sel = ref.read(agendaDayProvider);
    ref.read(agendaDayProvider.notifier).set(sel == day ? null : day);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selected = ref.watch(agendaDayProvider);
    final history = ref.watch(historyProvider).value ?? const <Rendezvous>[];
    final t = today();

    final coming = <DateTime, int>{};
    for (final r in widget.planned) {
      if (r.slotsOpen) continue;
      final d = dayOf(r.appointmentAt);
      coming[d] = (coming[d] ?? 0) + 1;
    }
    final past = <DateTime, int>{};
    for (final r in history) {
      if (r.status != RdvStatus.valide) continue;
      final d = dayOf(r.appointmentAt);
      // Today and later: dots = what the list shows when the day is picked.
      if (!d.isBefore(t)) continue;
      past[d] = (past[d] ?? 0) + 1;
    }

    final List<DateTime> days;
    final String label;
    if (_month) {
      final first = DateTime(_anchor.year, _anchor.month, 1);
      final start = _monday(first);
      final last = DateTime(_anchor.year, _anchor.month + 1, 0);
      final count = last.difference(start).inDays + 1;
      days = [for (var i = 0; i < ((count + 6) ~/ 7) * 7; i++) DateTime(start.year, start.month, start.day + i)];
      label = monthLabel(first);
    } else {
      final start = _monday(_anchor);
      days = [for (var i = 0; i < 7; i++) DateTime(start.year, start.month, start.day + i)];
      final end = days.last;
      label = start.month == end.month
          ? '${start.day} – ${DateFormat.MMMd().format(end)}'
          : '${DateFormat.MMMd().format(start)} – ${DateFormat.MMMd().format(end)}';
    }
    final weekdays = [for (var i = 0; i < 7; i++) DateFormat('EEEEE').format(DateTime(2024, 1, 1 + i)).toUpperCase()];

    Widget cell(DateTime d) {
      final isPast = d.isBefore(t);
      final isToday = d == t;
      final isSel = selected == d;
      final outside = _month && d.month != _anchor.month;
      final nComing = coming[d] ?? 0;
      final hold = widget.held[d];
      final nPast = past[d] ?? 0;
      final fg = isSel
          ? Colors.white
          : outside
              ? c.textSubtle.withValues(alpha: 0.5)
              : isPast
                  ? c.textSubtle
                  : c.text;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _tap(d, nPast > 0 || nComing > 0 || hold != null),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isSel ? Palette.brand600 : (isPast && !outside ? c.secondaryFill.withValues(alpha: 0.6) : null),
                borderRadius: BorderRadius.circular(12),
                border: isToday && !isSel ? Border.all(color: Palette.brand600, width: 1.5) : null,
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${d.day}',
                    style: TextStyle(fontSize: 15, fontWeight: isToday || isSel ? FontWeight.w800 : FontWeight.w600, color: fg)),
                const SizedBox(height: 3),
                SizedBox(
                  height: 6,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (var i = 0; i < (nComing + nPast).clamp(0, 3); i++)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSel ? Colors.white : (i < nComing && !isPast ? Palette.brand600 : c.textSubtle),
                        ),
                      ),
                    // proposed slot (date not fixed): hollow ring, colored by my answer
                    if (hold != null && !isPast)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: isSel ? Colors.white : heldColor(c, hold.answer), width: 1.5),
                        ),
                      ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconButton(
            tooltip: _month ? tr.prevMonth : tr.prevWeek,
            visualDensity: VisualDensity.compact,
            onPressed: () => _shift(-1),
            icon: Icon(LucideIcons.chevronLeft, color: c.brandText),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _anchor = t),
              child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: c.text)),
            ),
          ),
          IconButton(
            tooltip: _month ? tr.nextMonth : tr.nextWeek,
            visualDensity: VisualDensity.compact,
            onPressed: () => _shift(1),
            icon: Icon(LucideIcons.chevronRight, color: c.brandText),
          ),
          TextButton.icon(
            onPressed: _toggleMonth,
            icon: Icon(_month ? LucideIcons.chevronsDownUp : LucideIcons.chevronsUpDown, size: 16, color: c.brandText),
            label: Text(_month ? tr.calendarWeek : tr.calendarMonth, style: TextStyle(color: c.brandText, fontWeight: FontWeight.w600)),
          ),
        ]),
        Row(children: [
          for (final w in weekdays)
            Expanded(child: Text(w, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.textMuted))),
        ]),
        const SizedBox(height: 2),
        for (var row = 0; row < days.length ~/ 7; row++) Row(children: [for (final d in days.skip(row * 7).take(7)) cell(d)]),
        // Legend, only when proposed slots are in view.
        if (days.any((d) => widget.held.containsKey(d) && !d.isBefore(t)))
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Row(children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: Palette.brand600)),
              const SizedBox(width: 5),
              Text(tr.legendFixed, style: TextStyle(fontSize: 11.5, color: c.textMuted)),
              const SizedBox(width: 12),
              const TriRing(),
              const SizedBox(width: 5),
              Flexible(child: Text(tr.legendProposed, style: TextStyle(fontSize: 11.5, color: c.textMuted))),
            ]),
          ),
      ]),
    );
  }
}
