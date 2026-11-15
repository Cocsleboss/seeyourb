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

/// "Ajoute-moi sur SeeU : @andrea" + a link opening the Friends tab, search prefilled.
Future<void> shareMyHandle(String username) {
  final link = '${Config.shareLinkBase}/friends?q=${Uri.encodeComponent(username)}';
  return SharePlus.instance.share(ShareParams(text: 'Ajoute-moi sur SeeU : @$username\n$link'));
}

Future<void> shareAppLink() => SharePlus.instance.share(ShareParams(
      text: "Rejoins-moi sur SeeU, l'app pour ne plus perdre de vue les gens qu'on aime : ${Config.appDownloadUrl}",
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
      title: 'Associer ${friend.displayName}',
      subtitle: "Quel contact correspond à cet ami ? C'est sa période qui sera remise à zéro quand vous validerez un rendez-vous ensemble.",
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
    if (f.email != null && c.email != null && c.email!.toLowerCase() == f.email!.toLowerCase()) return true;
    final first = normalizeText(f.displayName.split(RegExp(r'\s+')).first);
    return first.isNotEmpty && normalizeText(c.name.split(RegExp(r'\s+')).first) == first;
  }

  Future<void> _link(Contact c) async {
    setState(() => _busy = c.id);
    final ok = await guard(() async {
      await ref.read(apiProvider).linkFriendToContact(widget.friend.userId, c.id);
      return true;
    }, success: '${widget.friend.displayName} est associé au contact ${c.name}');
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
      AppButton('Créer un nouveau contact', icon: LucideIcons.userPlus, full: true, onPressed: () {
        final router = GoRouter.of(context);
        Navigator.pop(context);
        router.push('/contacts/new', extra: ContactPrefill(name: f.displayName, email: f.email, linkedUserId: f.userId));
      }),
      const SizedBox(height: 14),
      SearchField(controller: _q, hint: 'Rechercher dans mes contacts…', onChanged: (_) => setState(() {})),
      const SizedBox(height: 6),
      if (shown.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text('Aucun contact ne correspond.', textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
        )
      else
        for (final x in shown)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            enabled: _busy == null,
            leading: Avatar(name: x.name, path: x.photoPath, size: 40),
            title: Text(x.name, style: TextStyle(fontWeight: FontWeight.w500, color: c.text)),
            subtitle: x.linkedUserId == f.userId
                ? Text('Déjà associé', style: TextStyle(color: c.textMuted, fontSize: 13))
                : (x.categoryLabel == null ? null : Text(x.categoryLabel!, style: TextStyle(color: c.textMuted, fontSize: 13))),
            trailing: _busy == x.id
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : (_suggested(x) ? const Pill('Suggéré', tone: Tone.brand) : null),
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
      subtitle: [handle(friend.username), ?friend.email].where((s) => s.isNotEmpty).join(' · '),
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
    }, success: '${widget.friend.displayName} sait que vous aimeriez vous voir 👋');
    if (mounted) setState(() => _busy = null);
  }

  Future<void> _unlink() async {
    setState(() => _busy = 'unlink');
    final ok = await guard(() async {
      await ref.read(apiProvider).unlinkFriend(widget.friend.userId);
      return true;
    }, success: 'Contact dissocié');
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
      title: 'Retirer ${f.displayName} ?',
      message:
          "Vos contacts et rendez-vous existants sont conservés, mais vous ne pourrez plus vous envoyer d'invitations. Les invitations en attente sont annulées.",
      confirmLabel: 'Retirer',
    );
    if (!ok || !mounted) return;
    final done = await guard(() async {
      await ref.read(apiProvider).removeFriend(f.friendshipId);
      return true;
    }, success: 'Ami retiré');
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
      AppButton('Envie de se voir', icon: LucideIcons.hand, size: ButtonSize.lg, full: true, loading: _busy == 'wave', onPressed: _wave),
      const SizedBox(height: 10),
      if (contact != null) ...[
        AppButton('Proposer un rendez-vous',
            icon: LucideIcons.calendarPlus, variant: ButtonVariant.secondary, full: true, onPressed: () => go('/rdv/new?contact=${contact.id}')),
        const SizedBox(height: 10),
        AppButton('Voir le contact ${contact.name}',
            icon: LucideIcons.user, variant: ButtonVariant.secondary, full: true, onPressed: () => go('/contacts/${contact.id}')),
        const SizedBox(height: 10),
        AppButton('Associer à un autre contact', icon: LucideIcons.link2, variant: ButtonVariant.secondary, full: true, onPressed: relink),
        const SizedBox(height: 10),
        AppButton('Dissocier du contact',
            icon: LucideIcons.link2Off, variant: ButtonVariant.secondary, full: true, loading: _busy == 'unlink', onPressed: _unlink),
      ] else
        AppButton('Associer à un contact', icon: LucideIcons.link2, variant: ButtonVariant.secondary, full: true, onPressed: relink),
      const SizedBox(height: 22),
      AppButton('Retirer de mes amis', icon: LucideIcons.userMinus, variant: ButtonVariant.danger, full: true, onPressed: _remove),
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
      title: 'Associer ${contact.name} à un ami SeeU',
      subtitle: 'Vous pourrez lui envoyer vos rendez-vous et partager les photos. Chaque ami ne peut être associé qu\'à un seul contact.',
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
    if (f.email != null && c.email != null && f.email!.toLowerCase() == c.email!.toLowerCase()) return true;
    final first = normalizeText(c.name.split(RegExp(r'\s+')).first);
    return first.isNotEmpty && normalizeText(f.displayName.split(RegExp(r'\s+')).first) == first;
  }

  Future<void> _link(Friend f) async {
    setState(() => _busy = f.userId);
    final ok = await guard(() async {
      await ref.read(apiProvider).linkFriendToContact(f.userId, widget.contact.id);
      return true;
    }, success: '${widget.contact.name} est associé à ${f.displayName}');
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
        Text("Vous n'avez pas encore d'ami SeeU.", style: TextStyle(color: c.textMuted, fontSize: 15)),
        const SizedBox(height: 14),
        AppButton('Ajouter un ami SeeU', icon: LucideIcons.heartHandshake, full: true, onPressed: () {
          final nav = Navigator.of(context);
          nav.pop();
          showAddFriendSheet(nav.context);
        }),
      ]);
    }
    return Column(children: [
      for (final f in friends)
        Builder(builder: (_) {
          final other = linkedContactOf(contacts, f.userId);
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            enabled: _busy == null,
            leading: Avatar(name: f.displayName, path: other?.photoPath, size: 40),
            title: Text(f.displayName, style: TextStyle(fontWeight: FontWeight.w500, color: c.text)),
            subtitle: Text(
              [handle(f.username), if (other != null) 'Associé à ${other.name}'].where((s) => s.isNotEmpty).join(' · '),
              style: TextStyle(color: c.textMuted, fontSize: 13),
            ),
            trailing: _busy == f.userId
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : (_suggested(f) ? const Pill('Suggéré', tone: Tone.brand) : null),
            onTap: () => _link(f),
          );
        }),
    ]);
  }
}
