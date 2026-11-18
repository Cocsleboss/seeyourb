// Réglages → Profil public et partage: my profile link (copy, share, QR code),
// the public web page on / off, what it shows, which public events, and
// whether my friends see my city. Saved as soon as touched.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../domain/text.dart';
import '../../ui/feedback.dart';
import '../../ui/forms.dart';
import '../../ui/kit.dart';
import '../../ui/scaffold.dart';
import 'share_profile.dart';

/// My upcoming public events (organized or going): the ones a public profile may list.
List<Rendezvous> myPublicEvents(List<Rendezvous> planned) => planned
    .where((r) => r.eventId != null && r.visibility == EventVisibility.public && r.status == RdvStatus.planifie && (r.rsvp == null || r.rsvp == Rsvp.accepted))
    .toList()
  ..sort((a, b) => a.appointmentAt.compareTo(b.appointmentAt));

class PublicProfileSettingsScreen extends ConsumerStatefulWidget {
  const PublicProfileSettingsScreen({super.key});
  @override
  ConsumerState<PublicProfileSettingsScreen> createState() => _PublicProfileSettingsScreenState();
}

class _PublicProfileSettingsScreenState extends ConsumerState<PublicProfileSettingsScreen> {
  final _busyRdv = <String>{};

  Future<void> _set(Map<String, dynamic> patch) async {
    final p = await guard(() => ref.read(apiProvider).updateProfile(patch));
    if (p != null) ref.read(sessionProvider).setProfile(p);
  }

  Future<void> _toggleField(Profile p, PublicField f, bool on) {
    final next = {...p.publicFields};
    on ? next.add(f) : next.remove(f);
    return _set({'public_fields': [for (final x in PublicField.values) if (next.contains(x)) x.name]});
  }

  Future<void> _showEvent(Rendezvous r, bool show) async {
    setState(() => _busyRdv.add(r.id));
    final ok = await guard(() async {
      await ref.read(apiProvider).setShowOnProfile(r.id, show);
      return true;
    });
    if (!mounted) return;
    setState(() => _busyRdv.remove(r.id));
    if (ok != null) ref.invalidate(plannedRdvProvider);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = ref.watch(profileProvider);
    if (p == null || p.username == null) {
      return AppScaffold(title: tr.publicProfileTitle, back: true, body: const Padding(padding: EdgeInsets.all(16), child: SkeletonList()));
    }
    final on = p.publicProfile;
    final events = myPublicEvents(ref.watch(plannedRdvProvider).value ?? const []);

    Widget fieldRow(PublicField f, String label, IconData icon) => Opacity(
          opacity: on ? 1 : 0.5,
          child: Row(children: [
            Icon(icon, size: 20, color: c.textMuted),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontSize: 15.5, color: c.text))),
            Switch.adaptive(value: p.publicFields.contains(f), onChanged: on ? (v) => _toggleField(p, f, v) : null),
          ]),
        );

    return AppScaffold(
      title: tr.publicProfileTitle,
      back: true,
      body: PageList(children: [
        const SizedBox(height: 8),
        ProfileLinkCard(username: p.username!),
        const SizedBox(height: 10),
        AppButton(tr.previewMyProfile,
            icon: LucideIcons.eye, variant: ButtonVariant.ghost, full: true, onPressed: () => context.push('/u/${p.username}')),

        // Public web page
        const SizedBox(height: 14),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ToggleRow(
              title: tr.publicProfileToggle,
              subtitle: tr.publicProfileToggleSub,
              value: on,
              onChanged: (v) => _set({'public_profile': v}),
            ),
            if (!on) ...[
              const SizedBox(height: 8),
              InfoBox(child: Text(tr.publicProfileOffInfo, style: const TextStyle(fontSize: 13.5))),
            ],
            const Divider(height: 28),
            Text(tr.publicFieldsTitle, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: c.text)),
            const SizedBox(height: 6),
            fieldRow(PublicField.avatar, tr.publicFieldAvatar, LucideIcons.image),
            fieldRow(PublicField.name, tr.publicFieldName, LucideIcons.user),
            fieldRow(PublicField.city, tr.publicFieldCity, LucideIcons.mapPin),
            fieldRow(PublicField.bio, tr.publicFieldBio, LucideIcons.quote),
            const SizedBox(height: 6),
            Text(tr.publicFieldsHelp, style: TextStyle(color: c.textMuted, fontSize: 12.5, height: 1.35)),
          ]),
        ),

        // Public events on it
        SectionTitle(tr.publicEventsTitle),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SegmentedControl<PublicEventsMode>(
              value: p.publicEvents,
              options: [
                (PublicEventsMode.none, tr.publicEventsNone),
                (PublicEventsMode.selected, tr.publicEventsSelected),
                (PublicEventsMode.all, tr.publicEventsAll),
              ],
              onChanged: (v) => _set({'public_events': v.name}),
            ),
            const SizedBox(height: 8),
            Text(tr.publicEventsHelp, style: TextStyle(color: c.textMuted, fontSize: 12.5, height: 1.35)),
            if (p.publicEvents == PublicEventsMode.selected) ...[
              const SizedBox(height: 14),
              Text(tr.publicEventsPick, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: c.text)),
              const SizedBox(height: 4),
              if (events.isEmpty)
                Text(tr.noPublicEventsYet, style: TextStyle(color: c.textMuted, fontSize: 14))
              else
                for (final r in events)
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
                        Text(capitalize(formatDateLong(r.appointmentAt)), style: TextStyle(color: c.textMuted, fontSize: 13)),
                      ]),
                    ),
                    if (_busyRdv.contains(r.id))
                      const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                    else
                      Switch.adaptive(value: r.showOnProfile, onChanged: (v) => _showEvent(r, v)),
                  ]),
            ],
          ]),
        ),

        // In the app
        SectionTitle(tr.inAppVisibilityTitle),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ToggleRow(
              title: tr.friendsSeeCity,
              subtitle: tr.friendsSeeCitySub,
              value: p.friendsSeeCity,
              onChanged: (v) => _set({'friends_see_city': v}),
            ),
            const SizedBox(height: 6),
            Text(tr.inAppVisibilityHelp, style: TextStyle(color: c.textMuted, fontSize: 12.5, height: 1.35)),
          ]),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}
