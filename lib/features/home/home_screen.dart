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
import '../../domain/text.dart';
import '../../ui/feedback.dart';
import '../../ui/kit.dart';
import '../../ui/rows.dart';
import '../../ui/scaffold.dart';
import '../contacts/quick_sheets.dart';
import '../friends/invite_card.dart';
import '../rdv/status_actions.dart';
import 'push_banner.dart';
import 'agenda_calendar.dart';
import 'to_fix.dart';
import '../friends/add_friend_sheet.dart';
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

/// Filter of "Prochains rendez-vous": all, organized by me, where I'm a guest.
enum AgendaFilter { all, mine, invited }

final agendaFilterProvider = NotifierProvider<AgendaFilterNotifier, AgendaFilter>(AgendaFilterNotifier.new);

class AgendaFilterNotifier extends Notifier<AgendaFilter> {
  @override
  AgendaFilter build() => AgendaFilter.all;
  void set(AgendaFilter f) => state = f;
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
    // Fixed dates only (upcoming or happening now). Events still choosing their
    // date never borrow one: they're in "À fixer".
    final upcoming =
        plannedList.where((r) => !r.slotsOpen && (r.phase(now) == RdvPhase.upcoming || r.phase(now) == RdvPhase.now)).toList();
    final toFixAll = plannedList.where((r) => r.slotsOpen && r.eventId != null).toList();
    final held = heldDays(ref, plannedList);
    final due = toRecontact(contacts);
    final bdaysToday = birthdaysToday(contacts);
    final bdaysWeek = birthdaysThisWeek(contacts);
    final overdue = overdueCount(contacts);
    final filter = ref.watch(agendaFilterProvider);
    final hasGuest = [...upcoming, ...toFixAll].any((r) => !r.isOrganizer);
    bool keep(Rendezvous r) => switch (hasGuest ? filter : AgendaFilter.all) {
          AgendaFilter.all => true,
          AgendaFilter.mine => r.isOrganizer,
          AgendaFilter.invited => !r.isOrganizer,
        };
    final toFix = toFixAll.where(keep).toList();
    final pickedDay = ref.watch(agendaDayProvider);
    // A picked day shows exactly what its dots count: every planned event that
    // day (even one already started / to confirm), not only the upcoming ones.
    final base = pickedDay == null
        ? upcoming
        : plannedList.where((r) => !r.slotsOpen && dayOf(r.appointmentAt) == pickedDay).toList();
    final shown = base.where(keep).toList();
    final heldPicked = pickedDay == null ? null : held[pickedDay];

