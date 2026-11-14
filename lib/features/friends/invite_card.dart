// Incoming rendezvous invitation card (Home + Friends).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../ui/feedback.dart';
import '../../ui/kit.dart';

class InviteCard extends ConsumerStatefulWidget {
  const InviteCard({super.key, required this.invite});
  final IncomingInvite invite;
  @override
  ConsumerState<InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends ConsumerState<InviteCard> {
  bool? _busy;

  Future<void> _respond(bool accept) async {
    setState(() => _busy = accept);
    final res = await guard(() => ref.read(apiProvider).respondRdvInvite(widget.invite.id, accept),
        success: accept ? 'Rendez-vous ajouté' : 'Invitation refusée');
    if (!mounted) return;
    setState(() => _busy = null);
    refreshData(ref);
    if (accept && res != null) context.push('/rdv/$res');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final i = widget.invite;
    final past = i.rdvStatus == RdvStatus.valide;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar(name: i.fromName, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                past ? '${i.fromName} partage une rencontre avec vous' : '${i.fromName} vous propose un rendez-vous',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.text, height: 1.3),
              ),
              if (i.title != null) ...[
                const SizedBox(height: 4),
                Text(i.title!, style: TextStyle(fontSize: 15.5, color: c.text)),
              ],
              const SizedBox(height: 3),
              Text(formatDayTime(i.appointmentAt), style: TextStyle(fontSize: 15, color: c.textMuted)),
              if (i.location != null) ...[
                const SizedBox(height: 3),
                Row(children: [
                  Icon(LucideIcons.mapPin, size: 16, color: c.textMuted),
                  const SizedBox(width: 4),
                  Expanded(child: Text(i.location!, style: TextStyle(fontSize: 15, color: c.textMuted))),
                ]),
              ],
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: AppButton('Refuser',
                icon: LucideIcons.x,
                variant: ButtonVariant.secondary,
                full: true,
                loading: _busy == false,
                onPressed: _busy == null ? () => _respond(false) : null),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton('Accepter',
                icon: LucideIcons.check, full: true, loading: _busy == true, onPressed: _busy == null ? () => _respond(true) : null),
          ),
        ]),
      ]),
    );
  }
}
