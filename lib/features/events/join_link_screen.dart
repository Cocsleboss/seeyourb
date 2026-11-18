// /j/:token — an invitation link (https://<site>/j/<token> or seeu://app/j/<token>).
// Shows the event, then "Je viens" / "À confirmer" (or the availability when
// timeslots are open). Already in: my own copy (/rdv/:id) takes over.
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
import '../../maps/maps.dart';
import '../../ui/feedback.dart';
import '../../ui/kit.dart';
import '../../ui/scaffold.dart';
import '../misc/fallback_screens.dart';
import 'event_widgets.dart';

final eventByLinkProvider = FutureProvider.autoDispose.family<LinkedEvent?, String>((ref, token) => ref.watch(apiProvider).eventByLink(token));

class JoinLinkScreen extends ConsumerWidget {
  const JoinLinkScreen({super.key, required this.token});
  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(eventByLinkProvider(token));
    if (value.hasValue && value.value == null) {
      return MissingItem(title: tr.linkInvalidTitle, backLabel: tr.backToHome, backPath: '/');
    }
    final e = value.value;
    if (e != null && e.joined) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.pushReplacement('/rdv/${e.myRdvId}');
      });
    }
    return AppScaffold(
      title: e?.displayTitle ?? tr.rdvGeneric,
      back: true,
      body: e == null
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: AsyncBody(value: value, onRetry: () => ref.invalidate(eventByLinkProvider(token)), builder: (_) => const SizedBox()),
            )
          : _Body(token: token, event: e),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.token, required this.event});
  final String token;
  final LinkedEvent event;
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  Rsvp? _busy;

  Future<void> _join(Rsvp answer) async {
    setState(() => _busy = answer);
    final id = await guard(() => ref.read(apiProvider).joinByLink(widget.token, answer),
        success: widget.event.slotsOpen ? null : (answer == Rsvp.accepted ? tr.joinedToast : tr.rsvpToastPending));
    if (!mounted) return;
    setState(() => _busy = null);
    if (id == null) return;
    refreshData(ref);
    context.pushReplacement('/rdv/$id');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final e = widget.event;
    final cancelled = e.status == RdvStatus.annule;
    return PageList(
      onRefresh: () => ref.refresh(eventByLinkProvider(widget.token).future),
      children: [
        const SizedBox(height: 8),
        InfoBox(
          tone: Tone.brand,
          child: Row(children: [
            Icon(LucideIcons.link, size: 18, color: c.brandText),
            const SizedBox(width: 10),
            Expanded(
              child: Text(e.sharedByName == null ? tr.invitedByLinkOf(e.organizerName) : tr.invitedByLinkOf(e.sharedByName!),
                  style: const TextStyle(fontSize: 14, height: 1.35)),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              VisibilityPill(e.visibility),
              if (cancelled) StatusPill(e.status),
            ]),
            const SizedBox(height: 14),
            Text(e.displayTitle, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: c.text, height: 1.2)),
            const SizedBox(height: 10),
            Row(children: [
              Icon(e.slotsOpen ? LucideIcons.calendarClock : LucideIcons.calendar, size: 20, color: c.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(e.slotsOpen ? tr.dateConfirmedBy(e.organizerName) : capitalize(formatDayTime(e.startsAt)),
                    style: TextStyle(fontSize: 16, color: c.text)),
              ),
            ]),
            if (e.location != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(LucideIcons.mapPin, size: 20, color: c.textMuted),
                const SizedBox(width: 8),
                Expanded(child: Text(e.location!, style: TextStyle(fontSize: 16, color: c.text))),
              ]),
            ],
            if (e.lat != null && e.lng != null) ...[
              const SizedBox(height: 12),
              PlaceMapCard(lat: e.lat!, lng: e.lng!, label: e.location ?? e.displayTitle),
            ],
            if (e.link != null) ...[
              const SizedBox(height: 8),
              EventLinkRow(e.link!),
            ],
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: e.organizerUsername == null ? null : () => context.push('/u/${e.organizerUsername}'),
              child: Row(children: [
                Avatar(name: e.organizerName, size: 36, userId: e.organizerId),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr.organizedBy(e.organizerName), style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
                    if (e.organizerUsername != null) Text(handle(e.organizerUsername), style: TextStyle(color: c.textMuted, fontSize: 13.5)),
                  ]),
                ),
                Pill(tr.nGoing(e.going), icon: LucideIcons.users),
              ]),
            ),
            if (e.description != null) ...[
              const SizedBox(height: 14),
              Text(e.description!, style: TextStyle(fontSize: 15, color: c.text, height: 1.45)),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        if (e.removed)
          InfoBox(tone: Tone.red, child: Text(tr.removedFromEventInfo))
        else if (cancelled)
          InfoBox(tone: Tone.red, child: Text(tr.eventCancelledInfo))
        else if (e.isMine)
          InfoBox(child: Text(tr.yourOwnEvent))
        else ...[
          Text(e.slotsOpen ? tr.joinToVote : tr.areYouComing, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: c.text)),
          const SizedBox(height: 10),
          if (e.slotsOpen)
            AppButton(tr.giveAvailability,
                icon: LucideIcons.calendarClock,
                full: true,
                size: ButtonSize.lg,
                loading: _busy != null,
                onPressed: _busy == null ? () => _join(Rsvp.pending) : null)
          else ...[
            AppButton(tr.imGoing,
                icon: LucideIcons.check,
                full: true,
                size: ButtonSize.lg,
                loading: _busy == Rsvp.accepted,
                onPressed: _busy == null ? () => _join(Rsvp.accepted) : null),
            const SizedBox(height: 8),
            AppButton(tr.rsvpPending,
                icon: LucideIcons.circleHelp,
                variant: ButtonVariant.secondary,
                full: true,
                loading: _busy == Rsvp.pending,
                onPressed: _busy == null ? () => _join(Rsvp.pending) : null),
          ],
          const SizedBox(height: 8),
          Text(tr.joinByLinkHint(e.organizerName), style: TextStyle(fontSize: 13, color: c.textMuted, height: 1.35)),
        ],
      ],
    );
  }
}
