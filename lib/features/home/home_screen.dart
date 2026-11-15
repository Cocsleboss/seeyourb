// §4.3 Accueil — the dashboard.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../domain/selectors.dart';
import '../../ui/feedback.dart';
import '../../ui/kit.dart';
import '../../ui/rows.dart';
import '../../ui/scaffold.dart';
import '../contacts/quick_sheets.dart';
import '../friends/invite_card.dart';
import '../rdv/status_actions.dart';
import 'push_banner.dart';
import 'feed_section.dart';
import '../../ads/ads.dart';
import '../../core/i18n.dart';

const _maxDue = 8;
const _maxUpcoming = 10;

/// Home sections: my agenda, friends' events, public events.
enum HomeSection { agenda, friends, explore }

final homeSectionProvider = NotifierProvider<HomeSectionNotifier, HomeSection>(HomeSectionNotifier.new);

class HomeSectionNotifier extends Notifier<HomeSection> {
  @override
  HomeSection build() => HomeSection.agenda;
  void set(HomeSection s) => state = s;
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final profile = ref.watch(profileProvider);
    final section = ref.watch(homeSectionProvider);
    final now = clock();

    final header = Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(profile == null ? tr.greetingAlone(greeting(now)) : tr.greetingName(greeting(now), profile.firstName),
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: c.text, height: 1.15)),
            const SizedBox(height: 4),
            Text(formatDayMonth(now), style: TextStyle(fontSize: 17, color: c.textMuted)),
          ]),
        ),
        AppIconButton(icon: LucideIcons.settings, tooltip: tr.settings, onPressed: () => context.go('/settings')),
      ]),
    );

    final top = [header, const SizedBox(height: 16), HomeSectionPicker(value: section, onChanged: ref.read(homeSectionProvider.notifier).set)];

    return AppScaffold(
      fab: FloatingActionButton(
        onPressed: () => context.push(switch (section) {
          HomeSection.agenda => '/rdv/new',
          HomeSection.friends => '/rdv/new?vis=contacts',
          HomeSection.explore => '/rdv/new?vis=public',
        }),
        tooltip: tr.newRdv,
        backgroundColor: Palette.brand600,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 6,
        child: const Icon(LucideIcons.plus, size: 30),
      ),
      body: SafeArea(
        bottom: false,
        child: switch (section) {
          HomeSection.agenda => _Agenda(top: top),
          HomeSection.friends => FeedSection(scope: 'contacts', top: top),
          HomeSection.explore => FeedSection(scope: 'public', top: top),
        },
      ),
    );
  }
}

/// Three big tabs with icons at the top of Home.
class HomeSectionPicker extends StatelessWidget {
  const HomeSectionPicker({super.key, required this.value, required this.onChanged});
  final HomeSection value;
  final ValueChanged<HomeSection> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget item(HomeSection s, IconData icon, String label, Tone tone) {
      final selected = s == value;
      final t = c.tone(tone);
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: GestureDetector(
            onTap: () => onChanged(s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                color: selected ? t.solid : c.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: selected ? t.solid : c.border),
                boxShadow: selected ? [BoxShadow(color: t.solid.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))] : null,
              ),
              child: Column(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: selected ? Colors.white.withValues(alpha: 0.2) : t.bg, shape: BoxShape.circle),
                  child: Icon(icon, size: 21, color: selected ? Colors.white : t.fg),
                ),
                const SizedBox(height: 6),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : c.text)),
              ]),
            ),
          ),
        ),
      );
    }

    return Row(children: [
      item(HomeSection.agenda, LucideIcons.calendarHeart, tr.homeAgenda, Tone.brand),
      const SizedBox(width: 8),
      item(HomeSection.friends, LucideIcons.partyPopper, tr.homeFriends, Tone.violet),
      const SizedBox(width: 8),
      item(HomeSection.explore, LucideIcons.compass, tr.homeExplore, Tone.green),
    ]);
  }
}

