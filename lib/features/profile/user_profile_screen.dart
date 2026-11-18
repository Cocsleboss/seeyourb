// /u/:username — a SeeU user's page (opened from a shared link, a participant
// list, a search…): only what they let me see, "Ajouter en ami" / "Ajouter à
// mes contacts" right here, their upcoming events, report / block.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../domain/text.dart';
import '../../ui/feedback.dart';
import '../../ui/kit.dart';
import '../../ui/rows.dart';
import '../../ui/scaffold.dart';
import '../contacts/contact_form_screen.dart';
import '../contacts/link_friend_field.dart';
import '../events/event_widgets.dart';
import '../events/moderation.dart';
import '../friends/friend_sheets.dart';
import 'share_profile.dart';

class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key, required this.username});
  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(userProfileProvider(username));
    final p = value.value;
    final mutes = p == null || p.isMe ? null : ref.watch(mutesProvider).value;
    return AppScaffold(
      title: p?.displayName ?? tr.userProfileTitle,
      back: true,
      actions: [
        if (p != null && !p.isMe)
          AppIconButton(
            icon: LucideIcons.ellipsis,
            tooltip: tr.moreActions,
            onPressed: () => showModerationSheet(context,
                title: p.displayName,
                actions: personActions(context, ref,
                    userId: p.userId,
                    name: p.displayName,
                    muted: (mutes ?? const <MuteEntry>[]).any((m) => m.targetUser == p.userId),
                    onBlocked: () => leavePage(context))),
          ),
      ],
      body: value.hasValue && p == null
          ? EmptyState(
              icon: LucideIcons.userX,
              title: tr.profileNotFound,
              message: tr.profileNotFoundMessage,
              actions: [AppButton(tr.backHome, onPressed: () => context.go('/'))],
            )
          : p == null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: AsyncBody(value: value, onRetry: () => ref.invalidate(userProfileProvider(username)), builder: (_) => const SizedBox()),
                )
              : _Body(profile: p),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.profile});
  final UserProfile profile;
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
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

  void _addToContacts() {
    final p = widget.profile;
    final friends = p.relation == ProfileRelation.friends;
    context.push('/contacts/new',
        extra: ContactPrefill(
          name: p.displayName,
          linkedUserId: friends ? p.userId : null,
          linkedUsername: friends ? p.username : null,
          city: p.city,
          country: p.country,
          // not friends yet: the request goes with the new card (linked on accept)
          request: friends || p.relation == ProfileRelation.sent
              ? null
              : FriendLinkChoice(
                  userId: p.userId,
                  name: p.displayName,
                  username: p.username,
                  isFriend: false,
                  relation: p.relation == ProfileRelation.received ? UserRelation.received : UserRelation.none),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = widget.profile;
    final api = ref.read(apiProvider);
    final busy = _busy != null;

    final actions = <Widget>[
      switch (p.relation) {
        ProfileRelation.self => AppButton(tr.shareMyProfile, icon: LucideIcons.share2, full: true, size: ButtonSize.lg, onPressed: () => shareProfile(p.username, public: p.publicProfile)),
        ProfileRelation.none => AppButton(tr.addAsFriend,
            icon: LucideIcons.userPlus,
            full: true,
            size: ButtonSize.lg,
            loading: _busy == 'add',
            onPressed: busy ? null : () => _run('add', () => api.sendFriendRequest(p.username), tr.requestSentTo(p.displayName))),
        ProfileRelation.sent => AppButton(tr.requestSentButton, icon: LucideIcons.hourglass, full: true, size: ButtonSize.lg, variant: ButtonVariant.secondary),
        ProfileRelation.received => AppButton(tr.acceptRequest,
            icon: LucideIcons.userCheck,
            full: true,
            size: ButtonSize.lg,
            loading: _busy == 'accept',
            onPressed: busy
                ? null
                : () async {
                    await _run('accept', () => api.respondFriendRequest(p.friendshipId!, true), tr.nowFriendsWith(p.displayName));
                    if (mounted && p.contactId == null) await offerLinkAfterAccept(this.context, p.userId);
                  }),
        ProfileRelation.friends => AppButton(tr.wantToMeet,
            icon: LucideIcons.hand,
            full: true,
            size: ButtonSize.lg,
            loading: _busy == 'wave',
            onPressed: busy ? null : () => _run('wave', () => api.sendWave(p.userId), tr.wantToMeetSent(p.displayName))),
      },
      if (p.relation == ProfileRelation.sent && p.friendshipId != null) ...[
        const SizedBox(height: 10),
        AppButton(tr.cancelRequest,
            icon: LucideIcons.x,
            variant: ButtonVariant.ghost,
            full: true,
            loading: _busy == 'cancel',
            onPressed: busy ? null : () => _run('cancel', () => api.removeFriend(p.friendshipId!), tr.requestCancelled)),
      ],
      // Not friends yet: only "add as SeeU friend" (no contact card for a stranger).
      if (!p.isMe && (p.contactId != null || p.relation == ProfileRelation.friends)) ...[
        const SizedBox(height: 10),
        if (p.contactId != null)
          AppButton(tr.seeContactCard,
              icon: LucideIcons.bookUser, variant: ButtonVariant.secondary, full: true, onPressed: () => context.push('/contacts/${p.contactId}'))
        else
          AppButton(tr.addToMyContacts, icon: LucideIcons.contactRound, variant: ButtonVariant.secondary, full: true, onPressed: _addToContacts),
      ],
      if (p.isMe) ...[
        const SizedBox(height: 10),
        AppButton(tr.editMyProfile,
            icon: LucideIcons.pencil, variant: ButtonVariant.secondary, full: true, onPressed: () => context.push('/settings/public-profile')),
      ],
    ];

    return PageList(
      onRefresh: () => ref.refresh(userProfileProvider(p.username).future),
      children: [
        const SizedBox(height: 12),
        Center(child: Avatar(name: p.displayName, size: 100, userId: p.userId)),
        const SizedBox(height: 12),
        Text(p.displayName, textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: c.text)),
        const SizedBox(height: 2),
        Text(handle(p.username), textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: c.textMuted)),
        if (p.cityLabel != null || p.relation == ProfileRelation.friends || p.mutualFriends > 0) ...[
          const SizedBox(height: 10),
          Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
            if (p.cityLabel != null) Pill(tr.livesIn(p.cityLabel!), icon: LucideIcons.mapPin),
            if (p.relation == ProfileRelation.friends) Pill(tr.alreadyFriends, tone: Tone.brand, icon: LucideIcons.users),
            if (p.mutualFriends > 0) Pill(tr.mutualFriends(p.mutualFriends), icon: LucideIcons.usersRound),
          ]),
        ],
        if (p.bio != null) ...[
          const SizedBox(height: 14),
          Text(p.bio!, textAlign: TextAlign.center, style: TextStyle(fontSize: 15.5, color: c.text, height: 1.45)),
        ],
        if (p.isMe) ...[
          const SizedBox(height: 14),
          InfoBox(child: Text(tr.thisIsYou, style: const TextStyle(fontSize: 13.5))),
        ],
        const SizedBox(height: 20),
        ...actions,
        SectionTitle(tr.theirEvents, count: p.events.isEmpty ? null : p.events.length),
        if (p.events.isEmpty)
          Text(tr.noVisibleEvents, style: TextStyle(color: c.textMuted, fontSize: 14.5))
        else
          RowsCard(children: [for (final e in p.events) _EventRow(e)]),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow(this.e);
  final ProfileEvent e;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final when = e.slotsOpen ? tr.dateToChoose : '${capitalize(formatDate(e.startsAt))} · ${formatTime(e.startsAt)}';
    return InkWell(
      onTap: () => context.push(e.path),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          DateBlock(e.startsAt),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: c.text)),
              const SizedBox(height: 2),
              Text([when, ?e.location].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textMuted, fontSize: 13.5)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                VisibilityPill(e.visibility),
                Pill(e.isOrganizer ? tr.roleOrganizer : tr.roleGoing, icon: e.isOrganizer ? LucideIcons.crown : LucideIcons.check),
              ]),
            ]),
          ),
          Icon(LucideIcons.chevronRight, color: c.textMuted),
        ]),
      ),
    );
  }
}
