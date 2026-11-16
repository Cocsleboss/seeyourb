// Events still choosing their date (several timeslots). They never borrow a
// fake date: they live in their own "À fixer" block (amber, dashed look), and
// the calendar shows each proposed day as a hollow ring colored by my answer.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../ui/kit.dart';

/// Proposed days of my open events: day → my strongest answer that day
/// (yes > maybe > no / none), with the events and times.
class HeldDay {
  HeldDay(this.answer, this.items);
  SlotAnswer? answer;
  final List<(Rendezvous, EventSlot)> items;
}

int _rank(SlotAnswer? a) => switch (a) { SlotAnswer.yes => 3, SlotAnswer.maybe => 2, SlotAnswer.no => 1, null => 0 };

Map<DateTime, HeldDay> heldDays(WidgetRef ref, List<Rendezvous> planned) {
  final out = <DateTime, HeldDay>{};
  for (final r in planned.where((r) => r.slotsOpen && r.eventId != null)) {
    final slots = ref.watch(slotsProvider(r.eventId!)).value ?? const <EventSlot>[];
    for (final s in slots) {
      final d = dayOf(s.startsAt);
      // The organizer proposed them: counts as available.
      final mine = r.isOrganizer ? SlotAnswer.yes : s.myAnswer;
      final h = out.putIfAbsent(d, () => HeldDay(null, []));
      h.items.add((r, s));
      if (_rank(mine) > _rank(h.answer)) h.answer = mine;
    }
  }
  return out;
}

Color heldColor(AppColors c, SlotAnswer? a) => switch (a) {
      SlotAnswer.yes => c.tone(Tone.green).solid,
      SlotAnswer.maybe => c.tone(Tone.amber).solid,
      _ => c.textSubtle,
    };

/// One event to fix. Deliberately unlike a fixed event row: amber frame,
/// "?" calendar instead of a date, "Date à choisir" tag, and my status.
class ToFixCard extends ConsumerWidget {
  const ToFixCard({super.key, required this.rdv});
  final Rendezvous rdv;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final amber = c.tone(Tone.amber);
    final slots = ref.watch(slotsProvider(rdv.eventId!)).value;

    Widget status;
    if (slots == null) {
      status = Text(tr.dateToChoose, style: TextStyle(fontSize: 13, color: c.textMuted));
    } else if (rdv.isOrganizer) {
      final voters = slots.isEmpty ? 0 : slots.map((s) => s.yes + s.maybe + s.no).reduce((a, b) => a > b ? a : b);
      final others = (rdv.event?.memberCount ?? 1) - 1;
      final best = bestSlots(slots);
      status = _StatusLine(
        icon: LucideIcons.users,
        color: c.textMuted,
        text: [
          tr.answeredCount(voters, others < voters ? voters : others),
          if (best.length == 1) '${tr.bestShort} ${formatDayMonth(best.first.startsAt)}',
        ].join(' · '),
      );
    } else if (slots.every((s) => s.myAnswer == null)) {
      status = _StatusLine(icon: LucideIcons.circleAlert, color: c.tone(Tone.orange).text, text: tr.yourTurnToAnswer(slots.length), bold: true);
    } else {
      final yes = slots.where((s) => s.myAnswer == SlotAnswer.yes).length;
      final maybe = slots.where((s) => s.myAnswer == SlotAnswer.maybe).length;
      status = _StatusLine(icon: LucideIcons.circleCheck, color: c.tone(Tone.green).text, text: tr.availabilitySentShort(yes, maybe));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: amber.bg.withValues(alpha: c.isDark ? 0.25 : 0.45),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/rdv/${rdv.id}'),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: amber.solid.withValues(alpha: 0.55), width: 1.5),
            ),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: amber.solid.withValues(alpha: 0.6), width: 1.5),
                ),
                child: Icon(LucideIcons.calendarClock, color: amber.text, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (rdv.isOrganizer) ...[Icon(LucideIcons.crown, size: 15, color: c.brandText), const SizedBox(width: 5)],
                    Expanded(
                      child: Text(rdv.displayTitle,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.text)),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    Pill(tr.dateToChoose, tone: Tone.amber, icon: LucideIcons.calendarClock),
                    if (slots != null) ...[
                      const SizedBox(width: 6),
                      Text(tr.nSlots(slots.length), style: TextStyle(fontSize: 12.5, color: c.textMuted)),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  status,
                ]),
              ),
              Icon(LucideIcons.chevronRight, color: c.textMuted, size: 20),
            ]),
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.icon, required this.color, required this.text, this.bold = false});
  final IconData icon;
  final Color color;
  final String text;
  final bool bold;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(text,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        ),
      ]);
}

/// Picked day with proposed slots: "Créneaux proposés ce jour" + my answer.
class ProposedThatDay extends StatelessWidget {
  const ProposedThatDay({super.key, required this.held});
  final HeldDay held;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Overline(tr.proposedSlotsThatDay),
      for (final (r, s) in held.items)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: c.tone(Tone.amber).bg.withValues(alpha: c.isDark ? 0.25 : 0.45),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/rdv/${r.id}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  Icon(LucideIcons.calendarClock, size: 18, color: c.tone(Tone.amber).text),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${formatTime(s.startsAt)} · ${r.displayTitle}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
                  ),
                  _AnswerPill(r.isOrganizer ? null : s.myAnswer, organizer: r.isOrganizer),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}

class _AnswerPill extends StatelessWidget {
  const _AnswerPill(this.answer, {this.organizer = false});
  final SlotAnswer? answer;
  final bool organizer;
  @override
  Widget build(BuildContext context) {
    if (organizer) return Pill(tr.youProposed, tone: Tone.brand);
    return switch (answer) {
      SlotAnswer.yes => Pill(tr.slotYes, tone: Tone.green, icon: LucideIcons.check),
      SlotAnswer.maybe => Pill(tr.slotMaybe, tone: Tone.amber),
      SlotAnswer.no => Pill(tr.slotNo, tone: Tone.red),
      null => Pill(tr.notAnswered, tone: Tone.orange),
    };
  }
}

/// Event form: warn (not block) when the chosen day is held by a slot I said yes / maybe to.
String? heldWarning(Map<DateTime, HeldDay> held, DateTime day, {String? exceptRdv}) {
  final h = held[dayOf(day)];
  if (h == null) return null;
  final hits = h.items.where((x) =>
      x.$1.id != exceptRdv && (x.$1.isOrganizer || x.$2.myAnswer == SlotAnswer.yes || x.$2.myAnswer == SlotAnswer.maybe));
  if (hits.isEmpty) return null;
  final (r, s) = hits.first;
  return tr.heldDayWarning(r.displayTitle, formatTime(s.startsAt));
}
