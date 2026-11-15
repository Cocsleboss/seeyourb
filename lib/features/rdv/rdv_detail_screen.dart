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
import 'status_actions.dart';
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
    return AppScaffold(
      title: rdv?.displayTitle ?? tr.rdvGeneric,
      back: true,
      actions: [
        if (rdv != null)
          AppIconButton(
            icon: LucideIcons.pencil,
            tooltip: tr.edit,
            color: context.colors.brandText,
            onPressed: () => context.push('/rdv/$id/edit'),
          ),
      ],
      body: rdv == null
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: AsyncBody(value: value, onRetry: () => ref.invalidate(rdvProvider(id)), builder: (_) => const SizedBox()),
            )
          : _Body(rdv),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body(this.rdv);
  final Rendezvous rdv;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmSheet(
      context,
      title: tr.deleteRdvTitle,
      message: rdv.isShared
          ? tr.deleteRdvShared
          : tr.deleteRdvPrivate,
      confirmLabel: tr.delete,
    );
    if (!ok || !context.mounted) return;
    final done = await guard(() async {
      await ref.read(apiProvider).deleteRdv(rdv);
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
    final friendContacts = rdv.contacts.where((p) => p.linkedUserId != null).toList();

    return PageList(
      onRefresh: () async {
        refreshData(ref);
        await ref.read(rdvProvider(rdv.id).future);
      },
      children: [
        const SizedBox(height: 8),
        // 0. Invitation from a friend: my answer (à confirmer / accepter / refuser)
        if (rdv.rsvp != null) ...[_RsvpCard(rdv: rdv), const SizedBox(height: 16)],

        // 1. Amber "did it happen?" banner
        if (rdv.needsConfirmation()) ...[
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
              StatusPill(rdv.status),
              if (rdv.isTentative) ...[const SizedBox(width: 6), const TentativePill()],
              const Spacer(),
              // "Aujourd'hui" / "Demain" / "Hier" only (otherwise it repeats the date below)
              if (calendarDaysBetween(today(), rdv.appointmentAt).abs() <= 1)
                Text(relativeDayLabel(rdv.appointmentAt), style: TextStyle(color: c.textMuted, fontSize: 15)),
            ]),
            const SizedBox(height: 14),
            Text(capitalize(formatDateLong(rdv.appointmentAt)),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: c.text, height: 1.2)),
            const SizedBox(height: 8),
            Row(children: [
              Icon(LucideIcons.clock, size: 20, color: c.textMuted),
              const SizedBox(width: 8),
              Text(formatTime(rdv.appointmentAt), style: TextStyle(fontSize: 18, color: c.text)),
            ]),
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
            if (rdv.notes != null) ...[
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(LucideIcons.stickyNote, size: 18, color: c.textSubtle),
                const SizedBox(width: 8),
                Expanded(child: Text(rdv.notes!, style: TextStyle(fontSize: 15, color: c.text, height: 1.4))),
              ]),
            ],
            if (rdv.isShared) ...[
              const SizedBox(height: 14),
              InfoBox(
                tone: Tone.brand,
                child: Text(tr.sharedRdvInfo,
                    style: const TextStyle(fontSize: 13.5)),
              ),
            ],
          ]),
        ),

        // 3. Participants
        SectionTitle(tr.participants),
        if (rdv.contacts.isEmpty)
          Text(tr.noParticipants, style: TextStyle(color: c.textMuted))
        else
          RowsCard(children: [
            for (final p in rdv.contacts)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Avatar(name: p.name, path: p.photoPath, size: 46),
                title: Text(p.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5, color: c.text)),
                subtitle: p.categoryLabel == null ? null : Text(p.categoryLabel!, style: TextStyle(color: c.textMuted)),
                trailing: Icon(LucideIcons.chevronRight, color: c.textMuted),
                onTap: () => context.push('/contacts/${p.id}'),
              ),
          ]),

        // 4. Sharing
        if (friendContacts.isNotEmpty) _ShareSection(rdv: rdv, friends: friendContacts),

        // 5. Status + calendar
        const SizedBox(height: 20),
        if (!rdv.needsConfirmation()) RdvStatusActions(rdv: rdv),
        if (rdv.status == RdvStatus.planifie) ...[
          const SizedBox(height: 10),
          AppButton(tr.addToCalendar,
              icon: LucideIcons.calendarPlus, variant: ButtonVariant.secondary, full: true, onPressed: _addToCalendar),
        ],

        // 6. Photos
        PhotoSection(
          title: rdv.isShared ? tr.sharedPhotos : tr.photos,
          photos: photos,
          rdvId: rdv.id,
          emptyText: rdv.isShared ? tr.photosEmptyShared : tr.photosEmptyPrivate,
        ),

        // 7. Delete
        const SizedBox(height: 28),
        AppButton(tr.deleteRdv,
            icon: LucideIcons.trash2, variant: ButtonVariant.danger, full: true, onPressed: () => _delete(context, ref)),
      ],
    );
  }
}

