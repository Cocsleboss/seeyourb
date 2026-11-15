// §4.6 Fiche contact.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../ui/feedback.dart';
import '../../ui/kit.dart';
import '../../ui/rows.dart';
import '../../ui/scaffold.dart';
import '../misc/fallback_screens.dart';
import '../../domain/text.dart';
import '../friends/friend_sheets.dart';
import '../photos/photo_section.dart';
import 'quick_sheets.dart';

String birthdayLabel(BirthdayInfo b) {
  final age = b.showAge ? ' (${b.age} ans)' : '';
  if (b.days == 0) return "C'est son anniversaire aujourd'hui !$age";
  if (b.days == 1) return 'Anniversaire demain$age';
  return 'Anniversaire dans ${b.days} jours$age';
}

class ContactDetailScreen extends ConsumerWidget {
  const ContactDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(contactProvider(id));
    if (value.hasValue && value.value == null) {
      return const MissingItem(title: 'Contact introuvable', backLabel: 'Voir mes contacts', backPath: '/contacts');
    }
    final contact = value.value;
    return AppScaffold(
      title: contact?.name ?? '',
      back: true,
      actions: [
        if (contact != null)
          AppIconButton(
            icon: LucideIcons.pencil,
            tooltip: 'Modifier',
            color: context.colors.brandText,
            onPressed: () => context.push('/contacts/$id/edit'),
          ),
      ],
      body: contact == null
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: AsyncBody(value: value, onRetry: () => ref.invalidate(contactsProvider), builder: (_) => const SizedBox()),
            )
          : _Body(contact),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body(this.contact);
  final Contact contact;

  Future<void> _toggleSeeSoon(WidgetRef ref) async {
    final ok = await guard(
      () => ref.read(apiProvider).setSeeSoon(contact.id, !contact.seeSoon),
      success: contact.seeSoon ? 'Retiré de la liste « à voir bientôt »' : "Ajouté à la liste « à voir bientôt » de l'accueil",
    );
    if (ok != null) refreshData(ref);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmSheet(
      context,
      title: 'Supprimer ce contact ?',
      message: 'Ses rendez-vous et photos seront aussi supprimés. Cette action est définitive.',
      confirmLabel: 'Supprimer',
    );
    if (!ok || !context.mounted) return;
    final done = await guard(() async {
      await ref.read(apiProvider).deleteContact(contact);
      return true;
    }, success: 'Contact supprimé');
    if (done == null || !context.mounted) return;
    refreshData(ref);
    context.go('/contacts');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final bday = nextBirthday(contact.birthday);
    final snoozed = contact.snoozeUntil != null && contact.snoozeUntil!.isAfter(contact.nextDueDate);
    final rdvs = ref.watch(contactRdvsProvider(contact.id));
    final photos = ref.watch(contactPhotosProvider(contact.id));

    return PageList(
      onRefresh: () async {
        refreshData(ref);
        await ref.read(contactsProvider.future);
      },
      children: [
        // 1. Header
        const SizedBox(height: 8),
        Center(child: Avatar(name: contact.name, path: contact.photoPath, size: 100)),
        const SizedBox(height: 12),
        Text(contact.name, textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: c.text)),
        if (contact.categories.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [for (final cat in contact.categories) Pill(cat, large: true)],
          ),
        ],
        if (contact.linkedUserId != null) ...[
          const SizedBox(height: 8),
          const Center(child: Pill('Ami SeeU · rendez-vous et photos partageables', tone: Tone.brand, icon: LucideIcons.users)),
        ],
        if (bday != null && bday.days <= 30) ...[
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(LucideIcons.cake, size: 18, color: c.tone(Tone.pink).text),
            const SizedBox(width: 6),
            Flexible(child: Text(birthdayLabel(bday), style: TextStyle(color: c.tone(Tone.pink).text, fontSize: 16))),
          ]),
        ],
        const SizedBox(height: 20),

        // 2. Follow-up card
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            DueBadge(contact, large: true),
            const SizedBox(height: 12),
            InfoLine('Dernière rencontre', contact.lastMeetingDate == null ? 'Pas encore notée' : formatDateLong(contact.lastMeetingDate!)),
            InfoLine('Prochaine échéance', '${formatDateLong(effectiveDueDate(contact))}${snoozed ? ' (reportée)' : ''}'),
            InfoLine('Fréquence', frequencyLabel(contact.frequencyValue, contact.frequencyUnit)),
          ]),
        ),
        const SizedBox(height: 16),

        // 3. Actions
        AppButton('Planifier un rendez-vous',
            icon: LucideIcons.calendarPlus, size: ButtonSize.lg, full: true, onPressed: () => context.push('/rdv/new?contact=${contact.id}')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: AppButton("Vu aujourd'hui",
                icon: LucideIcons.check, variant: ButtonVariant.secondary, size: ButtonSize.lg, full: true,
                onPressed: () => showMarkSeenSheet(context, contact)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton('Reporter',
                icon: LucideIcons.clock, variant: ButtonVariant.secondary, size: ButtonSize.lg, full: true,
                onPressed: () => showSnoozeSheet(context, contact)),
          ),
        ]),
        const SizedBox(height: 10),
        AppButton(
          contact.seeSoon ? 'Dans « à voir bientôt » · retirer' : 'À voir bientôt',
          icon: contact.seeSoon ? Icons.star_rounded : LucideIcons.star,
          variant: contact.seeSoon ? ButtonVariant.outline : ButtonVariant.secondary,
          size: ButtonSize.lg,
          full: true,
          onPressed: () => _toggleSeeSoon(ref),
        ),

        // SeeU friend: actions if linked, otherwise offer to associate
        _FriendSection(contact: contact),

        // 4. Information
        if (contact.phone != null || contact.email != null || contact.notes != null || contact.birthday != null) ...[
          const SectionTitle('Informations'),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (contact.phone != null)
                _InfoAction(
                  icon: LucideIcons.phone,
                  text: contact.phone!,
                  onTap: () => launchUrl(Uri(scheme: 'tel', path: contact.phone!.replaceAll(RegExp(r'\s+'), ''))),
                ),
              if (contact.email != null)
                _InfoAction(icon: LucideIcons.mail, text: contact.email!, onTap: () => launchUrl(Uri(scheme: 'mailto', path: contact.email))),
              if (contact.birthday != null) _InfoAction(icon: LucideIcons.cake, text: 'Né(e) le ${formatDateLong(contact.birthday!)}'),
              if (contact.notes != null) _InfoAction(icon: LucideIcons.stickyNote, text: contact.notes!),
            ]),
          ),
        ],

        // 5. Rendezvous
        const SectionTitle('Rendez-vous'),
        AsyncBody(
          value: rdvs,
          skeletonRows: 2,
          onRetry: () => ref.invalidate(contactRdvsProvider(contact.id)),
          builder: (list) {
            if (list.isEmpty) {
              return Text("Aucun rendez-vous avec ce contact pour l'instant.", style: TextStyle(color: c.textMuted, fontSize: 14.5));
            }
            final now = DateTime.now();
            final upcoming = list.where((r) => r.status == RdvStatus.planifie && !r.appointmentAt.isBefore(now)).toList()
              ..sort((a, b) => a.appointmentAt.compareTo(b.appointmentAt));
            final ids = upcoming.map((r) => r.id).toSet();
            final past = list.where((r) => !ids.contains(r.id)).toList();
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (upcoming.isNotEmpty) ...[
                const Overline('À venir'),
                RowsCard(children: [for (final r in upcoming) RdvRow(rdv: r, showStatus: false)]),
                const SizedBox(height: 12),
              ],
              if (past.isNotEmpty) ...[
                const Overline('Passés'),
                RowsCard(children: [for (final r in past) RdvRow(rdv: r)]),
              ],
            ]);
          },
        ),

        // 6. Gallery
        PhotoSection(title: 'Galerie', photos: photos, contactId: contact.id),

        // 7. Delete
        const SizedBox(height: 28),
        AppButton('Supprimer le contact',
            icon: LucideIcons.trash2, variant: ButtonVariant.danger, full: true, onPressed: () => _delete(context, ref)),
      ],
    );
  }
}

