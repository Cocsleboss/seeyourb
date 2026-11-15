// Timeslot poll. Each member answers yes / maybe / no per slot; answers stay a
// draft until "Valider mes disponibilités", which also sets the member's RSVP:
// ≥ 1 yes → going, all no → declined (organizer notified), otherwise "à confirmer".
// Leaving with unsent answers asks to confirm (unanswered slots count as maybe).
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

/// Unsent answers per event (slot id → answer).
final availabilityDraftProvider =
    NotifierProvider.family<AvailabilityDraft, Map<String, SlotAnswer>, String>(AvailabilityDraft.new);

class AvailabilityDraft extends Notifier<Map<String, SlotAnswer>> {
  AvailabilityDraft(this.eventId);
  final String eventId;

  @override
  Map<String, SlotAnswer> build() => const {};

  void set(String slotId, SlotAnswer a) => state = {...state, slotId: a};
  void clear() => state = const {};
}

/// My answer per slot: draft first, else what the server has.
Map<String, SlotAnswer?> mergedAnswers(List<EventSlot> slots, Map<String, SlotAnswer> draft) =>
    {for (final s in slots) s.id: draft[s.id] ?? s.myAnswer};

/// RSVP that these answers lead to (unanswered = maybe).
Rsvp rsvpFromAnswers(Iterable<SlotAnswer?> answers) {
  final list = answers.map((a) => a ?? SlotAnswer.maybe).toList();
  if (list.any((a) => a == SlotAnswer.yes)) return Rsvp.accepted;
  if (list.isNotEmpty && list.every((a) => a == SlotAnswer.no)) return Rsvp.declined;
  return Rsvp.pending;
}

/// True when there are answers not sent yet.
bool hasUnsentAvailability(WidgetRef ref, String eventId) {
  final draft = ref.read(availabilityDraftProvider(eventId));
  if (draft.isEmpty) return false;
  final slots = ref.read(slotsProvider(eventId)).value ?? const <EventSlot>[];
  return slots.any((s) => draft[s.id] != null && draft[s.id] != s.myAnswer);
}

/// Sends the answers (draft + current). Returns false on error.
Future<bool> submitAvailability(WidgetRef ref, String eventId, {required bool isOrganizer}) async {
  final slots = ref.read(slotsProvider(eventId)).value ?? const <EventSlot>[];
  final merged = mergedAnswers(slots, ref.read(availabilityDraftProvider(eventId)));
  final answers = {for (final e in merged.entries) e.key: e.value ?? SlotAnswer.maybe};
  final res = await guard(
    () async {
      await ref.read(apiProvider).submitAvailability(eventId, answers);
      return true;
    },
    success: isOrganizer
        ? tr.availabilitySaved
        : switch (rsvpFromAnswers(answers.values)) {
            Rsvp.accepted => tr.availabilitySentGoing,
            Rsvp.declined => tr.availabilitySentDeclined,
            Rsvp.pending => tr.availabilitySaved,
          },
  );
  if (res == null) return false;
  ref.read(availabilityDraftProvider(eventId).notifier).clear();
  refreshData(ref);
  return true;
}

/// Before leaving an event page with unsent answers. Returns true to leave.
Future<bool> confirmLeaveAvailability(BuildContext context, WidgetRef ref, String eventId, {required bool isOrganizer}) async {
  if (!hasUnsentAvailability(ref, eventId)) return true;
  final slots = ref.read(slotsProvider(eventId)).value ?? const <EventSlot>[];
  final merged = mergedAnswers(slots, ref.read(availabilityDraftProvider(eventId)));
  final outcome = rsvpFromAnswers(merged.values);
  final unanswered = merged.values.where((a) => a == null).length;
  final choice = await showAppSheet<bool>(
    context,
    title: tr.confirmAvailabilityTitle,
    subtitle: [
      if (unanswered > 0) tr.unansweredAsMaybe(unanswered),
      if (!isOrganizer) _outcomeText(outcome),
    ].join('\n\n'),
    builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppButton(outcome == Rsvp.declined && !isOrganizer ? tr.confirmAndDecline : tr.confirmAvailability,
          variant: outcome == Rsvp.declined && !isOrganizer ? ButtonVariant.danger : ButtonVariant.primary,
          full: true,
          onPressed: () => Navigator.pop(ctx, true)),
      const SizedBox(height: 10),
      AppButton(tr.leaveWithoutSending, variant: ButtonVariant.secondary, full: true, onPressed: () => Navigator.pop(ctx, false)),
    ]),
  );
  if (choice == null) return false; // sheet dismissed: stay
  if (!choice) {
    ref.read(availabilityDraftProvider(eventId).notifier).clear();
    return true;
  }
  return withProgress(() => submitAvailability(ref, eventId, isOrganizer: isOrganizer));
}

String _outcomeText(Rsvp r) => switch (r) {
      Rsvp.accepted => tr.outcomeGoing,
      Rsvp.declined => tr.outcomeDeclined,
      Rsvp.pending => tr.outcomeMaybe,
    };