class _Agenda extends ConsumerWidget {
  const _Agenda({required this.top});
  final List<Widget> top;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider);
    final planned = ref.watch(plannedRdvProvider);
    final invites = ref.watch(incomingInvitesProvider).value ?? const <IncomingInvite>[];

    Future<void> refresh() async {
      refreshData(ref);
      ref.invalidate(pushPermissionProvider);
      await Future.wait([ref.read(contactsProvider.future), ref.read(plannedRdvProvider.future)]);
    }

    return PageList(
      onRefresh: refresh,
      bottomPadding: 100,
      children: [
        ...top,
        const PushBanner(),
        if (invites.isNotEmpty) ...[
          SectionTitle(tr.invitationsReceived(invites.length)),
          for (final i in invites) Padding(padding: const EdgeInsets.only(bottom: 10), child: InviteCard(invite: i)),
        ],
        if (contacts.hasError && !contacts.hasValue)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ErrorCard(error: contacts.error!, onRetry: () => ref.invalidate(contactsProvider)),
          )
        else if (!contacts.hasValue)
          const Padding(padding: EdgeInsets.only(top: 16), child: SkeletonList(rows: 5))
        else if (contacts.requireValue.isEmpty)
          const _Welcome()
        else
          ..._dashboard(context, ref, contacts.requireValue, planned),
      ],
    );
  }

  List<Widget> _dashboard(BuildContext context, WidgetRef ref, List<Contact> contacts, AsyncValue<List<Rendezvous>> planned) {
    final c = context.colors;
    final now = DateTime.now();
    final plannedList = planned.value ?? const <Rendezvous>[];
    final toConfirm = plannedList.where((r) => r.needsConfirmation(now)).toList();
    final upcoming = plannedList.where((r) => !r.appointmentAt.isBefore(now)).toList();
    final due = toRecontact(contacts);
    final bdaysToday = birthdaysToday(contacts);
    final bdaysWeek = birthdaysThisWeek(contacts);
    final overdue = overdueCount(contacts);

    return [
      // 4. Birthdays today
      for (final b in bdaysToday) Padding(padding: const EdgeInsets.only(top: 16), child: _BirthdayCard(b)),

      // 5. Counters
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: _Stat(value: contacts.length, label: tr.statContacts(contacts.length), onTap: () => context.go('/contacts'))),
        const SizedBox(width: 10),
        Expanded(child: _Stat(value: overdue, label: tr.statOverdue, danger: overdue > 0, onTap: () => context.go('/contacts'))),
        const SizedBox(width: 10),
        Expanded(child: _Stat(value: upcoming.length, label: tr.statUpcoming)),
      ]),

      // 6. To confirm
      if (toConfirm.isNotEmpty) ...[
        SectionTitle(tr.didTheyHappen),
        RowsCard(children: [for (final r in toConfirm) RdvRow(rdv: r, showStatus: false, footer: RdvStatusActions(rdv: r))]),
      ],

      // 7. To recontact
      SectionTitle(
        tr.toReconnect,
        action: Row(mainAxisSize: MainAxisSize.min, children: [
          if (due.length > _maxDue)
            TextButton(
              onPressed: () => context.go('/contacts'),
              child: Text(tr.seeAllN(due.length), style: TextStyle(color: c.brandText, fontWeight: FontWeight.w600)),
            ),
          AppIconButton(
            icon: LucideIcons.plus,
            tooltip: tr.addSeeSoon,
            color: c.brandText,
            onPressed: () => showSeeSoonSheet(context, excludeIds: due.map((x) => x.id).toSet()),
          ),
        ]),
      ),
      if (due.isEmpty)
        AppCard(
          color: c.tone(Tone.green).bg,
          borderColor: c.tone(Tone.green).bg,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr.allUpToDate, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.tone(Tone.green).fg)),
            const SizedBox(height: 4),
            Text(
              tr.allUpToDateMessage,
              style: TextStyle(color: c.tone(Tone.green).fg.withValues(alpha: 0.85), fontSize: 14.5, height: 1.35),
            ),
          ]),
        )
      else
        RowsCard(children: [for (final x in due.take(_maxDue)) _DueRow(x)]),

      // 8. Birthdays this week
      if (bdaysWeek.isNotEmpty) ...[
        SectionTitle(tr.birthdaysThisWeek),
        RowsCard(children: [
          for (final (x, b) in bdaysWeek)
            ContactRow(
              contact: x,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.cake, size: 16, color: c.tone(Tone.pink).text),
                const SizedBox(width: 4),
                Text(
                  '${tr.inNDays(b.days)}${b.showAge ? ' · ${tr.nYearsOld(b.age)}' : ''}',
                  style: TextStyle(color: c.tone(Tone.pink).text, fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
              ]),
            ),
        ]),
      ],

      // 9. Next rendezvous
      SectionTitle(tr.nextRdvs),
      if (planned.hasError && !planned.hasValue)
        ErrorCard(error: planned.error!, onRetry: () => ref.invalidate(plannedRdvProvider))
      else if (!planned.hasValue)
        const SkeletonList(rows: 2)
      else if (upcoming.isEmpty)
        AppCard(
          child: Column(children: [
            Text(tr.noRdvPlanned, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: c.text)),
            const SizedBox(height: 4),
            Text(tr.noRdvPlannedMessage,
                textAlign: TextAlign.center, style: TextStyle(color: c.textMuted, fontSize: 14.5)),
            const SizedBox(height: 12),
            AppButton(tr.plan, icon: LucideIcons.calendarPlus, variant: ButtonVariant.secondary, onPressed: () => context.push('/rdv/new')),
          ]),
        )
      else ...[
        for (final (day, list) in groupOrdered(upcoming.take(_maxUpcoming), (Rendezvous r) => dayOf(r.appointmentAt))) ...[
          Overline(relativeDayLabel(day)),
          RowsCard(children: [for (final r in list) RdvRow(rdv: r, showStatus: false, dayLabel: false)]),
          const SizedBox(height: 8),
        ],
        if (upcoming.length > _maxUpcoming)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              tr.moreRdvs(upcoming.length - _maxUpcoming),
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted, fontSize: 14),
            ),
          ),
      ],
      const AdTile(AdPlacement.homeAgenda),
    ];
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: AppCard(
          child: EmptyState(
            icon: LucideIcons.heartHandshake,
            title: tr.welcomeTitle,
            message:
                tr.welcomeMessage,
            actions: [
              AppButton(tr.addFirstContact,
                  icon: LucideIcons.userPlus, size: ButtonSize.lg, onPressed: () => context.push('/contacts/new')),
            ],
          ),
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.danger = false, this.onTap});
  final int value;
  final String label;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = danger ? c.tone(Tone.red).text : c.text;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(children: [
        Text('$value', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, letterSpacing: 0.8, fontWeight: FontWeight.w500, color: danger ? color : c.textMuted)),
      ]),
    );
  }
}

