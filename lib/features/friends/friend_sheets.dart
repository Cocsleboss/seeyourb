// Friend panel, "associate to a contact" panel and share helpers (§4.11).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/text.dart';
import '../../ui/feedback.dart';
import '../../ui/forms.dart';
import '../../ui/kit.dart';
import '../contacts/contact_form_screen.dart';
import 'add_friend_sheet.dart';
import '../../core/i18n.dart';

/// "Ajoute-moi sur SeeU : @andrea" + a link opening the Friends tab, search prefilled.
Future<void> shareMyHandle(String username) {
  final link = '${Config.shareLinkBase}/friends?q=${Uri.encodeComponent(username)}';
  return SharePlus.instance.share(ShareParams(text: tr.shareHandleText(username, link)));
}

Future<void> shareAppLink() => SharePlus.instance.share(ShareParams(
      text: tr.shareAppText(Config.appDownloadUrl),
    ));

Contact? linkedContactOf(List<Contact> contacts, String friendUserId) {
  for (final c in contacts) {
    if (c.linkedUserId == friendUserId) return c;
  }
  return null;
}

/* ------------------------------------------------------------------ */
/*  Associate a friend with a contact                                  */
/* ------------------------------------------------------------------ */

Future<void> showLinkSheet(BuildContext context, Friend friend) => showAppSheet(
      context,
      title: tr.linkFriendTitle(friend.displayName),
      subtitle: tr.linkFriendSub,
      builder: (_) => _LinkSheet(friend),
    );

class _LinkSheet extends ConsumerStatefulWidget {
  const _LinkSheet(this.friend);
  final Friend friend;
  @override
  ConsumerState<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends ConsumerState<_LinkSheet> {
  final _q = TextEditingController();
  String? _busy;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  bool _suggested(Contact c) {
    final f = widget.friend;
    final first = normalizeText(f.displayName.split(RegExp(r'\s+')).first);
    return first.isNotEmpty && normalizeText(c.name.split(RegExp(r'\s+')).first) == first;
  }

  Future<void> _link(Contact c) async {
    setState(() => _busy = c.id);
    final ok = await guard(() async {
      await ref.read(apiProvider).linkFriendToContact(widget.friend.userId, c.id);
      return true;
    }, success: tr.linkedFriendToContact(widget.friend.displayName, c.name));
    if (!mounted) return;
    setState(() => _busy = null);
    if (ok != null) {
      refreshData(ref);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final f = widget.friend;
    final all = (ref.watch(contactsProvider).value ?? const <Contact>[])
        .where((x) => x.linkedUserId == null || x.linkedUserId == f.userId)
        .toList();
    final shown = all.where((x) => matchesQuery(x.name, _q.text)).toList()
      ..sort((a, b) {
        final s = (_suggested(b) ? 1 : 0) - (_suggested(a) ? 1 : 0);
        return s != 0 ? s : compareNames(a.name, b.name);
      });
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppButton(tr.createNewContact, icon: LucideIcons.userPlus, full: true, onPressed: () {
        final router = GoRouter.of(context);
        Navigator.pop(context);
        router.push('/contacts/new', extra: ContactPrefill(name: f.displayName, linkedUserId: f.userId));
      }),
      const SizedBox(height: 14),
      SearchField(controller: _q, hint: tr.searchMyContacts, onChanged: (_) => setState(() {})),
      const SizedBox(height: 6),
      if (shown.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(tr.noMatchingContact, textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
        )
      else
        for (final x in shown)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            enabled: _busy == null,
            leading: Avatar(name: x.name, path: x.photoPath, size: 40, seeu: x.linkedUserId != null, userId: x.linkedUserId),
            title: Text(x.name, style: TextStyle(fontWeight: FontWeight.w500, color: c.text)),
            subtitle: x.linkedUserId == f.userId
                ? Text(tr.alreadyLinked, style: TextStyle(color: c.textMuted, fontSize: 13))
                : (x.categoryLabel == null ? null : Text(x.categoryLabel!, style: TextStyle(color: c.textMuted, fontSize: 13))),
            trailing: _busy == x.id
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : (_suggested(x) ? Pill(tr.suggested, tone: Tone.brand) : null),
            onTap: () => _link(x),
          ),
    ]);
  }
}

