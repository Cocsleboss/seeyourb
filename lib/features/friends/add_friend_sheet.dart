// "Ajouter un ami SeeU": search by @username, send / accept requests, share my @.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/text.dart';
import '../../ui/feedback.dart';
import '../../ui/forms.dart';
import '../../ui/kit.dart';
import 'friend_sheets.dart';
import '../../core/i18n.dart';

/// Returns the user id of a person who became a friend right away (they had invited me).
/// [forContact]: the request is for this contact, which gets linked once accepted.
Future<void> showAddFriendSheet(BuildContext context, {String? initialQuery, Contact? forContact}) async {
  final becameFriend = await showAppSheet<String>(
    context,
    title: forContact == null ? tr.addSeeuFriendLong : tr.findContactOnSeeu(forContact.name),
    subtitle: forContact == null ? tr.addFriendSub : tr.findContactOnSeeuSub(forContact.name),
    builder: (_) => _AddFriend(initialQuery: initialQuery, forContact: forContact),
  );
  if (becameFriend != null && forContact == null && context.mounted) await offerLinkAfterAccept(context, becameFriend);
}

class _AddFriend extends ConsumerStatefulWidget {
  const _AddFriend({this.initialQuery, this.forContact});
  final String? initialQuery;
  final Contact? forContact;
  @override
  ConsumerState<_AddFriend> createState() => _AddFriendState();
}

class _AddFriendState extends ConsumerState<_AddFriend> {
  final _q = TextEditingController();
  Timer? _debounce;
  List<UserSearchResult>? _results;
  bool _searching = false;
  String? _busy;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery;
    if (q != null && q.isNotEmpty) {
      _q.text = normalizeUsername(q);
      WidgetsBinding.instance.addPostFrameCallback((_) => _onQuery(_q.text));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _onQuery(String raw) {
    _debounce?.cancel();
    final q = normalizeUsername(raw);
    if (q.length < 2) {
      setState(() {
        _results = null;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final seq = ++_seq;
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final r = await ref.read(apiProvider).searchUsers(q);
        if (mounted && seq == _seq) setState(() => _results = r);
      } catch (_) {
        if (mounted && seq == _seq) showToast(tr.searchFailed, kind: ToastKind.error);
      } finally {
        if (mounted && seq == _seq) setState(() => _searching = false);
      }
    });
  }

  Future<void> _add(UserSearchResult u) async {
    setState(() => _busy = u.userId);
    final res = await guard(() => ref.read(apiProvider).sendFriendRequest(u.username, contactId: widget.forContact?.id));
    if (!mounted) return;
    setState(() => _busy = null);
    if (res == null) return;
    final who = u.displayName;
    switch (res.status) {
      case FriendRequestStatus.sent:
        showToast(tr.requestSentTo(who));
      case FriendRequestStatus.accepted:
        showToast(tr.alreadyInvitedYou(who));
      case FriendRequestStatus.alreadySent:
        showToast(tr.requestAlreadySent, kind: ToastKind.info);
      case FriendRequestStatus.alreadyFriends:
        showToast(tr.alreadyFriend(who), kind: ToastKind.info);
      case FriendRequestStatus.notFound || FriendRequestStatus.self:
        showToast(tr.accountGone, kind: ToastKind.error);
    }
    refreshData(ref);
    if (widget.forContact != null && res.status != FriendRequestStatus.notFound && res.status != FriendRequestStatus.self) {
      Navigator.pop(context); // back to the contact, which now shows the request / link
    } else if (res.status == FriendRequestStatus.accepted) {
      Navigator.pop(context, res.userId ?? u.userId);
    } else {
      _onQuery(_q.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final profile = ref.watch(profileProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppTextField(
        controller: _q,
        hint: tr.usernamePlaceholder,
        autofocus: widget.initialQuery == null,
        onChanged: _onQuery,
        prefix: Padding(
          padding: const EdgeInsets.only(left: 14, right: 6),
          child: Text('@', style: TextStyle(fontSize: 17, color: c.textMuted, fontWeight: FontWeight.w600)),
        ),
        suffix: _searching
            ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
            : null,
      ),
      if (_results != null) ..._resultWidgets(c),
      const SizedBox(height: 16),
      if (profile?.username != null)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
          decoration: BoxDecoration(color: c.secondaryFill, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr.yourUsername, style: TextStyle(color: c.textMuted, fontSize: 14.5)),
                Text(handle(profile!.username), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: c.text)),
              ]),
            ),
            AppButton(tr.share,
                icon: LucideIcons.share2, variant: ButtonVariant.secondary, size: ButtonSize.sm, onPressed: () => shareMyHandle(profile.username!)),
          ]),
        ),
    ]);
  }

  List<Widget> _resultWidgets(AppColors c) {
    final r = _results!;
    if (r.isEmpty) {
      return [
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(children: () {
            final parts = tr.noAccountStartsWith('\u0000').split('\u0000');
            return [
              TextSpan(text: parts.first),
              TextSpan(text: handle(normalizeUsername(_q.text)), style: const TextStyle(fontWeight: FontWeight.w700)),
              if (parts.length > 1) TextSpan(text: parts.last),
            ];
          }()),
          style: TextStyle(color: c.textMuted, fontSize: 14.5, height: 1.35),
        ),
        const SizedBox(height: 10),
        AppButton(tr.sendAppLink, icon: LucideIcons.share2, variant: ButtonVariant.secondary, onPressed: shareAppLink),
      ];
    }
    return [
      const SizedBox(height: 6),
      for (final u in r)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Avatar(name: u.displayName, size: 42, userId: u.userId),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.displayName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: c.text)),
                Text(handle(u.username), style: TextStyle(color: c.textMuted, fontSize: 14)),
              ]),
            ),
            switch (u.relation) {
              UserRelation.none => AppButton(tr.add,
                  icon: LucideIcons.userPlus, size: ButtonSize.sm, loading: _busy == u.userId, onPressed: _busy == null ? () => _add(u) : null),
              UserRelation.received => AppButton(tr.rsvpAccept,
                  icon: LucideIcons.check, size: ButtonSize.sm, loading: _busy == u.userId, onPressed: _busy == null ? () => _add(u) : null),
              UserRelation.sent => Text(tr.requestSent, style: TextStyle(color: c.textMuted, fontSize: 13.5)),
              UserRelation.friends => Text(tr.alreadyInFriends, style: TextStyle(color: c.textMuted, fontSize: 13.5)),
            },
          ]),
        ),
    ];
  }
}
