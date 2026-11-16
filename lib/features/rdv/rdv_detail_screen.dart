// §4.10 Fiche rendez-vous.
import 'dart:io';

import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../domain/text.dart';
import '../../ui/feedback.dart';
import '../../ui/kit.dart';
import 'rsvp.dart';
import '../../ui/scaffold.dart';
import '../misc/fallback_screens.dart';
import '../photos/photo_section.dart';
import '../../maps/maps.dart';
import 'people_section.dart';
import 'status_actions.dart';
import '../events/chat.dart';
import '../events/event_widgets.dart';
import '../events/moderation.dart';
import '../events/slot_poll.dart';
import '../../core/i18n.dart';

class RdvDetailScreen extends ConsumerWidget {
  const RdvDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(rdvProvider(id));
    if (value.hasValue && value.value == null) {
      return MissingItem(title: tr.errRdvNotFound, backLabel: tr.backToHome, backPath: '/');
    }
    final rdv = value.value;
    final event = rdv?.eventId == null ? null : ref.watch(eventProvider(rdv!.eventId!)).value;
    final guardSlots = rdv != null && rdv.slotsOpen && rdv.eventId != null;

    // Unsent availability: ask before leaving (system back and the arrow).
    Future<void> leave() async {
      if (guardSlots && !await confirmLeaveAvailability(context, ref, rdv.eventId!, isOrganizer: rdv.isOrganizer)) return;
      if (context.mounted) leavePage(context);
    }

    final scaffold = AppScaffold(
      title: rdv?.displayTitle ?? tr.rdvGeneric,
      back: true,
      onBack: leave,
      actions: [
        if (rdv != null)
          AppIconButton(
            icon: LucideIcons.pencil,
            tooltip: tr.edit,
            color: context.colors.brandText,
            onPressed: () => context.push('/rdv/$id/edit'),
          ),
        if (rdv != null && event != null && rdv.isShared)
          AppIconButton(
            icon: LucideIcons.ellipsis,
            tooltip: tr.moreActions,
            onPressed: () => showModerationSheet(context, title: rdv.displayTitle, actions: [
              event.mutedEvent
                  ? ModerationAction(LucideIcons.bell, tr.unmuteEvent, () => setEventMuted(ref, event.id, false))
                  : ModerationAction(LucideIcons.bellOff, tr.muteEvent, () => setEventMuted(ref, event.id, true)),
              if (!rdv.isOrganizer)
                ...personActions(context, ref,
                    userId: event.organizerId, name: event.organizerName, muted: event.mutedOrganizer, onBlocked: () => leavePage(context)),
            ]),
          ),
      ],
      body: rdv == null
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: AsyncBody(value: value, onRetry: () => ref.invalidate(rdvProvider(id)), builder: (_) => const SizedBox()),
            )
          : _Body(rdv),
    );
    if (!guardSlots) return scaffold;
    return Consumer(builder: (context, ref, _) {
      ref.watch(availabilityDraftProvider(rdv.eventId!));
      final unsent = hasUnsentAvailability(ref, rdv.eventId!);
      return PopScope(
        canPop: !unsent,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) leave();
        },
        child: scaffold,
      );
    });
  }
}