/* ------------------------------------------------------------------ */
/*  Friend panel                                                       */
/* ------------------------------------------------------------------ */

Future<void> showFriendSheet(BuildContext context, Friend friend) => showAppSheet(
      context,
      title: friend.displayName,
      subtitle: handle(friend.username),
      builder: (_) => _FriendSheet(friend),
    );

class _FriendSheet extends ConsumerStatefulWidget {
  const _FriendSheet(this.friend);
  final Friend friend;
  @override
  ConsumerState<_FriendSheet> createState() => _FriendSheetState();
}

class _FriendSheetState extends ConsumerState<_FriendSheet> {
  String? _busy;

  Future<void> _wave() async {
    setState(() => _busy = 'wave');
    await guard(() async {
      await ref.read(apiProvider).sendWave(widget.friend.userId);
      return true;
    }, success: tr.wantToMeetSent(widget.friend.displayName));
    if (mounted) setState(() => _busy = null);
  }

  Future<void> _unlink() async {
    setState(() => _busy = 'unlink');
    final ok = await guard(() async {
      await ref.read(apiProvider).unlinkFriend(widget.friend.userId);
      return true;
    }, success: tr.contactUnlinked);
    if (!mounted) return;
    setState(() => _busy = null);
    if (ok != null) {
      refreshData(ref);
      Navigator.pop(context);
    }
  }

  Future<void> _remove() async {
    final f = widget.friend;
    final ok = await confirmSheet(
      context,
      title: tr.removeFriendTitle(f.displayName),
      message: tr.removeFriendMessage,
      confirmLabel: tr.remove,
    );
    if (!ok || !mounted) return;
    final done = await guard(() async {
      await withProgress(() => ref.read(apiProvider).removeFriend(f.friendshipId));
      return true;
    }, success: tr.friendRemoved);
    if (!mounted) return;
    if (done != null) {
      refreshData(ref);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.friend;
    final contact = linkedContactOf(ref.watch(contactsProvider).value ?? const [], f.userId);
    final router = GoRouter.of(context);
    final nav = Navigator.of(context);
    void go(String path) {
      nav.pop();
      router.push(path);
    }

    void relink() {
      nav.pop();
      showLinkSheet(nav.context, f);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppButton(tr.wantToMeet, icon: LucideIcons.hand, size: ButtonSize.lg, full: true, loading: _busy == 'wave', onPressed: _wave),
      const SizedBox(height: 10),
      if (contact != null) ...[
        AppButton(tr.proposeRdv,
            icon: LucideIcons.calendarPlus, variant: ButtonVariant.secondary, full: true, onPressed: () => go('/rdv/new?contact=${contact.id}')),
        const SizedBox(height: 10),
        AppButton(tr.seeContactName(contact.name),
            icon: LucideIcons.user, variant: ButtonVariant.secondary, full: true, onPressed: () => go('/contacts/${contact.id}')),
        const SizedBox(height: 10),
        AppButton(tr.linkToOtherContact, icon: LucideIcons.link2, variant: ButtonVariant.secondary, full: true, onPressed: relink),
        const SizedBox(height: 10),
        AppButton(tr.unlinkContact,
            icon: LucideIcons.link2Off, variant: ButtonVariant.secondary, full: true, loading: _busy == 'unlink', onPressed: _unlink),
      ] else
        AppButton(tr.linkToContact, icon: LucideIcons.link2, variant: ButtonVariant.secondary, full: true, onPressed: relink),
      const SizedBox(height: 22),
      AppButton(tr.removeFromFriends, icon: LucideIcons.userMinus, variant: ButtonVariant.danger, full: true, onPressed: _remove),
    ]);
  }
}

