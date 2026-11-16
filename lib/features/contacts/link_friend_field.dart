// New contact form: "SeeU friend" field. Either an existing friend (linked right
// away) or someone found by @username (a friend request is sent once the contact
// is created, tied to it: accepted → linked automatically).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/text.dart';
import '../../ui/feedback.dart';
import '../../ui/forms.dart';
import '../../ui/kit.dart';
import '../../ui/rows.dart';
import '../friends/friend_sheets.dart';

/// What the field holds: a friend to link now, or a username to send a request to.
class FriendLinkChoice {
  const FriendLinkChoice({required this.userId, required this.name, this.username, required this.isFriend, this.relation = UserRelation.none});
  final String userId;
  final String name;
  final String? username;

  /// When not friends yet: request already sent / received, or none.
  final UserRelation relation;

  /// false: not friends yet → request sent after the contact is created.
  final bool isFriend;
}

class LinkFriendField extends ConsumerWidget {
  const LinkFriendField({super.key, required this.value, required this.onChanged});
  final FriendLinkChoice? value;
  final ValueChanged<FriendLinkChoice?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final v = value;
    if (v == null) {
      return AppButton(tr.linkToFriend,
          icon: LucideIcons.heartHandshake,
          variant: ButtonVariant.secondary,
          full: true,
          onPressed: () async {
            final picked = await showAppSheet<FriendLinkChoice>(context,
                title: tr.linkToFriend, subtitle: tr.contactLinkSheetSub, builder: (_) => const _PickFriend());
            if (picked != null) onChanged(picked);
          });
    }
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(children: [
        FriendAvatar(name: v.name, size: 40, isFriend: v.isFriend, seeu: true, userId: v.userId),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v.name, style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
            Text(
                v.isFriend
                    ? handle(v.username)
                    : '${handle(v.username)} · ${switch (v.relation) {
                        UserRelation.sent => tr.requestAlreadySentLinked,
                        UserRelation.received => tr.requestReceivedAcceptOnSave,
                        _ => tr.requestSentOnSave,
                      }}',
                style: TextStyle(color: c.textMuted, fontSize: 13)),
          ]),
        ),
        IconButton(tooltip: tr.remove, onPressed: () => onChanged(null), icon: Icon(LucideIcons.x, color: c.textMuted)),
      ]),
    );
  }
}

class _PickFriend extends ConsumerStatefulWidget {
  const _PickFriend();
  @override
  ConsumerState<_PickFriend> createState() => _PickFriendState();
}

class _PickFriendState extends ConsumerState<_PickFriend> {
  final _q = TextEditingController();
  Timer? _debounce;
  List<UserSearchResult>? _results;
  int _seq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _search(String raw) {
    _debounce?.cancel();
    final q = normalizeUsername(raw);
    if (q.length < 2) return setState(() => _results = null);
    final seq = ++_seq;
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final r = await ref.read(apiProvider).searchUsers(q);
        if (mounted && seq == _seq) setState(() => _results = r);
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final contacts = ref.watch(contactsProvider).value ?? const <Contact>[];
    final friends = (ref.watch(friendsProvider).value ?? const <Friend>[])
        .where((f) => f.accepted && linkedContactOf(contacts, f.userId) == null)
        .toList()
      ..sort((a, b) => compareNames(a.displayName, b.displayName));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final f in friends)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: FriendAvatar(name: f.displayName, size: 40, isFriend: true, userId: f.userId),
          title: Text(f.displayName, style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
          subtitle: Text(handle(f.username), style: TextStyle(color: c.textMuted, fontSize: 13)),
          onTap: () => Navigator.pop(
              context, FriendLinkChoice(userId: f.userId, name: f.displayName, username: f.username, isFriend: true)),
        ),
      if (friends.isNotEmpty) const SizedBox(height: 12),
      Text(tr.orFindByUsername, style: TextStyle(color: c.textMuted, fontSize: 13.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      AppTextField(
        controller: _q,
        hint: tr.usernamePlaceholder,
        onChanged: _search,
        prefix: Padding(
          padding: const EdgeInsets.only(left: 14, right: 6),
          child: Text('@', style: TextStyle(fontSize: 17, color: c.textMuted, fontWeight: FontWeight.w600)),
        ),
      ),
      for (final u in _results ?? const <UserSearchResult>[])
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Avatar(name: u.displayName, size: 40, userId: u.userId),
          title: Text(u.displayName, style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
          subtitle: Text(handle(u.username), style: TextStyle(color: c.textMuted, fontSize: 13)),
          trailing: switch (u.relation) {
            UserRelation.friends => Pill(tr.seeuFriendShort, tone: Tone.brand),
            UserRelation.sent => Pill(tr.requestPendingShort, tone: Tone.orange),
            UserRelation.received => Pill(tr.requestReceivedShort, tone: Tone.violet),
            UserRelation.none => null,
          },
          onTap: () => Navigator.pop(
              context,
              FriendLinkChoice(
                  userId: u.userId,
                  name: u.displayName,
                  username: u.username,
                  isFriend: u.relation == UserRelation.friends,
                  relation: u.relation)),
        ),
      if (_results != null && _results!.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(tr.noResults, style: TextStyle(color: c.textMuted)),
        ),
    ]);
  }
}