class _RsvpCard extends ConsumerStatefulWidget {
  const _RsvpCard({required this.rdv});
  final Rendezvous rdv;
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
          from == null ? tr.invitedByFriend : tr.proposedBy(from.displayName),
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
          onChanged: invite == null
              ? null
              : (answer) async {
                  setState(() => _busy = answer);
                  await answerInvitation(ref, invite.id, answer);
                  if (mounted) setState(() => _busy = null);
                },
        ),
      ]),
    );
  }
}

class _ShareSection extends ConsumerStatefulWidget {
  const _ShareSection({required this.rdv, required this.friends});
  final Rendezvous rdv;
  final List<ContactLite> friends;
  @override
  ConsumerState<_ShareSection> createState() => _ShareSectionState();
}

class _ShareSectionState extends ConsumerState<_ShareSection> {
  String? _busy;

  Future<void> _run(String key, Future<void> Function() action, String success) async {
    setState(() => _busy = key);
    final ok = await guard(() async {
      await action();
      return true;
    }, success: success);
    if (!mounted) return;
    setState(() => _busy = null);
    if (ok != null) refreshData(ref);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final invites = ref.watch(rdvInvitesProvider(widget.rdv.id));
    final rdv = widget.rdv;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(tr.sharing),
      AsyncBody(
        value: invites,
        skeletonRows: 1,
        onRetry: () => ref.invalidate(rdvInvitesProvider(rdv.id)),
        builder: (list) => RowsCard(children: [
          for (final f in widget.friends) _row(c, f, list),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
        child: Text(
          tr.sharingHelp,
          style: TextStyle(color: c.textMuted, fontSize: 14, height: 1.4),
        ),
      ),
    ]);
  }

  Widget _row(AppColors c, ContactLite f, List<RdvInvitation> invites) {
    final rdv = widget.rdv;
    RdvInvitation? sent;
    RdvInvitation? received;
    for (final i in invites) {
      if (i.rdvId == rdv.id && i.toUser == f.linkedUserId) sent = i;
      if (i.toRdvId == rdv.id && i.fromUser == f.linkedUserId) received = i;
    }
    String text;
    Widget? action;
    if (received != null) {
      text = tr.proposedThisRdv;
    } else if (sent == null) {
      text = tr.friendNotInvited;
      if (rdv.status != RdvStatus.annule) {
        action = AppButton(tr.send,
            icon: LucideIcons.send,
            size: ButtonSize.sm,
            loading: _busy == f.id,
            onPressed: _busy == null
                ? () => _run(f.id, () => ref.read(apiProvider).sendRdvInvite(rdv.id, f.linkedUserId!), tr.invitationSentTo(f.name))
                : null);
      }
    } else {
      final invite = sent;
      switch (invite.status) {
        case InviteStatus.pending:
          text = tr.invitationPending;
          action = AppButton(tr.cancel,
              variant: ButtonVariant.secondary,
              size: ButtonSize.sm,
              loading: _busy == f.id,
              onPressed: _busy == null ? () => _run(f.id, () => ref.read(apiProvider).cancelRdvInvite(invite.id), tr.invitationCancelled) : null);
        case InviteStatus.accepted:
          text = tr.acceptedShared;
        case InviteStatus.declined:
          text = tr.declinedInvitation;
          if (rdv.status != RdvStatus.annule) {
            action = AppButton(tr.resend,
                icon: LucideIcons.send,
                variant: ButtonVariant.secondary,
                size: ButtonSize.sm,
                loading: _busy == f.id,
                onPressed: _busy == null
                    ? () => _run(f.id, () => ref.read(apiProvider).sendRdvInvite(rdv.id, f.linkedUserId!), tr.invitationSentTo(f.name))
                    : null);
          }
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Avatar(name: f.name, path: f.photoPath, size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5, color: c.text)),
            const SizedBox(height: 2),
            Text(text, style: TextStyle(color: c.textMuted, fontSize: 14)),
          ]),
        ),
        if (action != null) ...[const SizedBox(width: 8), action],
      ]),
    );
  }
}
