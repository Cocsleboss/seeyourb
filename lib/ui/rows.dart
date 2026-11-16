// List rows shared by several screens: contact row, rendezvous row, date block.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme.dart';
import '../domain/dates.dart';
import '../domain/models.dart';
import 'kit.dart';
import '../domain/text.dart';
import '../data/providers.dart';
import '../features/rdv/rsvp.dart';
import '../core/i18n.dart';

class ContactRow extends StatelessWidget {
  const ContactRow({super.key, required this.contact, this.onTap, this.trailing, this.showBadge = true, this.friend});
  final Contact contact;

  /// The SeeU friend linked to this contact, if any (shows the SeeU badge and @username).
  final Friend? friend;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap ?? () => context.push('/contacts/${contact.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          FriendAvatar(name: contact.name, path: contact.photoPath, size: 46, isFriend: contact.linkedUserId != null, userId: contact.linkedUserId),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(contact.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, color: c.text)),
              const SizedBox(height: 2),
              Text(
                [
                  if (friend?.username != null) '@${friend!.username}',
                  contact.lastMeetingDate == null ? tr.notSeenYet : tr.seenOn(formatDateShort(contact.lastMeetingDate!)),
                  frequencyLabel(contact.frequencyValue, contact.frequencyUnit),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, color: c.textMuted),
              ),
              if (contact.categories.isNotEmpty) ...[
                const SizedBox(height: 4),
                CategoryTags(contact.categories, max: 3),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          if (trailing != null)
            trailing!
          else if (showBadge)
            contact.seeSoon ? Pill(tr.soonPill, tone: Tone.violet) : DueBadge(contact, short: true),
        ]),
      ),
    );
  }
}

/// Avatar with a small SeeU badge when the person is a SeeU friend.
class FriendAvatar extends StatelessWidget {
  const FriendAvatar({super.key, required this.name, this.path, this.size = 46, this.isFriend = false, this.seeu, this.userId});
  final String name;

  /// SeeU account (shows their profile picture).
  final String? userId;

  /// Has a SeeU account (defaults to [isFriend]).
  final bool? seeu;
  final String? path;
  final double size;
  final bool isFriend;

  @override
  Widget build(BuildContext context) {
    final avatar = Avatar(name: name, path: path, size: size, seeu: seeu ?? isFriend, userId: userId);
    if (!isFriend) return avatar;
    final c = context.colors;
    final badge = size * 0.42;
    return Tooltip(
      message: tr.seeuFriend,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(clipBehavior: Clip.none, children: [
          avatar,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(color: Palette.brand600, shape: BoxShape.circle, border: Border.all(color: c.card, width: 2)),
              child: Icon(LucideIcons.heartHandshake, size: badge * 0.55, color: Colors.white),
            ),
          ),
        ]),
      ),
    );
  }
}

/// "14 / NOV" block.
class DateBlock extends StatelessWidget {
  const DateBlock(this.date, {super.key});
  final DateTime date;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(color: c.isDark ? Palette.gray800 : Palette.brand50, borderRadius: BorderRadius.circular(14)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('${date.day}', style: TextStyle(fontSize: 21, height: 1.1, fontWeight: FontWeight.w700, color: c.brandText)),
        Text(monthShort(date), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: c.brandText)),
      ]),
    );
  }
}

class RdvRow extends StatelessWidget {
  const RdvRow({super.key, required this.rdv, this.showStatus = true, this.footer, this.dayLabel = true, this.showOwner = false});
  final Rendezvous rdv;
  final bool showStatus;

  /// "Par vous" / "Invité" badge (upcoming lists).
  final bool showOwner;
  final Widget? footer;

