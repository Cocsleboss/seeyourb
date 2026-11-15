// Contacts tab — one list of people: my contacts (private cards) and my SeeU friends.
// A contact linked to a friend shows a SeeU badge; a friend without a card shows up
// in "Amis SeeU sans fiche" until it is associated or created.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/selectors.dart';
import '../../domain/text.dart';
import '../../ui/feedback.dart';
import '../../ui/forms.dart';
import '../../ui/kit.dart';
import '../../ui/rows.dart';
import '../../ui/scaffold.dart';
import '../friends/add_friend_sheet.dart';
import '../friends/friend_sheets.dart';
import '../friends/invite_card.dart';
import '../../core/i18n.dart';

enum _Sort { due, name }

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key, this.friendQuery});

  /// From a shared link "Ajoute-moi sur SeeU": opens the add-friend sheet prefilled.
  final String? friendQuery;

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _q = TextEditingController();
  String? _category;
  _Sort _sort = _Sort.due;
  String? _busy;

  @override
  void initState() {
    super.initState();
    _openFromLink(widget.friendQuery);
  }

  @override
  void didUpdateWidget(ContactsScreen old) {
    super.didUpdateWidget(old);
    if (widget.friendQuery != old.friendQuery) _openFromLink(widget.friendQuery);
  }

  void _openFromLink(String? q) {
    if (q == null || q.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showAddFriendSheet(context, initialQuery: q);
    });
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _respond(Friend f, bool accept) async {
    setState(() => _busy = f.friendshipId);
    final ok = await guard(() async {
      await ref.read(apiProvider).respondFriendRequest(f.friendshipId, accept);
      return true;
    }, success: accept ? tr.nowFriendsWith(f.displayName) : tr.requestDeclined);
    if (!mounted) return;
    setState(() => _busy = null);
    if (ok == null) return;
    refreshData(ref);
    if (accept) await offerLinkAfterAccept(context, f.userId);
  }

  Future<void> _cancel(Friend f) async {
    setState(() => _busy = f.friendshipId);
    final ok = await guard(() async {
      await ref.read(apiProvider).removeFriend(f.friendshipId);
      return true;
    }, success: tr.requestCancelled);
    if (!mounted) return;
    setState(() => _busy = null);
    if (ok != null) refreshData(ref);
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsProvider);
    return AppScaffold(
      title: tr.contactsTitle,
      actions: [
        AppIconButton(icon: LucideIcons.bookUser, tooltip: tr.importContacts, onPressed: () => context.push('/contacts/import')),
      ],
      body: AsyncBody(
        value: contacts,
        onRetry: () => ref.invalidate(contactsProvider),
        builder: _content,
      ),
    );
  }

  Widget _content(List<Contact> all) {
    final c = context.colors;
    final friends = ref.watch(friendsProvider).value ?? const <Friend>[];
    final invites = ref.watch(incomingInvitesProvider).value ?? const <IncomingInvite>[];
    final received = friends.where((f) => !f.accepted && f.incoming).toList();
    final sent = friends.where((f) => !f.accepted && !f.incoming).toList();
    final unlinked = friends.where((f) => f.accepted && linkedContactOf(all, f.userId) == null).toList()
      ..sort((a, b) => compareNames(a.displayName, b.displayName));
    final friendByUser = {for (final f in friends.where((f) => f.accepted)) f.userId: f};

    final categories = usedCategories(all);
    final filtered = all.where((x) => (_category == null || x.categories.contains(_category)) && contactMatches(x, _q.text)).toList();
    final unlinkedShown = _category != null ? const <Friend>[] : unlinked.where((f) => matchesAny([f.displayName, f.username], _q.text)).toList();
    final overdue = overdueCount(all);
    final nothingAtAll = all.isEmpty && friends.isEmpty;

    Widget row(Contact x) => ContactRow(contact: x, friend: x.linkedUserId == null ? null : friendByUser[x.linkedUserId]);

    final sections = <Widget>[];
    if (unlinkedShown.isNotEmpty) {
      sections
        ..add(SectionTitle(tr.friendsWithoutCard, count: unlinkedShown.length, padding: const EdgeInsets.only(top: 18, bottom: 8)))
        ..add(RowsCard(children: [for (final f in unlinkedShown) _UnlinkedFriendRow(friend: f)]));
    }
    if (filtered.isEmpty && unlinkedShown.isEmpty && !nothingAtAll) {
      sections.add(EmptyState(icon: LucideIcons.searchX, title: tr.noResults, message: tr.tryAnotherSearch));
    } else if (_sort == _Sort.name) {
      final sorted = [...filtered]..sort((a, b) => compareNames(a.name, b.name));
      if (sorted.isNotEmpty) {
        sections
          ..add(const SizedBox(height: 14))
          ..add(RowsCard(children: [for (final x in sorted) row(x)]));
      }
    } else {
      final g = groupByDue(filtered);
      for (final (title, list) in [(tr.groupOverdue, g.overdue), (tr.groupThisWeek, g.thisWeek), (tr.groupUpToDate, g.upToDate)]) {
        if (list.isEmpty) continue;
        sections
          ..add(SectionTitle(title, count: list.length, padding: const EdgeInsets.only(top: 18, bottom: 8)))
          ..add(RowsCard(children: [for (final x in list) row(x)]));
      }
    }

    return RefreshIndicator(
      onRefresh: () async {
        refreshData(ref);
        await ref.read(contactsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32, top: 12),
        children: [
          // Add people
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: AppButton(tr.addSeeuFriend,
                    icon: LucideIcons.heartHandshake, variant: ButtonVariant.secondary, full: true, onPressed: () => showAddFriendSheet(context)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(tr.addContact, icon: LucideIcons.userPlus, full: true, onPressed: () => context.push('/contacts/new')),
              ),
            ]),
          ),

          // Social activity waiting for me
          if (invites.isNotEmpty || received.isNotEmpty || sent.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (invites.isNotEmpty) ...[
                  SectionTitle(tr.rdvInvitations),
                  for (final i in invites) Padding(padding: const EdgeInsets.only(bottom: 10), child: InviteCard(invite: i)),
                ],
                if (received.isNotEmpty) ...[
                  SectionTitle(tr.friendRequestsReceived),
                  RowsCard(children: [
                    for (final f in received)
                      _PersonRow(
                        name: f.displayName,
                        subtitle: '${handle(f.username)} · ${tr.sentYouARequest}',
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          AppButton(tr.rsvpDecline,
                              variant: ButtonVariant.secondary, size: ButtonSize.sm, onPressed: _busy == null ? () => _respond(f, false) : null),
                          const SizedBox(width: 6),
                          AppButton(tr.rsvpAccept,
                              size: ButtonSize.sm, loading: _busy == f.friendshipId, onPressed: _busy == null ? () => _respond(f, true) : null),
                        ]),
                      ),
                  ]),
                ],
                if (sent.isNotEmpty) ...[
                  SectionTitle(tr.friendRequestsSent),
                  RowsCard(children: [
                    for (final f in sent)
                      _PersonRow(
                        name: f.displayName,
                        subtitle: '${handle(f.username)} · ${tr.waitingForAnswer}',
                        trailing: AppButton(tr.cancel,
                            variant: ButtonVariant.secondary,
                            size: ButtonSize.sm,
                            loading: _busy == f.friendshipId,
                            onPressed: _busy == null ? () => _cancel(f) : null),
                      ),
                  ]),
                ],
              ]),
            ),

          if (nothingAtAll)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: EmptyState(
                icon: LucideIcons.users,
                title: tr.noContactsTitle,
                message:
                    tr.noContactsMessage,
                actions: [
                  AppButton(tr.importFromPhone,
                      icon: LucideIcons.bookUser, variant: ButtonVariant.secondary, onPressed: () => context.push('/contacts/import')),
                ],
              ),
            )
          else ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SearchField(controller: _q, hint: tr.contactsSearchHint, onChanged: (_) => setState(() {})),
            ),
            const SizedBox(height: 12),
            if (categories.isNotEmpty)
              ChipRow(children: [
                AppChip(tr.filterAll, selected: _category == null, onTap: () => setState(() => _category = null)),
                for (final cat in categories)
                  AppChip(cat, selected: _category == cat, onTap: () => setState(() => _category = _category == cat ? null : cat)),
              ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: tr.nContacts(all.length)),
                      if (friendByUser.isNotEmpty) TextSpan(text: ' · ${tr.nFriends(friendByUser.length)}'),
                      if (overdue > 0) ...[
                        const TextSpan(text: ' · '),
                        TextSpan(text: tr.nOverdue(overdue), style: TextStyle(color: c.tone(Tone.red).text, fontWeight: FontWeight.w600)),
                      ],
                    ]),
                    style: TextStyle(color: c.textMuted, fontSize: 14.5),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: SegmentedControl<_Sort>(
                    options: [(_Sort.due, tr.sortDue), (_Sort.name, tr.sortName)],
                    value: _sort,
                    onChanged: (s) => setState(() => _sort = s),
                  ),
                ),
              ]),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0), child: Column(children: sections)),
          ],
        ],
      ),
    );
  }
}

class _UnlinkedFriendRow extends StatelessWidget {
  const _UnlinkedFriendRow({required this.friend});
  final Friend friend;
  @override
  Widget build(BuildContext context) {
    return _PersonRow(
      name: friend.displayName,
      subtitle: '${handle(friend.username)} · ${tr.notInContactsYet}',
      friendBadge: true,
      onTap: () => showFriendSheet(context, friend),
      trailing: AppButton(tr.add, icon: LucideIcons.link2, variant: ButtonVariant.secondary, size: ButtonSize.sm,
          onPressed: () => showLinkSheet(context, friend)),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.name, required this.subtitle, this.trailing, this.onTap, this.friendBadge = false});
  final String name;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool friendBadge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          FriendAvatar(name: name, size: 46, isFriend: friendBadge),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, color: c.text)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textMuted, fontSize: 13.5)),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ]),
      ),
    );
  }
}