class _Body extends ConsumerWidget {
  const _Body(this.rdv);
  final Rendezvous rdv;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmSheet(
      context,
      title: rdv.isOrganizer ? tr.deleteRdvTitle : tr.leaveEventTitle,
      message: !rdv.isOrganizer
          ? tr.leaveEventMessage
          : rdv.isShared && rdv.status == RdvStatus.planifie
              ? tr.deleteRdvOrganizerPlanned
              : rdv.isShared
                  ? tr.deleteRdvShared
                  : tr.deleteRdvPrivate,
      confirmLabel: rdv.isOrganizer ? tr.delete : tr.remove,
    );
    if (!ok || !context.mounted) return;
    final done = await guard(() async {
      await withProgress(() => ref.read(apiProvider).deleteRdv(rdv));
      return true;
    }, success: tr.rdvDeleted);
    if (done == null || !context.mounted) return;
    refreshData(ref);
    context.canPop() ? context.pop() : context.go('/');
  }

  Future<void> _addToCalendar() async {
    final names = rdv.contacts.map((c) => c.name).toList();
    await Add2Calendar.addEvent2Cal(Event(
      title: rdv.displayTitle,
      description: [
        if (names.isNotEmpty) tr.withNames(joinNames(names, max: 10)),
        ?rdv.notes,
      ].join('\n\n'),
      location: rdv.location,
      startDate: rdv.appointmentAt,
      endDate: rdv.appointmentAt.add(const Duration(hours: 1)),
      iosParams: const IOSParams(reminder: Duration(minutes: 30)),
    ));
  }

  void _openMaps(String location) {
    final q = Uri.encodeComponent(location);
    final uri = Platform.isIOS ? Uri.parse('https://maps.apple.com/?q=$q') : Uri.parse('geo:0,0?q=$q');
    launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) =>
        launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$q'), mode: LaunchMode.externalApplication));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final shared = rdv.isShared ? ref.watch(sharedRdvPhotosProvider(rdv.id)) : null;
    final photos = shared == null
        ? AsyncValue.data(rdv.photos)
        : shared.whenData((others) => [...rdv.photos, ...others]..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
    final event = rdv.eventId == null ? null : ref.watch(eventProvider(rdv.eventId!)).value;
    final public = rdv.visibility == EventVisibility.public;

    return PageList(
      onRefresh: () async {
        refreshData(ref);
        await ref.read(rdvProvider(rdv.id).future);
      },
      children: [
        const SizedBox(height: 8),
        // 0. Invitation from a friend: my answer (à confirmer / accepter / refuser)
        // (events voting on timeslots: the answer comes from the availability, below)
        if (rdv.rsvp != null && !rdv.slotsOpen) ...[_RsvpCard(rdv: rdv, event: event), const SizedBox(height: 16)],

        // 1. Amber "did it happen?" banner
        if (rdv.needsConfirmation() && !rdv.slotsOpen) ...[
          AppCard(
            color: c.tone(Tone.amber).bg,
            borderColor: c.tone(Tone.amber).bg,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(LucideIcons.circleHelp, color: c.tone(Tone.amber).text),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(tr.didItHappen,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: c.tone(Tone.amber).fg)),
                ),
              ]),
              const SizedBox(height: 12),
              RdvStatusActions(rdv: rdv),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        // 2. Main card
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              PhasePill(rdv),
              if (rdv.isTentative) ...[const SizedBox(width: 6), const TentativePill()],
              if (rdv.isShared) ...[const SizedBox(width: 6), VisibilityPill(rdv.visibility)],
              const Spacer(),
              // "Aujourd'hui" / "Demain" / "Hier" only (otherwise it repeats the date below)
              if (!rdv.slotsOpen && calendarDaysBetween(today(), rdv.appointmentAt).abs() <= 1)
                Text(relativeDayLabel(rdv.appointmentAt), style: TextStyle(color: c.textMuted, fontSize: 15)),
            ]),
            const SizedBox(height: 14),
            if (rdv.slotsOpen)
              Row(children: [
                Icon(LucideIcons.calendarClock, size: 26, color: c.tone(Tone.amber).text),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rdv.isOrganizer ? tr.dateYouSet : (event == null ? tr.dateToChoose : tr.dateConfirmedBy(event.organizerName)),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.text, height: 1.2),
                  ),
                ),
              ])
            else ...[
              Text(capitalize(formatDateLong(rdv.appointmentAt)),
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: c.text, height: 1.2)),
              const SizedBox(height: 8),
              Row(children: [
                Icon(LucideIcons.clock, size: 20, color: c.textMuted),
                const SizedBox(width: 8),
                Text(formatTime(rdv.appointmentAt), style: TextStyle(fontSize: 18, color: c.text)),
              ]),
            ],
            if (rdv.location != null) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _openMaps(rdv.location!),
                child: Row(children: [
                  Icon(LucideIcons.mapPin, size: 20, color: c.brandText),
                  const SizedBox(width: 8),
                  Expanded(child: Text(rdv.location!, style: TextStyle(fontSize: 16, color: c.brandText))),
                ]),
              ),
            ],
            if (rdv.event?.lat != null && rdv.event?.lng != null) ...[
              const SizedBox(height: 12),
              PlaceMapCard(lat: rdv.event!.lat!, lng: rdv.event!.lng!, label: rdv.location ?? rdv.displayTitle),
            ],
            if (rdv.event?.link != null) ...[
              const SizedBox(height: 8),
              EventLinkRow(rdv.event!.link!),
            ],
            if (event != null && !rdv.isOrganizer) ...[
              const SizedBox(height: 10),
              Row(children: [
                Avatar(name: event.organizerName, size: 24, userId: event.organizerId),
                const SizedBox(width: 8),
                Expanded(child: Text(tr.organizedBy(event.organizerName), style: TextStyle(fontSize: 15, color: c.text))),
              ]),
            ],
            if (rdv.event?.description != null) ...[
              const SizedBox(height: 10),
              Text(rdv.event!.description!, style: TextStyle(fontSize: 15, color: c.text, height: 1.45)),
            ],
            if (rdv.notes != null) ...[
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(LucideIcons.stickyNote, size: 18, color: c.textSubtle),
                const SizedBox(width: 8),
                Expanded(child: Text(rdv.notes!, style: TextStyle(fontSize: 15, color: c.text, height: 1.4))),
              ]),
            ],
            if (rdv.isShared && rdv.visibility == EventVisibility.private) ...[
              const SizedBox(height: 14),
              InfoBox(
                tone: Tone.brand,
                child: Text(tr.sharedRdvInfo,
                    style: const TextStyle(fontSize: 13.5)),
              ),
            ],
          ]),
        ),

        // 2b. Timeslot poll
        if (rdv.slotsOpen && rdv.eventId != null)
          SlotPoll(eventId: rdv.eventId!, isOrganizer: rdv.isOrganizer, members: rdv.event?.memberCount ?? 1, currentRsvp: rdv.rsvp),

        // 2c. Chat / announcements, right on the page
        if (rdv.isShared && rdv.eventId != null && rdv.rsvp != Rsvp.declined)
          EventChat(
            key: ValueKey('chat-${rdv.eventId}'),
            rdv: rdv,
            canPost: event?.canPost ?? (rdv.visibility != EventVisibility.public || rdv.isOrganizer),
          ),

        // 3. Everyone: SeeU members, my friends to invite, people without SeeU
        PeopleSection(rdv: rdv),

        // 5. Status + calendar
        const SizedBox(height: 20),
        if (!rdv.needsConfirmation() && !rdv.slotsOpen) RdvStatusActions(rdv: rdv),
        if (rdv.status == RdvStatus.planifie && !rdv.slotsOpen) ...[
          const SizedBox(height: 10),
          AppButton(tr.addToCalendar,
              icon: LucideIcons.calendarPlus, variant: ButtonVariant.secondary, full: true, onPressed: _addToCalendar),
        ],

        // 6. Photos
        PhotoSection(
          title: rdv.isShared ? tr.sharedPhotos : tr.photos,
          photos: photos,
          rdvId: rdv.id,
          emptyText: public && !rdv.isOrganizer
              ? tr.photosEmptyPublicMember
              : rdv.isShared
                  ? tr.photosEmptyShared
                  : tr.photosEmptyPrivate,
          canAdd: !public || rdv.isOrganizer,
        ),

        // 7. Delete (declined: nothing to remove, it's already out of the agenda)
        if (rdv.isOrganizer || rdv.rsvp != Rsvp.declined) ...[
          const SizedBox(height: 28),
          AppButton(rdv.isOrganizer ? tr.deleteRdv : tr.removeFromAgenda,
              icon: LucideIcons.trash2, variant: ButtonVariant.danger, full: true, onPressed: () => _delete(context, ref)),
        ],
      ],
    );
  }
}