/* ------------------------------------------------------------------ */
/*  After a friendship is accepted: offer to associate a contact      */
/* ------------------------------------------------------------------ */

Future<void> offerLinkAfterAccept(BuildContext context, String userId) async {
  final container = ProviderScope.containerOf(context, listen: false);
  container.invalidate(friendsProvider);
  final friends = await container.read(friendsProvider.future);
  final f = friends.where((x) => x.userId == userId && x.accepted).firstOrNull;
  if (f == null || !context.mounted) return;
  if (linkedContactOf(container.read(contactsProvider).value ?? const [], userId) != null) return;
  await showLinkSheet(context, f);
}

/* ------------------------------------------------------------------ */
/*  From a contact: associate it with one of my SeeU friends          */
/* ------------------------------------------------------------------ */

Future<void> showLinkContactToFriendSheet(BuildContext context, Contact contact) => showAppSheet(
      context,
      title: tr.linkContactToFriendTitle(contact.name),
      subtitle: tr.linkContactToFriendSub,
      builder: (_) => _LinkContactToFriend(contact),
    );

class _LinkContactToFriend extends ConsumerStatefulWidget {
  const _LinkContactToFriend(this.contact);
  final Contact contact;
  @override
  ConsumerState<_LinkContactToFriend> createState() => _LinkContactToFriendState();
}

class _LinkContactToFriendState extends ConsumerState<_LinkContactToFriend> {
  String? _busy;

  bool _suggested(Friend f) {
    final c = widget.contact;
    final first = normalizeText(c.name.split(RegExp(r'\s+')).first);
    return first.isNotEmpty && normalizeText(f.displayName.split(RegExp(r'\s+')).first) == first;
  }

  void _search() {
    final nav = Navigator.of(context);
    nav.pop();
    showAddFriendSheet(nav.context, forContact: widget.contact);
  }

  Future<void> _link(Friend f) async {
    setState(() => _busy = f.userId);
    final ok = await guard(() async {
      await ref.read(apiProvider).linkFriendToContact(f.userId, widget.contact.id);
      return true;
    }, success: tr.linkedContactToFriend(widget.contact.name, f.displayName));
    if (!mounted) return;
    setState(() => _busy = null);
    if (ok != null) {
      refreshData(ref);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final contacts = ref.watch(contactsProvider).value ?? const <Contact>[];
    final friends = (ref.watch(friendsProvider).value ?? const <Friend>[]).where((f) => f.accepted).toList()
      ..sort((a, b) {
        final s = (_suggested(b) ? 1 : 0) - (_suggested(a) ? 1 : 0);
        return s != 0 ? s : compareNames(a.displayName, b.displayName);
      });
    if (friends.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr.noSeeuFriendsYet, style: TextStyle(color: c.textMuted, fontSize: 15)),
        const SizedBox(height: 14),
        AppButton(tr.findOnSeeu, icon: LucideIcons.userSearch, full: true, onPressed: _search),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final f in friends)
        Builder(builder: (_) {
          final other = linkedContactOf(contacts, f.userId);
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            enabled: _busy == null,
            leading: Avatar(name: f.displayName, path: other?.photoPath, size: 40, userId: f.userId),
            title: Text(f.displayName, style: TextStyle(fontWeight: FontWeight.w500, color: c.text)),
            subtitle: Text(
              [handle(f.username), if (other != null) tr.linkedTo(other.name)].where((s) => s.isNotEmpty).join(' · '),
              style: TextStyle(color: c.textMuted, fontSize: 13),
            ),
            trailing: _busy == f.userId
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : (_suggested(f) ? Pill(tr.suggested, tone: Tone.brand) : null),
            onTap: () => _link(f),
          );
        }),
      const SizedBox(height: 12),
      // Not a friend yet: send a request tied to this contact.
      AppButton(tr.findOnSeeu, icon: LucideIcons.userSearch, variant: ButtonVariant.secondary, full: true, onPressed: _search),
    ]);
  }
}
