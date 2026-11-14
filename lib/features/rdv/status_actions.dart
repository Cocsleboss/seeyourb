// Status buttons: "A eu lieu" / "Annulé", or "Remettre en planifié" (§4.10).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/providers.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../ui/feedback.dart';
import '../../ui/kit.dart';

Future<bool> changeRdvStatus(BuildContext context, WidgetRef ref, Rendezvous rdv, RdvStatus status) async {
  if (status == RdvStatus.valide && rdv.appointmentAt.isAfter(DateTime.now())) {
    final ok = await confirmSheet(
      context,
      title: 'Ce rendez-vous est prévu plus tard',
      message: 'Il est planifié le ${formatDayTime(rdv.appointmentAt)}. Le marquer quand même comme ayant eu lieu ?',
      confirmLabel: 'Oui, il a eu lieu',
      danger: false,
    );
    if (!ok) return false;
  }
  final res = await guard(
    () => ref.read(apiProvider).setRdvStatus(rdv.id, status),
    success: switch (status) {
      RdvStatus.valide => rdv.contacts.isEmpty ? 'Rendez-vous validé' : 'Rendez-vous validé : date de dernière rencontre mise à jour',
      RdvStatus.annule => 'Rendez-vous annulé',
      RdvStatus.planifie => 'Rendez-vous remis en planifié',
    },
  );
  if (res != null) refreshData(ref);
  return res != null;
}

class RdvStatusActions extends ConsumerStatefulWidget {
  const RdvStatusActions({super.key, required this.rdv});
  final Rendezvous rdv;
  @override
  ConsumerState<RdvStatusActions> createState() => _RdvStatusActionsState();
}

class _RdvStatusActionsState extends ConsumerState<RdvStatusActions> {
  RdvStatus? _busy;

  Future<void> _set(RdvStatus s) async {
    setState(() => _busy = s);
    await changeRdvStatus(context, ref, widget.rdv, s);
    if (mounted) setState(() => _busy = null);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rdv.status != RdvStatus.planifie) {
      return Align(
        alignment: Alignment.centerLeft,
        child: AppButton('Remettre en planifié',
            icon: LucideIcons.rotateCcw,
            variant: ButtonVariant.ghost,
            loading: _busy == RdvStatus.planifie,
            onPressed: _busy == null ? () => _set(RdvStatus.planifie) : null),
      );
    }
    return Row(children: [
      Expanded(
        child: AppButton('A eu lieu',
            icon: LucideIcons.check,
            variant: ButtonVariant.success,
            full: true,
            loading: _busy == RdvStatus.valide,
            onPressed: _busy == null ? () => _set(RdvStatus.valide) : null),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: AppButton('Annulé',
            icon: LucideIcons.x,
            variant: ButtonVariant.outline,
            full: true,
            loading: _busy == RdvStatus.annule,
            onPressed: _busy == null ? () => _set(RdvStatus.annule) : null),
      ),
    ]);
  }
}
