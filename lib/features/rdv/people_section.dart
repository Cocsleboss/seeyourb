// "Participants" on the event page: one list for everyone, replacing the former
// Participants / Mes contacts / Partage sections.
//   • SeeU members (organizer, going, à confirmer): colored initials
//   • my SeeU friends among my contacts who aren't in yet: "Inviter"
//   • people without a SeeU account (mine and the other members'): grey icon
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/text.dart';
import '../../ui/feedback.dart';
import '../../ui/kit.dart';
import '../../ui/forms.dart';
import '../../domain/selectors.dart';
import '../../ui/rows.dart';
import 'rsvp.dart';

const _maxMembers = 50;

class PeopleSection extends ConsumerStatefulWidget {
  const PeopleSection({super.key, required this.rdv});
  final Rendezvous rdv;
  @override
  ConsumerState<PeopleSection> createState() => _PeopleSectionState();
}

class _PeopleSectionState extends ConsumerState<PeopleSection> {
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
    final rdv = widget.rdv;
    final eventId = rdv.eventId;
    final members = eventId == null ? null : ref.watch(participantsProvider(eventId));
    final others = eventId == null ? const <EventGuest>[] : (ref.watch(eventGuestsProvider(eventId)).value ?? const <EventGuest>[]);
    final invites = ref.watch(rdvInvitesProvider(rdv.id)).value ?? const <RdvInvitation>[];
    final contactsByUser = {
      for (final x in ref.watch(contactsProvider).value ?? const <Contact>[])
        if (x.linkedUserId != null) x.linkedUserId!: x,
    };

    if (members != null && !members.hasValue) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(tr.participants),
        AsyncBody(value: members, skeletonRows: 2, onRetry: () => ref.invalidate(participantsProvider(eventId!)), builder: (_) => const SizedBox()),
      ]);
    }
    final people = members?.value ?? const <Participant>[];
    final memberIds = people.map((p) => p.userId).toSet();
    final public = rdv.visibility == EventVisibility.public;
    final canInvite = rdv.status != RdvStatus.annule && (rdv.isOrganizer || (!public && (rdv.event?.guestsCanInvite ?? true)));

    // My SeeU friends attached to my copy but not (or no longer) in the event.
    final friendsOut = rdv.contacts.where((x) => x.linkedUserId != null && !memberIds.contains(x.linkedUserId)).toList();
    final mineOffSeeu = rdv.contacts.where((x) => x.linkedUserId == null).toList();
    final othersOffSeeu = others.where((g) => !g.isMine).toList();

    RdvInvitation? sentTo(String userId) =>
        invites.where((i) => i.rdvId == rdv.id && i.toUser == userId && i.status != InviteStatus.accepted).firstOrNull;

    final rows = <Widget>[
      for (final p in people.take(_maxMembers))
        _memberRow(c, p, contactsByUser[p.userId], sentTo(p.userId)),
      if (people.length > _maxMembers)
        Padding(
          padding: const EdgeInsets.all(14),
          child: Text(tr.andNMore(people.length - _maxMembers), textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
        ),
      for (final f in friendsOut)
        _friendOutRow(c, f, invites.where((i) => i.rdvId == rdv.id && i.toUser == f.linkedUserId).firstOrNull, canInvite),
      for (final x in mineOffSeeu)
        _PersonTile(
          avatar: Avatar(name: x.name, path: x.photoPath, size: 40, seeu: false),
          title: x.name,
          subtitle: tr.notOnSeeu,
          onTap: () => context.push('/contacts/${x.id}'),
        ),
      for (final g in othersOffSeeu)
        _PersonTile(
          avatar: Avatar(name: g.name, size: 40, seeu: false),
          title: g.name,
          subtitle: tr.notOnSeeuAddedBy(g.addedByName),
        ),
    ];

    final total = people.length + friendsOut.length + mineOffSeeu.length + othersOffSeeu.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(tr.participants, count: total),
      if (rows.isEmpty) Text(tr.noParticipants, style: TextStyle(color: c.textMuted)) else RowsCard(children: rows),
      if (mineOffSeeu.isNotEmpty || othersOffSeeu.isNotEmpty || friendsOut.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: Text(tr.peopleLegend, style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.4)),
        ),
      // Add people: my contacts (friends get invited). Only where I may invite.
      if (canInvite) ...[
        const SizedBox(height: 10),
        AppButton(tr.addPeople,
            icon: LucideIcons.userPlus,
            variant: ButtonVariant.secondary,
            full: true,
            onPressed: () => showAppSheet(context,
                title: tr.addPeople,
                subtitle: tr.addPeopleSub,
                builder: (_) => _AddPeople(rdv: rdv, exclude: {...rdv.contacts.map((x) => x.id)}, memberIds: memberIds))),
      ],
    ]);
  }

  Widget _memberRow(AppColors c, Participant p, Contact? contact, RdvInvitation? pendingInvite) {
    final rdv = widget.rdv;
    final me = p.userId == rdv.userId;
    final cancellable = pendingInvite != null && pendingInvite.status == InviteStatus.pending && pendingInvite.fromUser == rdv.userId && p.role == 'pending';
    Widget trailing;
    if (p.isOrganizer) {
      trailing = Pill(tr.organizer, tone: Tone.brand, icon: LucideIcons.crown);
    } else if (cancellable) {
      trailing = AppButton(tr.cancel,
          variant: ButtonVariant.secondary,
          size: ButtonSize.sm,
          loading: _busy == p.userId,
          onPressed: _busy == null
              ? () => _run(p.userId, () => ref.read(apiProvider).cancelRdvInvite(pendingInvite.id), tr.invitationCancelled)
              : null);
    } else if (p.role == 'pending') {
      trailing = const TentativePill();
    } else {
      trailing = Pill(tr.rsvpAccepted, tone: Tone.green);
    }
    return _PersonTile(
      avatar: FriendAvatar(name: contact?.name ?? p.name, path: contact?.photoPath, size: 40, isFriend: p.isFriend, seeu: true, userId: p.userId),
      title: me ? tr.you : (contact?.name ?? p.name),
      subtitle: cancellable ? tr.invitationPending : (p.username == null ? null : handle(p.username)),
      trailing: trailing,
      onTap: contact == null || me ? null : () => context.push('/contacts/${contact.id}'),
    );
  }

  Widget _friendOutRow(AppColors c, ContactLite f, RdvInvitation? sent, bool canInvite) {
    final rdv = widget.rdv;
    final declined = sent?.status == InviteStatus.declined;
    // Accepted earlier but no longer in the event: they left (or were removed by a block).
    final left = sent?.status == InviteStatus.accepted;
    Widget? action;
    if (canInvite) {
      action = AppButton(left ? tr.reinvite : (declined ? tr.resend : tr.inviteFriend),
          icon: LucideIcons.send,
          variant: declined || left ? ButtonVariant.secondary : ButtonVariant.primary,
          size: ButtonSize.sm,
          loading: _busy == f.id,
          onPressed: _busy == null
              ? () => _run(f.id, () => ref.read(apiProvider).sendRdvInvite(rdv.id, f.linkedUserId!), tr.invitationSentTo(f.name))
              : null);
    }
    return _PersonTile(
      avatar: FriendAvatar(name: f.name, path: f.photoPath, size: 40, isFriend: true, userId: f.linkedUserId),
      title: f.name,
      subtitle: left ? tr.leftEvent : (declined ? tr.declinedInvitation : tr.friendNotInvited),
      trailing: action,
      onTap: () => context.push('/contacts/${f.id}'),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.avatar, required this.title, this.subtitle, this.trailing, this.onTap});
  final Widget avatar;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          avatar,
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5, color: c.text)),
              if (subtitle != null)
                Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textMuted, fontSize: 13)),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ]),
      ),
    );
  }
}


