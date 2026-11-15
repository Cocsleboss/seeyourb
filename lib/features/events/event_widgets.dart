// Small event widgets shared by the feeds, the agenda and the event pages.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../ui/kit.dart';
import '../../ui/rows.dart';

IconData visibilityIcon(EventVisibility v) => switch (v) {
      EventVisibility.private => LucideIcons.lock,
      EventVisibility.contacts => LucideIcons.usersRound,
      EventVisibility.public => LucideIcons.globe,
    };

Tone visibilityTone(EventVisibility v) => switch (v) {
      EventVisibility.private => Tone.gray,
      EventVisibility.contacts => Tone.violet,
      EventVisibility.public => Tone.brand,
    };

class VisibilityPill extends StatelessWidget {
  const VisibilityPill(this.visibility, {super.key});
  final EventVisibility visibility;
  @override
  Widget build(BuildContext context) =>
      Pill(visibility.label, tone: visibilityTone(visibility), icon: visibilityIcon(visibility));
}

/// Date block, or a "?" block while the timeslots are being voted.
class EventDateBlock extends StatelessWidget {
  const EventDateBlock({super.key, required this.at, this.slotsOpen = false});
  final DateTime at;
  final bool slotsOpen;
  @override
  Widget build(BuildContext context) {
    if (!slotsOpen) return DateBlock(at);
    final c = context.colors;
    final t = c.tone(Tone.amber);
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(14)),
      child: Icon(LucideIcons.calendarClock, color: t.fg, size: 26),
    );
  }
}

/// Feed card: date, title, organizer, place, how many are going, my answer.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event});
  final FeedEvent event;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final e = event;
    final when = e.slotsOpen ? tr.dateToChoose : '${relativeDayLabel(e.appointmentAt)} · ${formatTime(e.appointmentAt)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: () => context.push(e.joined ? '/rdv/${e.myRdvId}' : '/event/${e.id}'),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          EventDateBlock(at: e.appointmentAt, slotsOpen: e.slotsOpen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.displayTitle,
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: c.text)),
              const SizedBox(height: 3),
              Text(when, style: TextStyle(fontSize: 14, color: c.textMuted)),
              if (e.location != null) ...[
                const SizedBox(height: 2),
                Row(children: [
                  Icon(LucideIcons.mapPin, size: 14, color: c.textMuted),
                  const SizedBox(width: 4),
                  Expanded(child: Text(e.location!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: c.textMuted))),
                ]),
              ],
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (e.isMine)
                  const OwnerPill(mine: true, long: true)
                else
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Avatar(name: e.organizerName, size: 22),
                    const SizedBox(width: 6),
                    Text(e.organizerName, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.text)),
                  ]),
                Pill(tr.nGoing(e.going), icon: LucideIcons.users),
                if (e.joined && !e.isMine)
                  e.myRsvp == Rsvp.pending
                      ? Pill(tr.rsvpPending, tone: Tone.orange)
                      : Pill(tr.youreGoing, tone: Tone.green, icon: LucideIcons.check),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