class SlotPoll extends ConsumerStatefulWidget {
  const SlotPoll({super.key, required this.eventId, required this.isOrganizer, required this.members, this.currentRsvp});
  final String eventId;
  final bool isOrganizer;

  /// People who can vote (bar denominator).
  final int members;

  /// My RSVP as the server knows it (null for the organizer).
  final Rsvp? currentRsvp;

  @override
  ConsumerState<SlotPoll> createState() => _SlotPollState();
}

class _SlotPollState extends ConsumerState<SlotPoll> {
  String? _busy;

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
      await withProgress(() => ref.read(apiProvider).chooseSlot(s.id));
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
    final draft = ref.watch(availabilityDraftProvider(widget.eventId));
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
          final merged = mergedAnswers(slots, draft);
          final unsent = slots.any((s) => draft[s.id] != null && draft[s.id] != s.myAnswer);
          final neverSent = slots.every((s) => s.myAnswer == null);
          final outcome = rsvpFromAnswers(merged.values);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr.slotsPollHelp, style: TextStyle(color: c.textMuted, fontSize: 14, height: 1.35)),
            const SizedBox(height: 10),
            RowsCard(children: [
              for (final s in slots)
                _SlotRow(
                  slot: s,
                  mine: merged[s.id],
                  changed: draft[s.id] != null && draft[s.id] != s.myAnswer,
                  best: best.contains(s.id),
                  total: total,
                  onVote: (a) => ref.read(availabilityDraftProvider(widget.eventId).notifier).set(s.id, a),
                  onChoose: widget.isOrganizer ? () => _choose(s) : null,
                  choosing: _busy == s.id,
                ),
            ]),
            const SizedBox(height: 12),
            // My answers: what they mean, and the button to send them
            if (unsent || neverSent)
              AppCard(
                color: c.brandSoft,
                borderColor: c.isDark ? Palette.brand900 : Palette.brand200,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (!widget.isOrganizer) ...[
                    Row(children: [
                      Text(tr.yourAnswer, style: TextStyle(color: c.textMuted, fontSize: 14)),
                      const SizedBox(width: 8),
                      Pill(outcome.label, tone: rsvpToneOf(outcome)),
                    ]),
                    const SizedBox(height: 6),
                    Text(_outcomeText(outcome), style: TextStyle(fontSize: 13.5, color: c.text, height: 1.35)),
                    const SizedBox(height: 12),
                  ],
                  AppButton(
                    outcome == Rsvp.declined && !widget.isOrganizer ? tr.confirmAndDecline : tr.confirmAvailability,
                    icon: LucideIcons.send,
                    variant: outcome == Rsvp.declined && !widget.isOrganizer ? ButtonVariant.danger : ButtonVariant.primary,
                    full: true,
                    onAsync: () => submitAvailability(ref, widget.eventId, isOrganizer: widget.isOrganizer),
                  ),
                ]),
              )
            else if (!widget.isOrganizer && widget.currentRsvp != null)
              Row(children: [
                Icon(LucideIcons.circleCheck, size: 18, color: c.tone(Tone.green).text),
                const SizedBox(width: 6),
                Expanded(child: Text(tr.availabilitySent, style: TextStyle(color: c.textMuted, fontSize: 14))),
                Pill(widget.currentRsvp!.label, tone: rsvpToneOf(widget.currentRsvp!)),
              ]),
            const SizedBox(height: 12),
            _Summary(slots: slots, best: slots.where((s) => best.contains(s.id)).toList(), isOrganizer: widget.isOrganizer, onChoose: _choose),
          ]);
        },
      ),
    ]);
  }
}

Tone rsvpToneOf(Rsvp r) => switch (r) {
      Rsvp.pending => Tone.orange,
      Rsvp.accepted => Tone.green,
      Rsvp.declined => Tone.red,
    };

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.slot,
    required this.mine,
    required this.changed,
    required this.best,
    required this.total,
    required this.onVote,
    this.onChoose,
    this.choosing = false,
  });
  final EventSlot slot;
  final SlotAnswer? mine;
  final bool changed;
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
        child: Semantics(
          button: true,
          selected: on,
          label: label,
          child: InkResponse(
            onTap: () => onVote(a),
            radius: 24,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: on ? t.solid : c.secondaryFill, shape: BoxShape.circle),
              child: Icon(icon, size: 19, color: on ? Colors.white : c.textMuted),
            ),
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
              Row(children: [
                Text(formatTime(slot.startsAt), style: TextStyle(color: c.textMuted, fontSize: 14)),
                if (changed) ...[
                  const SizedBox(width: 8),
                  Text(tr.notSentYet, style: TextStyle(color: c.brandText, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ]),
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
          Text('${capitalize(formatDayTime(s.startsAt))} · ${tr.slotCounts(s.yes, s.maybe)}', style: TextStyle(color: t.fg, fontSize: 14.5)),
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
