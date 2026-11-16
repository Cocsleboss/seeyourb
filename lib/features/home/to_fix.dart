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

/// Ring color = my answer: yes green, maybe amber, no red, not answered grey.
Color heldColor(AppColors c, SlotAnswer? a) => switch (a) {
      SlotAnswer.yes => c.tone(Tone.green).solid,
      SlotAnswer.maybe => c.tone(Tone.amber).solid,
      SlotAnswer.no => c.tone(Tone.red).solid,
      null => c.textSubtle,
    };

/// Legend ring: one third green, amber, red ("colored by your answer").
class TriRing extends StatelessWidget {
  const TriRing({super.key, this.size = 9});
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CustomPaint(
      size: Size.square(size),
      painter: _TriRingPainter([c.tone(Tone.green).solid, c.tone(Tone.amber).solid, c.tone(Tone.red).solid]),
    );
  }
}

class _TriRingPainter extends CustomPainter {
  _TriRingPainter(this.colors);
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 1.8;
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    const third = 2 * 3.14159265 / 3;
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(r, -3.14159265 / 2 + i * third, third, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..color = colors[i]);
    }
  }

  @override
  bool shouldRepaint(_TriRingPainter old) => old.colors != colors;
}

/// "Date confirmée par Andrea" / "Vous fixez la date": who decides, so it
/// doesn't read as something I must do.
String dateDecidedBy(WidgetRef ref, Rendezvous r) {
  if (r.isOrganizer) return tr.dateYouSet;
  final name = r.eventId == null ? null : ref.watch(eventProvider(r.eventId!)).value?.organizerName;
  return name == null ? tr.dateToChoose : tr.dateConfirmedBy(name);
}

/// Does this event wait on me? Member: not answered yet. Organizer: everyone
/// answered (time to pick the date).
bool toFixNeedsMe(Rendezvous rdv, List<EventSlot>? slots) {
  if (slots == null) return !rdv.isOrganizer;
  if (!rdv.isOrganizer) return slots.every((s) => s.myAnswer == null);
  final voters = slots.isEmpty ? 0 : slots.map((s) => s.yes + s.maybe + s.no).reduce((a, b) => a > b ? a : b);
  final others = (rdv.event?.memberCount ?? 1) - 1;
  return others > 0 && voters >= others;
}

/// One event to fix. Deliberately unlike a fixed event row: amber frame,
/// "?" calendar instead of a date, "Date à choisir" tag, and my status.
class ToFixCard extends ConsumerWidget {
  const ToFixCard({super.key, required this.rdv});
  final Rendezvous rdv;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final slots = ref.watch(slotsProvider(rdv.eventId!)).value;
    // Amber only while it's on me (answer / choose the date); grey while I wait.
    final needsMe = toFixNeedsMe(rdv, slots);
    final amber = needsMe ? c.tone(Tone.amber) : c.tone(Tone.gray);

    Widget status;
    if (slots == null) {
      status = Text(dateDecidedBy(ref, rdv), style: TextStyle(fontSize: 13, color: c.textMuted));
    } else if (rdv.isOrganizer) {
      final voters = slots.isEmpty ? 0 : slots.map((s) => s.yes + s.maybe + s.no).reduce((a, b) => a > b ? a : b);
      final others = (rdv.event?.memberCount ?? 1) - 1;
      final best = bestSlots(slots);
      status = _StatusLine(
        icon: needsMe ? LucideIcons.calendarCheck : LucideIcons.hourglass,
        color: needsMe ? c.tone(Tone.amber).text : c.textMuted,
        bold: needsMe,
        text: [
          if (needsMe) tr.yourTurnToChoose else tr.waitingForAnswers,
          tr.answeredCount(voters, others < voters ? voters : others),
          if (best.length == 1) '${tr.bestShort} ${formatDayMonth(best.first.startsAt)}',
        ].join(' · '),
      );
    } else if (slots.every((s) => s.myAnswer == null)) {
      status = _StatusLine(icon: LucideIcons.circleAlert, color: c.tone(Tone.orange).text, text: tr.yourTurnToAnswer(slots.length), bold: true);
    } else {
      final yes = slots.where((s) => s.myAnswer == SlotAnswer.yes).length;
      final maybe = slots.where((s) => s.myAnswer == SlotAnswer.maybe).length;
      status = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _StatusLine(icon: LucideIcons.circleCheck, color: c.tone(Tone.green).text, text: tr.availabilitySentShort(yes, maybe)),
        const SizedBox(height: 2),
        _StatusLine(icon: LucideIcons.hourglass, color: c.textMuted, text: tr.waitingForOrganizer),
      ]);
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
                    Flexible(child: Pill(dateDecidedBy(ref, rdv), tone: needsMe ? Tone.amber : Tone.gray, icon: LucideIcons.calendarClock)),
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
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 14, color: color)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(text,
              maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        ),
      ]);
}

/// Proposed slots of one day, shown under that day's fixed events: lighter
/// rows with the "?" calendar, "Créneau proposé" and my answer.
class ProposedSlotRows extends StatelessWidget {
  const ProposedSlotRows({super.key, required this.items});
  final List<(Rendezvous, EventSlot)> items;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sorted = [...items]..sort((a, b) => a.$2.startsAt.compareTo(b.$2.startsAt));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final (r, s) in sorted)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Material(
            color: c.secondaryFill,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => context.push('/rdv/${r.id}'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(children: [
                  Icon(LucideIcons.calendarClock, size: 20, color: heldColor(c, r.isOrganizer ? SlotAnswer.yes : s.myAnswer)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${formatTime(s.startsAt)} · ${r.displayTitle}',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
                      const SizedBox(height: 1),
                      Text(tr.proposedSlot, style: TextStyle(fontSize: 12, color: c.textMuted)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  if (!r.isOrganizer) ...[
                    Text(tr.yourAnswerShort, style: TextStyle(fontSize: 12, color: c.textMuted)),
                    const SizedBox(width: 6),
                  ],
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
