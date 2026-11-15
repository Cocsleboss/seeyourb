// §4.12 Historique.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../domain/selectors.dart';
import '../../domain/text.dart';
import '../../ui/forms.dart';
import '../../ui/kit.dart';
import '../../ui/rows.dart';
import '../../ui/scaffold.dart';
import 'calendar.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  RdvStatus? _filter;
  bool _calendar = false;
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final history = ref.watch(historyProvider);
    return AppScaffold(
      title: 'Historique',
      actions: [
        SizedBox(
          width: 104,
          child: SegmentedControl<bool>(
            options: const [(false, 'Liste'), (true, 'Mois')],
            value: _calendar,
            onChanged: (v) => setState(() => _calendar = v),
          ),
        ),
      ],
      body: _calendar
          ? PageList(
              onRefresh: () async => refreshData(ref),
              children: const [SizedBox(height: 8), HistoryCalendar()],
            )
          : AsyncBody(
              value: history,
              onRetry: () => ref.invalidate(historyProvider),
              builder: (all) {
                if (all.isEmpty) {
                  return PageList(
                    children: const [
                      EmptyState(
                        icon: LucideIcons.clock,
                        title: 'Aucune rencontre pour l\'instant',
                        message: 'Les rendez-vous validés ou annulés apparaîtront ici.',
                      ),
                    ],
                  );
                }
                final filtered = all
                    .where((r) => _filter == null || r.status == _filter)
                    .where(
                      (r) => matchesAny([
                        r.title,
                        r.location,
                        ...r.contacts.map((x) => x.name),
                      ], _q.text),
                    )
                    .toList();
                final done = all
                    .where((r) => r.status == RdvStatus.valide)
                    .length;
                final cancelled = all
                    .where((r) => r.status == RdvStatus.annule)
                    .length;
                final months = groupOrdered(
                  filtered,
                  (Rendezvous r) =>
                      DateTime(r.appointmentAt.year, r.appointmentAt.month),
                );
                return PageList(
                  onRefresh: () => ref.refresh(historyProvider.future),
                  children: [
                    const SizedBox(height: 12),
                    SegmentedControl<RdvStatus?>(
                      options: const [
                        (null, 'Tous'),
                        (RdvStatus.valide, 'A eu lieu'),
                        (RdvStatus.annule, 'Annulés'),
                      ],
                      value: _filter,
                      onChanged: (v) => setState(() => _filter = v),
                    ),
                    const SizedBox(height: 12),
                    SearchField(
                      controller: _q,
                      hint: 'Rechercher (contact, titre, lieu)',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${plural(done, 'rencontre')} · ${plural(cancelled, 'annulé')}',
                      style: TextStyle(color: c.textMuted, fontSize: 15),
                    ),
                    if (filtered.isEmpty)
                      const EmptyState(
                        icon: LucideIcons.searchX,
                        title: 'Aucun résultat',
                      )
                    else
                      for (final (month, list) in months) ...[
                        SectionTitle(monthLabel(month), count: list.length),
                        RowsCard(
                          children: [for (final r in list) RdvRow(rdv: r)],
                        ),
                      ],
                  ],
                );
              },
            ),
    );
  }
}