  /// "Hier · 18:30" (true) or "18:30" only (grouped by day already).
  final bool dayLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final meta = TextStyle(fontSize: 13.5, color: c.textMuted);
    final parts = <InlineSpan>[
      TextSpan(
          text: rdv.slotsOpen
              ? tr.dateToChoose
              : dayLabel
                  ? '${relativeDayLabel(rdv.appointmentAt)} · ${formatTime(rdv.appointmentAt)}'
                  : formatTime(rdv.appointmentAt)),
      if (rdv.location != null) ...[
        const TextSpan(text: ' · '),
        WidgetSpan(alignment: PlaceholderAlignment.middle, child: Icon(LucideIcons.mapPin, size: 14, color: c.textMuted)),
        TextSpan(text: ' ${rdv.location}'),
      ],
      if (rdv.photos.isNotEmpty) ...[
        const TextSpan(text: ' · '),
        WidgetSpan(alignment: PlaceholderAlignment.middle, child: Icon(LucideIcons.camera, size: 14, color: c.textMuted)),
        TextSpan(text: ' ${rdv.photos.length}'),
      ],
    ];
    return InkWell(
      onTap: () => context.push('/rdv/${rdv.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            rdv.slotsOpen ? const _PendingDateBlock() : DateBlock(rdv.appointmentAt),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  // Mine: a crown right before the title.
                  if (showOwner && rdv.isOrganizer) ...[
                    Tooltip(message: tr.organizedByYou, child: Icon(LucideIcons.crown, size: 16, color: c.brandText)),
                    const SizedBox(width: 5),
                  ],
                  if (rdv.visibility != EventVisibility.private) ...[
                    Icon(rdv.visibility == EventVisibility.public ? LucideIcons.globe : LucideIcons.usersRound, size: 15, color: c.brandText),
                    const SizedBox(width: 5),
                  ],
                  Expanded(
                    child: Text(rdv.displayTitle,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, color: c.text)),
                  ),
                ]),
                const SizedBox(height: 3),
                Text.rich(TextSpan(children: parts), maxLines: 1, overflow: TextOverflow.ellipsis, style: meta),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (rdv.contacts.isNotEmpty) AvatarStack(people: rdv.contacts),
              if (rdv.isTentative) ...[const SizedBox(height: 4), const TentativePill()]
              else if (showOwner) ...[const SizedBox(height: 4), OwnerPill(mine: rdv.isOrganizer)]
              else if (showStatus) ...[const SizedBox(height: 4), PhasePill(rdv)],
            ]),
          ]),
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ]),
      ),
    );
  }
}

/// Whether I organize the event ("Par vous") or I'm a guest ("Invité").
class OwnerPill extends StatelessWidget {
  const OwnerPill({super.key, required this.mine, this.long = false});
  final bool mine;

  /// "Organisé par vous" instead of "Par vous".
  final bool long;

  @override
  Widget build(BuildContext context) => mine
      ? Pill(long ? tr.organizedByYou : tr.byYou, tone: Tone.brand, icon: LucideIcons.crown)
      : Pill(tr.youAreGuest, icon: LucideIcons.mailOpen);
}

class _PendingDateBlock extends StatelessWidget {
  const _PendingDateBlock();
  @override
  Widget build(BuildContext context) {
    final t = context.colors.tone(Tone.amber);
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(14)),
      child: Icon(LucideIcons.calendarClock, color: t.fg, size: 26),
    );
  }
}

/// Small "label: value" line used in detail cards.
class InfoLine extends StatelessWidget {
  const InfoLine(this.label, this.value, {super.key, this.labelWidth = 140});
  final String label;
  final String value;
  final double labelWidth;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: labelWidth, child: Text(label, style: TextStyle(fontSize: 14.5, color: c.textMuted))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 14.5, color: c.text, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}



/// Under a contact's name, everywhere a contact is listed: whether they're a
/// SeeU friend (handshake + @username) or not on SeeU, then their categories.
class ContactKindLine extends ConsumerWidget {
  const ContactKindLine({super.key, required this.linkedUserId, this.categories = const [], this.fontSize = 12.5});
  final String? linkedUserId;
  final List<String> categories;
  final double fontSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final style = TextStyle(fontSize: fontSize, color: c.textMuted);
    final username = linkedUserId == null
        ? null
        : (ref.watch(friendsProvider).value ?? const <Friend>[]).where((f) => f.userId == linkedUserId).firstOrNull?.username;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(children: [
        Flexible(
          child: Text.rich(
            TextSpan(children: [
              if (linkedUserId != null) ...[
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                      padding: const EdgeInsets.only(right: 4), child: Icon(LucideIcons.heartHandshake, size: fontSize + 1, color: c.brandText)),
                ),
                TextSpan(text: tr.seeuFriendShort, style: TextStyle(color: c.brandText, fontWeight: FontWeight.w600)),
                if (username != null) TextSpan(text: ' ${handle(username)}'),
              ] else
                TextSpan(text: tr.notOnSeeu),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (categories.isNotEmpty) ...[const SizedBox(width: 6), Flexible(child: CategoryTags(categories))],
      ]),
    );
  }
}