class _FriendSection extends ConsumerStatefulWidget {
  const _FriendSection({required this.contact});
  final Contact contact;
  @override
  ConsumerState<_FriendSection> createState() => _FriendSectionState();
}

class _FriendSectionState extends ConsumerState<_FriendSection> {
  bool _waving = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final contact = widget.contact;
    if (contact.linkedUserId == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: AppButton('Associer à un ami SeeU',
            icon: LucideIcons.link2,
            variant: ButtonVariant.ghost,
            full: true,
            onPressed: () => showLinkContactToFriendSheet(context, contact)),
      );
    }
    final friend = (ref.watch(friendsProvider).value ?? const <Friend>[])
        .where((f) => f.accepted && f.userId == contact.linkedUserId)
        .firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Ami SeeU'),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(LucideIcons.heartHandshake, color: c.brandText),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                friend == null ? 'Associé à un compte SeeU' : '${friend.displayName} · ${handle(friend.username)}',
                style: TextStyle(fontWeight: FontWeight.w600, color: c.text, fontSize: 15.5),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Vous pouvez lui envoyer vos rendez-vous et partager les photos.',
              style: TextStyle(color: c.textMuted, fontSize: 13.5)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: AppButton('Envie de se voir',
                  icon: LucideIcons.hand,
                  variant: ButtonVariant.secondary,
                  size: ButtonSize.sm,
                  full: true,
                  loading: _waving,
                  onPressed: () async {
                    setState(() => _waving = true);
                    await guard(() async {
                      await ref.read(apiProvider).sendWave(contact.linkedUserId!);
                      return true;
                    }, success: '${contact.name} sait que vous aimeriez vous voir 👋');
                    if (mounted) setState(() => _waving = false);
                  }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton('Gérer',
                  icon: LucideIcons.settings2,
                  variant: ButtonVariant.secondary,
                  size: ButtonSize.sm,
                  full: true,
                  onPressed: friend == null ? null : () => showFriendSheet(context, friend)),
            ),
          ]),
        ]),
      ),
    ]);
  }
}

class _InfoAction extends StatelessWidget {
  const _InfoAction({required this.icon, required this.text, this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = onTap != null ? c.brandText : c.text;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: onTap != null ? c.brandText : c.textSubtle),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(fontSize: 15.5, color: color, height: 1.35))),
        ]),
      ),
    );
  }
}