class _AddPeople extends ConsumerStatefulWidget {
  const _AddPeople({required this.rdv, required this.exclude, required this.memberIds});
  final Rendezvous rdv;
  final Set<String> exclude;
  final Set<String> memberIds;
  @override
  ConsumerState<_AddPeople> createState() => _AddPeopleState();
}

class _AddPeopleState extends ConsumerState<_AddPeople> {
  final _q = TextEditingController();
  final _picked = <String>{};

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _add(List<Contact> all) async {
    final api = ref.read(apiProvider);
    final chosen = all.where((x) => _picked.contains(x.id)).toList();
    final ok = await guard(() async {
      await api.addContactsToRdv(widget.rdv.id, chosen.map((x) => x.id).toList());
      // SeeU friends among them get the invitation.
      for (final f in chosen.where((x) => x.linkedUserId != null)) {
        try {
          await api.sendRdvInvite(widget.rdv.id, f.linkedUserId!);
        } catch (_) {}
      }
      return true;
    }, success: tr.peopleAdded(chosen.length));
    if (ok == null || !mounted) return;
    refreshData(ref);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final all = (ref.watch(contactsProvider).value ?? const <Contact>[])
        .where((x) => !widget.exclude.contains(x.id) && (x.linkedUserId == null || !widget.memberIds.contains(x.linkedUserId)))
        .toList()
      ..sort((a, b) => compareNames(a.name, b.name));
    final shown = all.where((x) => contactMatches(x, _q.text)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SearchField(controller: _q, hint: tr.searchContact, onChanged: (_) => setState(() {})),
      const SizedBox(height: 6),
      ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45),
        child: shown.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: Text(all.isEmpty ? tr.allAlreadyInList : tr.noMatchingContact, textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
              )
            : ListView(shrinkWrap: true, children: [
                for (final x in shown)
                  CheckboxListTile(
                    value: _picked.contains(x.id),
                    onChanged: (_) => setState(() => _picked.contains(x.id) ? _picked.remove(x.id) : _picked.add(x.id)),
                    controlAffinity: ListTileControlAffinity.trailing,
                    activeColor: Palette.brand600,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    secondary: FriendAvatar(name: x.name, path: x.photoPath, size: 38, isFriend: x.linkedUserId != null, userId: x.linkedUserId),
                    title: Text(x.name, style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
                    subtitle: ContactKindLine(linkedUserId: x.linkedUserId, categories: x.categories),
                  ),
              ]),
      ),
      const SizedBox(height: 10),
      Text(tr.addPeopleHelp, style: TextStyle(color: c.textMuted, fontSize: 12.5, height: 1.35)),
      const SizedBox(height: 12),
      AppButton(_picked.isEmpty ? tr.addPeople : tr.addNPeople(_picked.length),
          icon: LucideIcons.check, full: true, onAsync: _picked.isEmpty ? null : () => _add(all)),
    ]);
  }
}
