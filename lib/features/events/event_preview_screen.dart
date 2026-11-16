// /event/:id — an event seen in a feed or a notification, before joining it.
// Once I'm in (going or "à confirmer"), my own copy (/rdv/:id) takes over.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ads/ads.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../domain/text.dart';
import '../../ui/feedback.dart';
import '../../ui/kit.dart';
import '../../ui/scaffold.dart';
import '../misc/fallback_screens.dart';
import '../rdv/rsvp.dart';
import '../../maps/maps.dart';
import 'event_widgets.dart';
import 'moderation.dart';

class EventPreviewScreen extends ConsumerWidget {
  const EventPreviewScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(eventProvider(id));
    if (value.hasValue && value.value == null) {
      return MissingItem(title: tr.errEventNotVisible, backLabel: tr.backToHome, backPath: '/');
    }
    final e = value.value;
    // Already in my agenda: show my copy instead.
    if (e != null && e.joined) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.pushReplacement('/rdv/${e.myRdvId}');
      });
    }
    return AppScaffold(
      title: e?.displayTitle ?? tr.rdvGeneric,
      back: true,
      actions: [
        if (e != null && !e.isMine)
          AppIconButton(
            icon: LucideIcons.ellipsis,
            tooltip: tr.moreActions,
            onPressed: () => showModerationSheet(context, title: e.displayTitle, actions: [
              e.mutedEvent
                  ? ModerationAction(LucideIcons.bell, tr.unmuteEvent, () => setEventMuted(ref, e.id, false))
                  : ModerationAction(LucideIcons.bellOff, tr.muteEvent, () => setEventMuted(ref, e.id, true)),
              ...personActions(context, ref,
                  userId: e.organizerId, name: e.organizerName, muted: e.mutedOrganizer, onBlocked: () => leavePage(context)),
            ]),
          ),
      ],
      body: e == null
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: AsyncBody(value: value, onRetry: () => ref.invalidate(eventProvider(id)), builder: (_) => const SizedBox()),
            )
          : _Preview(event: e),
    );
  }
}

class _Preview extends ConsumerStatefulWidget {
  const _Preview({required this.event});
  final FeedEvent event;
  @override
  ConsumerState<_Preview> createState() => _PreviewState();
}

class _PreviewState extends ConsumerState<_Preview> {
  Rsvp? _busy;

  Future<void> _answer(Rsvp answer) async {
    setState(() => _busy = answer);
    final id = await guard(() => ref.read(apiProvider).joinEvent(widget.event.id, answer),
        success: switch (answer) {
          Rsvp.accepted => tr.joinedToast,
          Rsvp.pending => tr.rsvpToastPending,
          Rsvp.declined => tr.notGoingToast,
        });
    if (!mounted) return;
    setState(() => _busy = null);
    refreshData(ref);
    if (id != null && answer != Rsvp.declined) context.pushReplacement('/rdv/$id');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final e = widget.event;
    return PageList(
      onRefresh: () => ref.refresh(eventProvider(e.id).future),
      children: [
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              VisibilityPill(e.visibility),
              if (e.status == RdvStatus.annule) StatusPill(e.status),
            ]),
            const SizedBox(height: 14),
            Text(e.displayTitle, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: c.text, height: 1.2)),
            const SizedBox(height: 10),
            Row(children: [
              Icon(e.slotsOpen ? LucideIcons.calendarClock : LucideIcons.calendar, size: 20, color: c.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(e.slotsOpen ? tr.dateConfirmedBy(e.organizerName) : capitalize(formatDayTime(e.appointmentAt)),
                    style: TextStyle(fontSize: 16, color: c.text)),
              ),
            ]),
            if (e.location != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(LucideIcons.mapPin, size: 20, color: c.textMuted),
                const SizedBox(width: 8),
                Expanded(child: Text(e.location!, style: TextStyle(fontSize: 16, color: c.text))),
              ]),
            ],
            if (e.lat != null && e.lng != null) ...[
              const SizedBox(height: 12),
              PlaceMapCard(lat: e.lat!, lng: e.lng!, label: e.location ?? e.displayTitle),
            ],
            if (e.link != null) ...[
              const SizedBox(height: 8),
              EventLinkRow(e.link!),
            ],
            const SizedBox(height: 14),
            Row(children: [
              Avatar(name: e.organizerName, size: 36, userId: e.organizerId),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr.organizedBy(e.organizerName), style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
                  if (e.organizerUsername != null) Text(handle(e.organizerUsername), style: TextStyle(color: c.textMuted, fontSize: 13.5)),
                ]),
              ),
              Pill(tr.nGoing(e.going), icon: LucideIcons.users),
            ]),
            if (e.description != null) ...[
              const SizedBox(height: 14),
              Text(e.description!, style: TextStyle(fontSize: 15, color: c.text, height: 1.45)),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        if (e.status == RdvStatus.annule)
          InfoBox(tone: Tone.red, child: Text(tr.eventCancelledInfo))
        else ...[
          Text(e.slotsOpen ? tr.joinToVote : tr.areYouComing, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: c.text)),
          const SizedBox(height: 10),
          // Several timeslots: no yes/no here, the answer comes from the availability.
          if (e.slotsOpen)
            AppButton(tr.giveAvailability,
                icon: LucideIcons.calendarClock, full: true, size: ButtonSize.lg, loading: _busy != null, onPressed: () => _answer(Rsvp.pending))
          else
            RsvpSelector(value: e.myRsvp, busy: _busy, onChanged: _answer),
          const SizedBox(height: 8),
          Text(e.visibility == EventVisibility.public ? tr.joinPublicHint : tr.joinFriendsHint,
              style: TextStyle(fontSize: 13, color: c.textMuted, height: 1.35)),
        ],
        if (e.visibility == EventVisibility.public) const AdTile(AdPlacement.publicEvent, padding: EdgeInsets.only(top: 24)),
      ],
    );
  }
}