class _BirthdayCard extends StatelessWidget {
  const _BirthdayCard(this.contact);
  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pink = c.tone(Tone.pink);
    final b = nextBirthday(contact.birthday)!;
    return AppCard(
      color: pink.bg,
      borderColor: pink.bg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: () => context.push('/contacts/${contact.id}'),
          child: Row(children: [
            Avatar(name: contact.name, path: contact.photoPath, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr.birthdayOf(contact.name),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: pink.fg)),
                const SizedBox(height: 2),
                Text('${b.showAge ? '${tr.turnsToday(b.age)} ' : ''}${tr.wishThem}',
                    style: TextStyle(color: pink.fg.withValues(alpha: 0.85), fontSize: 14)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          if (contact.phone != null) ...[
            Expanded(
              child: AppButton(tr.sendMessage,
                  icon: LucideIcons.messageCircle,
                  size: ButtonSize.sm,
                  variant: ButtonVariant.secondary,
                  full: true,
                  onPressed: () => launchUrl(Uri(scheme: 'sms', path: contact.phone!.replaceAll(RegExp(r'\s+'), '')))),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: AppButton(tr.plan,
                icon: LucideIcons.calendarPlus,
                size: ButtonSize.sm,
                variant: ButtonVariant.secondary,
                full: true,
                onPressed: () => context.push('/rdv/new?contact=${contact.id}')),
          ),
        ]),
      ]),
    );
  }
}

/// A row of "À recontacter" with its three actions.
class _DueRow extends ConsumerWidget {
  const _DueRow(this.contact);
  final Contact contact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marked = onlyMarked(contact);
    return Column(children: [
      ContactRow(contact: contact),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Row(children: [
          Expanded(
            child: AppButton(tr.plan,
                icon: LucideIcons.calendarPlus, size: ButtonSize.sm, full: true, onPressed: () => context.push('/rdv/new?contact=${contact.id}')),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppButton(tr.seen,
                icon: LucideIcons.check,
                size: ButtonSize.sm,
                variant: ButtonVariant.secondary,
                full: true,
                onPressed: () => showMarkSeenSheet(context, contact)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: marked
                ? AppButton(tr.remove, icon: LucideIcons.starOff, size: ButtonSize.sm, variant: ButtonVariant.secondary, full: true,
                    onPressed: () async {
                    final ok = await guard(() => ref.read(apiProvider).setSeeSoon(contact.id, false),
                        success: tr.removedFromList(contact.name));
                    if (ok != null) refreshData(ref);
                  })
                : AppButton(tr.snooze,
                    icon: LucideIcons.clock,
                    size: ButtonSize.sm,
                    variant: ButtonVariant.secondary,
                    full: true,
                    onPressed: () => showSnoozeSheet(context, contact)),
          ),
        ]),
      ),
    ]);
  }
}
