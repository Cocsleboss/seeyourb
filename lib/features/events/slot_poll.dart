// Timeslot poll: each member answers yes / maybe / no per slot; bars show how many
// are available; the summary highlights the best slot; the organizer picks it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../domain/text.dart';
import '../../ui/feedback.dart';
import '../../ui/kit.dart';

class SlotPoll extends ConsumerStatefulWidget {
  const SlotPoll({super.key, required this.eventId, required this.isOrganizer, required this.members});
  final String eventId;
  final bool isOrganizer;

  /// People who can vote (bar denominator).
  final int members;

  @override
  ConsumerState<SlotPoll> createState() => _SlotPollState();
}

class _SlotPollState extends ConsumerState<SlotPoll> {
  /// Optimistic answers while the server confirms.
  final _mine = <String, SlotAnswer?>{};
  String? _busy;

  Future<void> _vote(EventSlot s, SlotAnswer a) async {
    final next = (_mine.containsKey(s.id) ? _mine[s.id] : s.myAnswer) == a ? null : a;
    setState(() => _mine[s.id] = next);
    try {
      await ref.read(apiProvider).voteSlot(s.id, next);
      ref.invalidate(slotsProvider(widget.eventId));
      await ref.read(slotsProvider(widget.eventId).future);
      if (mounted) setState(() => _mine.remove(s.id));
    } catch (e) {
      if (mounted) setState(() => _mine.remove(s.id));
      showError(e);
    }
  }

  Future<void> _choose(EventSlot s) async {
    final ok = await confirmSheet(
      context,
      title: tr.chooseSlotTitle(capitalize(formatDayTime(s.startsAt))),
      message: tr.chooseSlotMessage,
      confirmLabel: tr.chooseThisSlot,
      danger: false,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = s.id);
    final done = await guard(() async {
      await ref.read(apiProvider).chooseSlot(s.id);
      return true;
    }, success: tr.slotChosen);
    if (!mounted) return;
    setState(() => _busy = null);
    if (done != null) refreshData(ref);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final value = ref.watch(slotsProvider(widget.eventId));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(tr.slotsPollTitle),
      AsyncBody(
        value: value,
        skeletonRows: 2,
        onRetry: () => ref.invalidate(slotsProvider(widget.eventId)),
        builder: (slots) {
          final best = bestSlots(slots).map((s) => s.id).toSet();
          final voters = slots.isEmpty ? 0 : slots.map((s) => s.yes + s.maybe + s.no).reduce((a, b) => a > b ? a : b);
          final total = widget.members < voters ? voters : widget.members;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr.slotsPollHelp, style: TextStyle(color: c.textMuted, fontSize: 14, height: 1.35)),
            const SizedBox(height: 10),
            RowsCard(children: [
              for (final s in slots)
                _SlotRow(
                  slot: s,
                  mine: _mine.containsKey(s.id) ? _mine[s.id] : s.myAnswer,
                  best: best.contains(s.id),
                  total: total,
                  onVote: (a) => _vote(s, a),
                  onChoose: widget.isOrganizer ? () => _choose(s) : null,
                  choosing: _busy == s.id,
                ),
            ]),
            const SizedBox(height: 12),
            _Summary(slots: slots, best: slots.where((s) => best.contains(s.id)).toList(), isOrganizer: widget.isOrganizer, onChoose: _choose),
          ]);
        },
      ),
    ]);
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.slot,
    required this.mine,
    required this.best,
    required this.total,
    required this.onVote,
    this.onChoose,
    this.choosing = false,
  });
  final EventSlot slot;
  final SlotAnswer? mine;
  final bool best;
  final int total;
  final ValueChanged<SlotAnswer> onVote;
  final VoidCallback? onChoose;
  final bool choosing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final green = c.tone(Tone.green);
    final amber = c.tone(Tone.amber);
    final denom = total <= 0 ? 1 : total;
    final names = [
      if (slot.yesNames.isNotEmpty) joinNames(slot.yesNames, max: 4),
      if (slot.maybeNames.isNotEmpty) '${tr.slotMaybeShort} : ${joinNames(slot.maybeNames, max: 3)}',
    ].join(' · ');

    Widget answer(SlotAnswer a, IconData icon, Tone tone, String label) {
      final on = mine == a;
      final t = c.tone(tone);
      return Tooltip(
        message: label,
        child: InkResponse(
          onTap: () => onVote(a),
          radius: 24,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: on ? t.solid : c.secondaryFill,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: on ? Colors.white : c.textMuted),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(capitalize(formatDayMonth(slot.startsAt)),
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: c.text)),
                ),
                if (best) ...[const SizedBox(width: 6), Icon(LucideIcons.star, size: 16, color: amber.solid)],
              ]),
              Text(formatTime(slot.startsAt), style: TextStyle(color: c.textMuted, fontSize: 14)),
            ]),
          ),
          answer(SlotAnswer.yes, LucideIcons.check, Tone.green, tr.slotYes),
          const SizedBox(width: 6),
          answer(SlotAnswer.maybe, LucideIcons.circleHelp, Tone.amber, tr.slotMaybe),
          const SizedBox(width: 6),
          answer(SlotAnswer.no, LucideIcons.x, Tone.red, tr.slotNo),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 8,
            child: Row(children: [
              if (slot.yes > 0) Expanded(flex: slot.yes, child: Container(color: green.solid)),
              if (slot.maybe > 0) Expanded(flex: slot.maybe, child: Container(color: amber.solid)),
              if (denom - slot.yes - slot.maybe > 0) Expanded(flex: denom - slot.yes - slot.maybe, child: Container(color: c.secondaryFill)),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: Text(
              [tr.slotCounts(slot.yes, slot.maybe), if (names.isNotEmpty) names].join(' — '),
              style: TextStyle(fontSize: 12.5, color: c.textMuted),
            ),
          ),
          if (onChoose != null)
            AppButton(tr.choose, size: ButtonSize.sm, variant: best ? ButtonVariant.primary : ButtonVariant.ghost, loading: choosing, onPressed: onChoose),
        ]),
      ]),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.slots, required this.best, required this.isOrganizer, required this.onChoose});
  final List<EventSlot> slots;
  final List<EventSlot> best;
  final bool isOrganizer;
  final ValueChanged<EventSlot> onChoose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = c.tone(best.isEmpty ? Tone.gray : Tone.green);
    return AppCard(
      color: t.bg,
      borderColor: t.bg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(best.isEmpty ? LucideIcons.hourglass : LucideIcons.trophy, color: t.fg, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(best.isEmpty ? tr.slotsNoVotes : (best.length == 1 ? tr.bestSlot : tr.bestSlotsTie),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: t.fg)),
          ),
        ]),
        for (final s in best) ...[
          const SizedBox(height: 6),
          Text('${capitalize(formatDayTime(s.startsAt))} · ${tr.slotCounts(s.yes, s.maybe)}',
              style: TextStyle(color: t.fg, fontSize: 14.5)),
        ],
        if (best.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(isOrganizer ? tr.slotsWaitOrganizer : tr.slotsWaitMember, style: TextStyle(color: t.fg, fontSize: 14)),
          )
        else if (isOrganizer && best.length == 1) ...[
          const SizedBox(height: 10),
          AppButton(tr.chooseThisSlot, icon: LucideIcons.calendarCheck, full: true, onPressed: () => onChoose(best.first)),
        ] else if (!isOrganizer)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(tr.slotsOrganizerDecides, style: TextStyle(color: t.fg.withValues(alpha: 0.85), fontSize: 13.5)),
          ),
      ]),
    );
  }
}
