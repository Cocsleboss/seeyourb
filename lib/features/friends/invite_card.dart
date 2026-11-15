// Incoming rendezvous invitation card (Home + Friends).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../ui/kit.dart';
import '../rdv/rsvp.dart';
import '../../core/i18n.dart';

class InviteCard extends ConsumerStatefulWidget {
  const InviteCard({super.key, required this.invite});
  final IncomingInvite invite;
  @override
  ConsumerState<InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends ConsumerState<InviteCard> {
  Rsvp? _busy;

  Future<void> _answer(Rsvp answer) async {
    setState(() => _busy = answer);
    final copy = await answerInvitation(ref, widget.invite.id, answer);
    if (!mounted) return;
    setState(() => _busy = null);
    if (answer == Rsvp.accepted && copy != null) context.push('/rdv/$copy');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final i = widget.invite;
    final past = i.rdvStatus == RdvStatus.valide;
    // My tentative copy tells whether the organizer proposed several timeslots.
    final copy = (ref.watch(plannedRdvProvider).value ?? const <Rendezvous>[]).where((r) => r.id == i.toRdvId).firstOrNull;
    final slots = copy?.slotsOpen ?? false;
    return AppCard(
      padding: const EdgeInsets.all(18),
      onTap: i.toRdvId == null ? null : () => context.push('/rdv/${i.toRdvId}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar(name: i.fromName, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                past ? tr.inviteSharesMeetup(i.fromName) : tr.inviteProposes(i.fromName),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.text, height: 1.3),
              ),
              if (i.title != null) ...[
                const SizedBox(height: 4),
                Text(i.title!, style: TextStyle(fontSize: 15.5, color: c.text)),
              ],
              const SizedBox(height: 3),
              Row(children: [
                if (slots) ...[Icon(LucideIcons.calendarClock, size: 16, color: c.tone(Tone.amber).text), const SizedBox(width: 4)],
                Expanded(
                  child: Text(slots ? tr.severalSlotsProposed : formatDayTime(i.appointmentAt),
                      style: TextStyle(fontSize: 15, color: slots ? c.tone(Tone.amber).text : c.textMuted, fontWeight: slots ? FontWeight.w600 : null)),
                ),
              ]),
              if (i.location != null) ...[
                const SizedBox(height: 3),
                Row(children: [
                  Icon(LucideIcons.mapPin, size: 16, color: c.textMuted),
                  const SizedBox(width: 4),
                  Expanded(child: Text(i.location!, style: TextStyle(fontSize: 15, color: c.textMuted))),
                ]),
              ],
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        if (slots)
          AppButton(tr.giveAvailability,
              icon: LucideIcons.calendarClock, full: true, onPressed: i.toRdvId == null ? null : () => context.push('/rdv/${i.toRdvId}'))
        else
          RsvpSelector(value: Rsvp.pending, busy: _busy, onChanged: _answer),
        const SizedBox(height: 8),
        Text(
          slots ? tr.slotsInviteHint : tr.inviteTentativeHint,
          style: TextStyle(fontSize: 12.5, color: c.textMuted),
        ),
      ]),
    );
  }
}
