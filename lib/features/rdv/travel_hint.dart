// "Marie habite à Lyon : vous pourriez vous voir pendant votre séjour."
// When an event's place is far from my home (≥ 40 km), the friends and contacts
// living near it. A trip is simply an event there (even private, alone).
//   • TravelHintCard: on the event page, with "Inviter" / "Ajouter"
//   • TravelFormHint: under the place field of the event form
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../ui/feedback.dart';
import '../../ui/kit.dart';

class TravelHintCard extends ConsumerStatefulWidget {
  const TravelHintCard({super.key, required this.rdv});
  final Rendezvous rdv;
  @override
  ConsumerState<TravelHintCard> createState() => _TravelHintCardState();
}

class _TravelHintCardState extends ConsumerState<TravelHintCard> {
  String? _busy;

  Future<void> _add(NearbyPerson p) async {
    final rdv = widget.rdv;
    final api = ref.read(apiProvider);
    setState(() => _busy = p.contactId ?? p.userId);
    final ok = await guard(() async {
      if (p.contactId != null) await api.addContactsToRdv(rdv.id, [p.contactId!]);
      if (p.isFriend && p.userId != null) await api.sendRdvInvite(rdv.id, p.userId!);
      return true;
    }, success: p.isFriend ? tr.invitationSentTo(p.name) : tr.peopleAdded(1));
    if (!mounted) return;
    setState(() => _busy = null);
    if (ok != null) refreshData(ref);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rdv = widget.rdv;
    final e = rdv.event;
    final me = ref.watch(profileProvider);
    if (e?.lat == null || e?.lng == null || me == null || !me.hasHome || rdv.status != RdvStatus.planifie || rdv.rsvp == Rsvp.declined) {
      return const SizedBox.shrink();
    }
    final people = ref.watch(peopleNearProvider((lat: e!.lat!, lng: e.lng!, eventId: rdv.eventId))).value ?? const <NearbyPerson>[];
    if (people.isEmpty) return const SizedBox.shrink();
    final public = rdv.visibility == EventVisibility.public;
    final canInvite = rdv.isOrganizer || (!public && e.guestsCanInvite);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: AppCard(
        color: c.tone(Tone.green).bg,
        borderColor: c.tone(Tone.green).bg,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(LucideIcons.mapPinHouse, color: c.tone(Tone.green).text),
            const SizedBox(width: 8),
            Expanded(
              child: Text(tr.travelCardTitle, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: c.tone(Tone.green).fg)),
            ),
          ]),
          const SizedBox(height: 2),
          Text(tr.travelCardSub, style: TextStyle(fontSize: 13, color: c.tone(Tone.green).fg)),
          const SizedBox(height: 8),
          for (final p in people)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: p.contactId != null
                  ? () => context.push('/contacts/${p.contactId}')
                  : (p.username != null ? () => context.push('/u/${p.username}') : null),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Avatar(name: p.name, size: 36, seeu: p.userId != null, userId: p.userId),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
                      Text(tr.travelRow(p.city ?? '—', '${p.km}'), style: TextStyle(fontSize: 13, color: c.textMuted)),
                    ]),
                  ),
                  if (canInvite && rdv.status == RdvStatus.planifie)
                    AppButton(p.isFriend ? tr.inviteFriend : tr.add,
                        icon: p.isFriend ? LucideIcons.send : LucideIcons.userPlus,
                        size: ButtonSize.sm,
                        variant: ButtonVariant.secondary,
                        loading: _busy == (p.contactId ?? p.userId),
                        onPressed: _busy == null ? () => _add(p) : null),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Under the place field: who lives there (or a nudge to set my city).
class TravelFormHint extends ConsumerWidget {
  const TravelFormHint({super.key, required this.lat, required this.lng, this.eventId});
  final double lat;
  final double lng;
  final String? eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final me = ref.watch(profileProvider);
    if (me == null) return const SizedBox.shrink();
    if (!me.hasHome) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(tr.travelSetCity, style: TextStyle(color: c.textMuted, fontSize: 12.5, height: 1.35)),
      );
    }
    final people = ref.watch(peopleNearProvider((lat: lat, lng: lng, eventId: eventId))).value ?? const <NearbyPerson>[];
    if (people.isEmpty) return const SizedBox.shrink();
    final first = people.first;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InfoBox(
        tone: Tone.green,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(LucideIcons.mapPinHouse, size: 18, color: c.tone(Tone.green).text),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              people.length == 1
                  ? tr.travelFormHint(first.name, first.city ?? '…')
                  : tr.travelFormHintMany(first.name, people.length - 1),
              style: const TextStyle(fontSize: 13.5),
            ),
          ),
        ]),
      ),
    );
  }
}
