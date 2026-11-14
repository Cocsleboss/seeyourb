// List rows shared by several screens: contact row, rendezvous row, date block.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme.dart';
import '../domain/dates.dart';
import '../domain/models.dart';
import '../domain/text.dart';
import 'kit.dart';

class ContactRow extends StatelessWidget {
  const ContactRow({super.key, required this.contact, this.onTap, this.trailing, this.showBadge = true});
  final Contact contact;
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
          Avatar(name: contact.name, path: contact.photoPath, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(contact.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, color: c.text)),
              const SizedBox(height: 2),
              Text(
                'Vu le ${formatDate(contact.lastMeetingDate)} · ${frequencyLabel(contact.frequencyValue, contact.frequencyUnit)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, color: c.textMuted),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          if (trailing != null)
            trailing!
          else if (showBadge)
            contact.seeSoon ? const Pill('★ Bientôt', tone: Tone.violet) : DueBadge(contact, short: true),
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
  const RdvRow({super.key, required this.rdv, this.showStatus = true, this.footer, this.dayLabel = true});
  final Rendezvous rdv;
  final bool showStatus;
  final Widget? footer;

  /// "Hier · 18:30" (true) or "18:30" only (grouped by day already).
  final bool dayLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final meta = TextStyle(fontSize: 13.5, color: c.textMuted);
    final parts = <InlineSpan>[
      TextSpan(text: dayLabel ? '${relativeDayLabel(rdv.appointmentAt)} · ${formatTime(rdv.appointmentAt)}' : formatTime(rdv.appointmentAt)),
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
            DateBlock(rdv.appointmentAt),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(rdv.displayTitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600, color: c.text)),
                const SizedBox(height: 3),
                Text.rich(TextSpan(children: parts), maxLines: 1, overflow: TextOverflow.ellipsis, style: meta),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (rdv.contacts.isNotEmpty) AvatarStack(people: rdv.contacts),
              if (showStatus) ...[const SizedBox(height: 4), StatusPill(rdv.status)],
            ]),
          ]),
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ]),
      ),
    );
  }
}

/// Small "label: value" line used in detail cards.
class InfoLine extends StatelessWidget {
  const InfoLine(this.label, this.value, {super.key, this.labelWidth = 150});
  final String label;
  final String value;
  final double labelWidth;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: labelWidth, child: Text(label, style: TextStyle(fontSize: 15, color: c.textMuted))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 15, color: c.text, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

String countLabel(int n, String singular, [String? pluralForm]) => plural(n, singular, pluralForm);
