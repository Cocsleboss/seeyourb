// §4.5 Liste des contacts.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/selectors.dart';
import '../../domain/text.dart';
import '../../ui/forms.dart';
import '../../ui/kit.dart';
import '../../ui/rows.dart';
import '../../ui/scaffold.dart';

enum _Sort { due, name }

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});
  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _q = TextEditingController();
  String? _category;
  _Sort _sort = _Sort.due;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsProvider);
    return AppScaffold(
      title: 'Contacts',
      actions: [
        AppIconButton(icon: LucideIcons.bookUser, tooltip: 'Importer des contacts', onPressed: () => context.push('/contacts/import')),
        const SizedBox(width: 6),
        AppIconButton(icon: LucideIcons.plus, tooltip: 'Nouveau contact', filled: true, onPressed: () => context.push('/contacts/new')),
      ],
      body: AsyncBody(
        value: contacts,
        onRetry: () => ref.invalidate(contactsProvider),
        builder: (all) => all.isEmpty ? _empty() : _list(all),
      ),
    );
  }

  Widget _empty() => PageList(children: [
        EmptyState(
          icon: LucideIcons.users,
          title: 'Aucun contact pour l\'instant',
          message: 'Ajoutez les personnes que vous voulez revoir régulièrement.',
          actions: [
            AppButton('Ajouter un contact', icon: LucideIcons.userPlus, onPressed: () => context.push('/contacts/new')),
            AppButton('Importer depuis le téléphone',
                icon: LucideIcons.bookUser, variant: ButtonVariant.secondary, onPressed: () => context.push('/contacts/import')),
          ],
        ),
      ]);

  Widget _list(List<Contact> all) {
    final c = context.colors;
    final categories = usedCategories(all);
    final filtered = all.where((x) => (_category == null || x.categories.contains(_category)) && contactMatches(x, _q.text)).toList();
    final overdue = overdueCount(all);

    final sections = <Widget>[];
    if (filtered.isEmpty) {
      sections.add(const EmptyState(icon: LucideIcons.searchX, title: 'Aucun résultat', message: 'Essayez une autre recherche.'));
    } else if (_sort == _Sort.name) {
      final sorted = [...filtered]..sort((a, b) => compareNames(a.name, b.name));
      sections.add(RowsCard(children: [for (final x in sorted) ContactRow(contact: x)]));
    } else {
      final g = groupByDue(filtered);
      for (final (title, list) in [('En retard', g.overdue), ('Cette semaine', g.thisWeek), ('À jour', g.upToDate)]) {
        if (list.isEmpty) continue;
        sections
          ..add(SectionTitle(title, count: list.length, padding: const EdgeInsets.only(top: 18, bottom: 8)))
          ..add(RowsCard(children: [for (final x in list) ContactRow(contact: x)]));
      }
    }

    return RefreshIndicator(
      onRefresh: () => ref.refresh(contactsProvider.future),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32, top: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SearchField(controller: _q, hint: 'Rechercher (nom, catégorie, notes)', onChanged: (_) => setState(() {})),
          ),
          const SizedBox(height: 12),
          if (categories.isNotEmpty)
            ChipRow(children: [
              AppChip('Tous', selected: _category == null, onTap: () => setState(() => _category = null)),
              for (final cat in categories)
                AppChip(cat, selected: _category == cat, onTap: () => setState(() => _category = _category == cat ? null : cat)),
            ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: plural(all.length, 'contact')),
                    if (overdue > 0) ...[
                      const TextSpan(text: ' · '),
                      TextSpan(text: '$overdue en retard', style: TextStyle(color: c.tone(Tone.red).text, fontWeight: FontWeight.w600)),
                    ],
                  ]),
                  style: TextStyle(color: c.textMuted, fontSize: 14.5),
                ),
              ),
              SizedBox(
                width: 180,
                child: SegmentedControl<_Sort>(
                  options: const [(_Sort.due, 'Échéance'), (_Sort.name, 'Nom')],
                  value: _sort,
                  onChanged: (s) => setState(() => _sort = s),
                ),
              ),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0), child: Column(children: sections)),
        ],
      ),
    );
  }
}