class _RsvpCard extends ConsumerStatefulWidget {
  const _RsvpCard({required this.rdv, this.event});
  final Rendezvous rdv;
  final FeedEvent? event;
  @override
  ConsumerState<_RsvpCard> createState() => _RsvpCardState();
}

class _RsvpCardState extends ConsumerState<_RsvpCard> {
  Rsvp? _busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rdv = widget.rdv;
    final invite = (ref.watch(rdvInvitesProvider(rdv.id)).value ?? const <RdvInvitation>[])
        .where((i) => i.toRdvId == rdv.id)
        .firstOrNull;
    final friends = ref.watch(friendsProvider).value ?? const <Friend>[];
    final from = invite == null ? null : friends.where((f) => f.userId == invite.fromUser).firstOrNull;
    final tone = c.tone(rsvpTone(rdv.rsvp!));
    return AppCard(
      color: tone.bg,
      borderColor: tone.bg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          from != null
              ? tr.proposedBy(from.displayName)
              : widget.event != null
                  ? tr.organizedBy(widget.event!.organizerName)
                  : tr.invitedByFriend,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: tone.fg),
        ),
        const SizedBox(height: 4),
        Text(
          switch (rdv.rsvp!) {
            Rsvp.pending => tr.rsvpPendingHelp,
            Rsvp.accepted => tr.rsvpAcceptedHelp,
            Rsvp.declined => tr.rsvpDeclinedHelp,
          },
          style: TextStyle(fontSize: 14, color: tone.fg.withValues(alpha: 0.85), height: 1.35),
        ),
        const SizedBox(height: 12),
        RsvpSelector(
          value: rdv.rsvp!,
          busy: _busy,
          onChanged: invite == null && rdv.eventId == null
              ? null
              : (answer) async {
                  setState(() => _busy = answer);
                  if (invite != null) {
                    await answerInvitation(ref, invite.id, answer);
                  } else {
                    await guard(() => ref.read(apiProvider).joinEvent(rdv.eventId!, answer), success: switch (answer) {
                      Rsvp.accepted => tr.joinedToast,
                      Rsvp.pending => tr.rsvpToastPending,
                      Rsvp.declined => tr.notGoingToast,
                    });
                    refreshData(ref);
                  }
                  if (mounted) setState(() => _busy = null);
                },
        ),
      ]),
    );
  }
}