    return [
      // 4. Birthdays today
      for (final b in bdaysToday) Padding(padding: const EdgeInsets.only(top: 16), child: _BirthdayCard(b)),

      // 5. Counters
      const SizedBox(height: 20),
      _StatsStrip(stats: [
        _Stat(icon: LucideIcons.users, tone: Tone.brand, value: contacts.length, label: tr.statContacts(contacts.length), onTap: () => context.go('/contacts')),
        _Stat(icon: LucideIcons.alarmClock, tone: overdue > 0 ? Tone.red : Tone.gray, value: overdue, label: tr.statOverdue, onTap: () => context.go('/contacts')),
        _Stat(icon: LucideIcons.calendarDays, tone: Tone.green, value: upcoming.length + toFixAll.length, label: tr.statUpcoming),
      ]),

      // 6. To confirm
      if (toConfirm.isNotEmpty) ...[
        SectionTitle(tr.didTheyHappen),
        RowsCard(children: [for (final r in toConfirm) RdvRow(rdv: r, showStatus: false, footer: RdvStatusActions(rdv: r))]),
      ],

      // 7. Keep in touch: people to see regularly (frequency), nothing planned yet.
      // Deliberately explained: these are reminders, not events.
      SectionTitle(
        tr.toReconnect,
        padding: const EdgeInsets.only(top: 24, bottom: 2),
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
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(LucideIcons.repeat, size: 15, color: c.textMuted),
          const SizedBox(width: 6),
          Expanded(child: Text(tr.keepInTouchHelp, style: TextStyle(color: c.textMuted, fontSize: 13.5, height: 1.35))),
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

      // 9. Next rendezvous, with the week / month calendar
      SectionTitle(tr.nextRdvs),
      AgendaCalendar(planned: plannedList, held: held),
      const SizedBox(height: 12),
      if (pickedDay != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: InputChip(
              label: Text(capitalize(formatDayMonth(pickedDay))),
              labelStyle: TextStyle(color: c.tone(Tone.brand).fg, fontWeight: FontWeight.w600),
              backgroundColor: c.tone(Tone.brand).bg,
              side: BorderSide.none,
              shape: const StadiumBorder(),
              deleteIcon: Icon(LucideIcons.x, size: 16, color: c.tone(Tone.brand).fg),
              onDeleted: () => ref.read(agendaDayProvider.notifier).set(null),
            ),
          ),
        ),
      if (planned.hasError && !planned.hasValue)
        ErrorCard(error: planned.error!, onRetry: () => ref.invalidate(plannedRdvProvider))
      else if (!planned.hasValue)
        const SkeletonList(rows: 2)
      else if (upcoming.isEmpty && toFixAll.isEmpty)
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
        // Only useful once some events are someone else's.
        if (hasGuest)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ChipWrap(children: [
              for (final (f, label) in [(AgendaFilter.all, tr.filterAll), (AgendaFilter.mine, tr.filterMine), (AgendaFilter.invited, tr.filterInvited)])
                AppChip(label, selected: filter == f, onTap: () => ref.read(agendaFilterProvider.notifier).set(f)),
            ]),
          ),
        // Not dated yet: their own amber block, on top, never mixed with dates.
        if (pickedDay == null && toFix.isNotEmpty) ...[
          Row(children: [
            Icon(LucideIcons.calendarClock, size: 15, color: c.tone(Tone.amber).text),
            const SizedBox(width: 6),
            Text('${tr.toFixTitle.toUpperCase()} (${toFix.length})',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: c.tone(Tone.amber).text)),
          ]),
          const SizedBox(height: 8),
          for (final r in toFix) ToFixCard(key: ValueKey('fix-${r.id}'), rdv: r),
          const SizedBox(height: 10),
        ],
        if (shown.isEmpty && (pickedDay != null || toFix.isEmpty) && heldPicked == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(pickedDay != null ? tr.nothingThatDay : filter == AgendaFilter.mine ? tr.noMineUpcoming : tr.noInvitedUpcoming,
                textAlign: TextAlign.center, style: TextStyle(color: c.textMuted, fontSize: 14.5)),
          ),
        for (final (day, list) in groupOrdered(shown.take(_maxUpcoming), (Rendezvous r) => dayOf(r.appointmentAt))) ...[
          Overline(relativeDayLabel(day)),
          RowsCard(children: [for (final r in list) RdvRow(rdv: r, showStatus: false, dayLabel: false, showOwner: true)]),
          const SizedBox(height: 8),
        ],
        if (heldPicked != null) ProposedThatDay(held: heldPicked),
        if (shown.length > _maxUpcoming)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              tr.moreRdvs(shown.length - _maxUpcoming),
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted, fontSize: 14),
            ),
          ),
      ],
      const AdTile(AdPlacement.homeAgenda),
    ];
  }
}

class _Welcome extends ConsumerWidget {
  const _Welcome();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = (ref.watch(friendsProvider).value ?? const <Friend>[]).where((f) => f.accepted).toList();
    // SeeU friends waiting for a card: send to Contacts, where they're set up.
    final toSetUp = friends.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: AppCard(
        child: EmptyState(
          icon: LucideIcons.heartHandshake,
          title: toSetUp ? tr.welcomeFriendsTitle : tr.welcomeTitle,
          message: toSetUp ? tr.welcomeFriendsMessage(friends.length) : tr.welcomeMessage,
          actions: [
            if (toSetUp)
              AppButton(tr.manageContacts,
                  icon: LucideIcons.users, size: ButtonSize.lg, onPressed: () => context.go('/contacts')),
            AppButton(tr.addFirstContact,
                icon: LucideIcons.userPlus,
                size: toSetUp ? ButtonSize.md : ButtonSize.lg,
                variant: toSetUp ? ButtonVariant.secondary : ButtonVariant.primary,
                onPressed: () => context.push('/contacts/new')),
            AppButton(tr.addSeeuFriend,
                icon: LucideIcons.userSearch, variant: ButtonVariant.secondary, onPressed: () => showAddFriendSheet(context)),
          ],
        ),
      ),
    );
  }
}

/// Key figures as one flat, tinted strip (deliberately unlike the section buttons above).
class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.stats});
  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(color: c.secondaryFill, borderRadius: BorderRadius.circular(16)),
      child: IntrinsicHeight(
        child: Row(children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) VerticalDivider(width: 1, thickness: 1, indent: 12, endIndent: 12, color: c.border),
            Expanded(child: stats[i]),
          ],
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.tone, required this.value, required this.label, this.onTap});
  final IconData icon;
  final Tone tone;
  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = c.tone(tone);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: t.text),
            const SizedBox(width: 6),
            Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: tone == Tone.red ? t.text : c.text, height: 1.1)),
          ]),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.textMuted)),
        ]),
      ),
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
            Avatar(name: contact.name, path: contact.photoPath, size: 44, seeu: contact.linkedUserId != null, userId: contact.linkedUserId),
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
