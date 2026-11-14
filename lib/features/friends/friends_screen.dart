// §4.11 Amis.
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
import '../../ui/scaffold.dart';
import 'friend_sheets.dart';
import 'invite_card.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key, this.initialQuery});
  final String? initialQuery;
  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _q = TextEditingController();
  Timer? _debounce;
  List<UserSearchResult>? _results;
  bool _searching = false;
  String? _busy;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _applyInitial(widget.initialQuery);
  }

  @override
  void didUpdateWidget(FriendsScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialQuery != old.initialQuery) _applyInitial(widget.initialQuery);
  }

  void _applyInitial(String? q) {
    if (q == null || q.isEmpty) return;
    _q.text = normalizeUsername(q);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onQuery(_q.text));
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
      } catch (e) {
        if (mounted && seq == _seq) showToast('Recherche impossible', kind: ToastKind.error);
      } finally {
        if (mounted && seq == _seq) setState(() => _searching = false);
      }
    });
  }

  Future<void> _add(UserSearchResult u) async {
    setState(() => _busy = u.userId);
    final res = await guard(() => ref.read(apiProvider).sendFriendRequest(u.username));
    if (!mounted) return;
    setState(() => _busy = null);
    if (res == null) return;
    final who = u.displayName;
    switch (res.status) {
      case FriendRequestStatus.sent:
        showToast('Demande envoyée à $who');
      case FriendRequestStatus.accepted:
        showToast('$who vous avait déjà invité : vous êtes maintenant amis !');
      case FriendRequestStatus.alreadySent:
        showToast('Demande déjà envoyée, en attente de sa réponse.', kind: ToastKind.info);
      case FriendRequestStatus.alreadyFriends:
        showToast('$who fait déjà partie de vos amis.', kind: ToastKind.info);
      case FriendRequestStatus.notFound || FriendRequestStatus.self:
        showToast("Ce compte n'existe plus.", kind: ToastKind.error);
    }
    refreshData(ref);
    _onQuery(_q.text);
    if (res.status == FriendRequestStatus.accepted) _afterAccept(res.userId ?? u.userId);
  }

  Future<void> _respond(Friend f, bool accept) async {
    setState(() => _busy = f.friendshipId);
    final ok = await guard(() async {
      await ref.read(apiProvider).respondFriendRequest(f.friendshipId, accept);
      return true;
    }, success: accept ? 'Vous êtes maintenant amis avec ${f.displayName}' : 'Demande refusée');
    if (!mounted) return;
    setState(() => _busy = null);
    if (ok == null) return;
    refreshData(ref);
    if (accept) _afterAccept(f.userId);
  }

  /// The "associate to a contact" panel opens right after a friendship is accepted.
  Future<void> _afterAccept(String userId) async {
    final friends = await ref.read(friendsProvider.future);
    final f = friends.where((x) => x.userId == userId && x.accepted).firstOrNull;
    if (f == null || !mounted) return;
    if (linkedContactOf(ref.read(contactsProvider).value ?? const [], userId) != null) return;
    showLinkSheet(context, f);
  }

  Future<void> _cancel(Friend f) async {
    setState(() => _busy = f.friendshipId);
    final ok = await guard(() async {
      await ref.read(apiProvider).removeFriend(f.friendshipId);
      return true;
    }, success: 'Demande annulée');
    if (!mounted) return;
    setState(() => _busy = null);
    if (ok != null) refreshData(ref);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final profile = ref.watch(profileProvider);
    final friends = ref.watch(friendsProvider);
    final invites = ref.watch(incomingInvitesProvider).value ?? const <IncomingInvite>[];
    final contacts = ref.watch(contactsProvider).value ?? const <Contact>[];

    return AppScaffold(
      title: 'Amis',
      subtitle: "Partagez rendez-vous et photos avec d'autres utilisateurs",
      body: PageList(
        onRefresh: () async {
          refreshData(ref);
          await ref.read(friendsProvider.future);
        },
        children: [
          const SizedBox(height: 12),
          // 1–2. Add a friend + my username
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Ajouter un ami', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: c.text)),
              const SizedBox(height: 4),
              Text("Cherchez-le par son nom d'utilisateur SeeU.", style: TextStyle(color: c.textMuted, fontSize: 15)),
              const SizedBox(height: 14),
              AppTextField(
                controller: _q,
                hint: 'nom.utilisateur',
                onChanged: _onQuery,
                prefix: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 6),
                  child: Text('@', style: TextStyle(fontSize: 17, color: c.textMuted, fontWeight: FontWeight.w600)),
                ),
                suffix: _searching
                    ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                    : null,
              ),
              if (_results != null) ..._searchResults(c),
              const SizedBox(height: 14),
              if (profile?.username != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                  decoration: BoxDecoration(color: c.isDark ? Palette.gray800.withValues(alpha: 0.6) : Palette.gray50, borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text("Votre nom d'utilisateur :", style: TextStyle(color: c.textMuted, fontSize: 14.5)),
                        Text(handle(profile!.username), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: c.text)),
                      ]),
                    ),
                    AppButton('Partager',
                        icon: LucideIcons.share2, variant: ButtonVariant.secondary, size: ButtonSize.sm, onPressed: () => shareMyHandle(profile.username!)),
                  ]),
                ),
            ]),
          ),

          // 3. Rendezvous invitations
          if (invites.isNotEmpty) ...[
            const SectionTitle('Invitations à un rendez-vous'),
            for (final i in invites) Padding(padding: const EdgeInsets.only(bottom: 10), child: InviteCard(invite: i)),
          ],

          AsyncBody(
            value: friends,
            onRetry: () => ref.invalidate(friendsProvider),
            builder: (all) {
              final received = all.where((f) => !f.accepted && f.incoming).toList();
              final sent = all.where((f) => !f.accepted && !f.incoming).toList();
              final accepted = all.where((f) => f.accepted).toList()..sort((a, b) => compareNames(a.displayName, b.displayName));
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // 4. Received requests
                if (received.isNotEmpty) ...[
                  const SectionTitle('Demandes reçues'),
                  RowsCard(children: [
                    for (final f in received)
                      _PersonRow(
                        name: f.displayName,
                        subtitle: '${handle(f.username)} · Vous a envoyé une demande',
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          AppButton('Refuser',
                              variant: ButtonVariant.secondary, size: ButtonSize.sm, onPressed: _busy == null ? () => _respond(f, false) : null),
                          const SizedBox(width: 6),
                          AppButton('Accepter',
                              size: ButtonSize.sm, loading: _busy == f.friendshipId, onPressed: _busy == null ? () => _respond(f, true) : null),
                        ]),
                      ),
                  ]),
                ],

                // 5. My friends
                SectionTitle('Mes amis', count: accepted.length),
                if (accepted.isEmpty)
                  AppCard(
                    child: EmptyState(
                      icon: LucideIcons.heartHandshake,
                      title: "Pas encore d'ami SeeU",
                      message:
                          "Ajoutez un ami par son nom d'utilisateur : vous pourrez lui proposer vos rendez-vous. S'il accepte, vous l'aurez tous les deux, vos périodes se remettront à zéro chacun de votre côté et vous partagerez les photos.",
                    ),
                  )
                else
                  RowsCard(children: [
                    for (final f in accepted) _friendRow(f, contacts),
                  ]),

                // 6. Sent requests
                if (sent.isNotEmpty) ...[
                  const SectionTitle('Demandes envoyées'),
                  RowsCard(children: [
                    for (final f in sent)
                      _PersonRow(
                        name: f.displayName,
                        subtitle: '${handle(f.username)} · En attente de sa réponse',
                        trailing: AppButton('Annuler',
                            variant: ButtonVariant.secondary,
                            size: ButtonSize.sm,
                            loading: _busy == f.friendshipId,
                            onPressed: _busy == null ? () => _cancel(f) : null),
                      ),
                  ]),
                ],
              ]);
            },
          ),
        ],
      ),
    );
  }

  Widget _friendRow(Friend f, List<Contact> contacts) {
    final c = context.colors;
    final linked = linkedContactOf(contacts, f.userId);
    return _PersonRow(
      name: f.displayName,
      photoPath: linked?.photoPath,
      subtitle: '${handle(f.username)}${linked != null ? ' · Associé au contact ${linked.name}' : ''}',
      onTap: () => showFriendSheet(context, f),
      trailing: linked == null
          ? AppButton('Associer à un contact',
              icon: LucideIcons.link2, variant: ButtonVariant.secondary, size: ButtonSize.sm, onPressed: () => showLinkSheet(context, f))
          : Icon(LucideIcons.chevronRight, color: c.textMuted),
    );
  }

  List<Widget> _searchResults(AppColors c) {
    final r = _results!;
    if (r.isEmpty) {
      return [
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Aucun compte ne commence par '),
            TextSpan(text: handle(normalizeUsername(_q.text)), style: const TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(text: ". Vérifiez l'orthographe, ou invitez cette personne à créer son compte."),
          ]),
          style: TextStyle(color: c.textMuted, fontSize: 14.5, height: 1.35),
        ),
        const SizedBox(height: 10),
        AppButton("Envoyer le lien de l'app", icon: LucideIcons.share2, variant: ButtonVariant.secondary, onPressed: shareAppLink),
      ];
    }
    return [
      const SizedBox(height: 6),
      for (final u in r)
        _PersonRow(
          name: u.displayName,
          subtitle: handle(u.username),
          padding: const EdgeInsets.symmetric(vertical: 8),
          trailing: switch (u.relation) {
            UserRelation.none => AppButton('Ajouter',
                icon: LucideIcons.userPlus, size: ButtonSize.sm, loading: _busy == u.userId, onPressed: _busy == null ? () => _add(u) : null),
            UserRelation.received => AppButton('Accepter',
                icon: LucideIcons.check, size: ButtonSize.sm, loading: _busy == u.userId, onPressed: _busy == null ? () => _add(u) : null),
            UserRelation.sent => Text('Demande envoyée', style: TextStyle(color: c.textMuted, fontSize: 13.5)),
            UserRelation.friends => Text('Déjà dans vos amis', style: TextStyle(color: c.textMuted, fontSize: 13.5)),
          },
        ),
    ];
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.name,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.photoPath,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });
  final String name;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? photoPath;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Row(children: [
          Avatar(name: name, path: photoPath, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, color: c.text)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textMuted, fontSize: 14)),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ]),
      ),
    );
  }
}
