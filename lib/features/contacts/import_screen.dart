// §4.8 Import de contacts — 3 steps, nothing is saved before the final confirmation.
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/contact_import.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../domain/text.dart';
import '../../ui/feedback.dart';
import '../../ui/forms.dart';
import '../../ui/kit.dart';
import '../../ui/scaffold.dart';

enum _Step { source, review, confirm }

/// Settings chosen for one imported person.
class _Choice {
  _Choice({required this.value, required this.unit, this.category, required this.lastMeeting});
  int value;
  FrequencyUnit unit;
  String? category;
  DateTime lastMeeting;
  _Choice copy() => _Choice(value: value, unit: unit, category: category, lastMeeting: lastMeeting);
}

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});
  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  _Step _step = _Step.source;

  // step 1
  List<ImportedContact>? _phoneBook;
  final Set<String> _picked = {};
  final _q = TextEditingController();
  bool _loading = false;
  bool _denied = false;

  // step 2
  List<ImportedContact> _queue = [];
  int _index = 0;
  final Map<String, _Choice?> _decisions = {}; // null = ignored
  _Choice _current = _Choice(value: 1, unit: FrequencyUnit.months, lastMeeting: today());
  DedupeResult? _dedupe;

  bool _saving = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  /* ------------------------------ step 1 ------------------------------ */

  Future<void> _loadPhoneBook() async {
    setState(() {
      _loading = true;
      _denied = false;
    });
    try {
      final status = await fc.FlutterContacts.permissions.request(fc.PermissionType.read);
      if (status != fc.PermissionStatus.granted && status != fc.PermissionStatus.limited) {
        setState(() => _denied = true);
        return;
      }
      final raw = await fc.FlutterContacts.getAll(
        properties: {fc.ContactProperty.name, fc.ContactProperty.phone, fc.ContactProperty.email, fc.ContactProperty.event, fc.ContactProperty.note},
      );
      var n = 0;
      final list = <ImportedContact>[];
      for (final c in raw) {
        final phone = cleanPhone(c.phones.isEmpty ? null : c.phones.first.number);
        final email = cleanEmail(c.emails.isEmpty ? null : c.emails.first.address);
        final name = (c.displayName ?? '').trim();
        final finalName = name.isNotEmpty ? name : (phone ?? email ?? '');
        if (finalName.isEmpty) continue;
        DateTime? birthday;
        for (final e in c.events) {
          if (e.label.label == fc.EventLabel.birthday && e.year != null) {
            final d = DateTime(e.year!, e.month, e.day);
            if (!d.isAfter(today())) birthday = d;
          }
        }
        final notes = c.notes.map((x) => x.note.trim()).where((x) => x.isNotEmpty).join('\n');
        list.add(ImportedContact(
          key: 'imp-${n++}',
          name: finalName.length > 120 ? finalName.substring(0, 120) : finalName,
          phone: phone,
          email: email,
          birthday: birthday,
          notes: notes.isEmpty ? null : notes,
        ));
      }
      list.sort((a, b) => compareNames(a.name, b.name));
      setState(() => _phoneBook = list);
    } catch (e) {
      showToast('Impossible de lire vos contacts sur cet appareil.', kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startReview() {
    final existing = (ref.read(contactsProvider).value ?? const <Contact>[])
        .map((c) => (name: c.name, phone: c.phone, email: c.email))
        .toList();
    final selected = _phoneBook!.where((c) => _picked.contains(c.key)).toList();
    final res = dedupeImported(selected, existing);
    setState(() {
      _dedupe = res;
      _queue = res.fresh;
      _index = 0;
      _decisions.clear();
      _step = res.fresh.isEmpty ? _Step.source : _Step.review;
    });
    if (res.fresh.isEmpty) showToast('Tous ces contacts sont déjà dans SeeU.', kind: ToastKind.info);
  }

  /* ------------------------------ step 2 ------------------------------ */

  void _decide(bool add) {
    final person = _queue[_index];
    _decisions[person.key] = add ? _current.copy() : null;
    if (_index + 1 >= _queue.length) {
      setState(() => _step = _Step.confirm);
    } else {
      setState(() {
        _index++;
        final next = _decisions[_queue[_index].key];
        if (next != null) _current = next.copy();
      });
    }
  }

  void _back() {
    if (_step == _Step.confirm) return setState(() => _step = _Step.review);
    if (_step == _Step.review && _index > 0) {
      return setState(() {
        _index--;
        final prev = _decisions[_queue[_index].key];
        if (prev != null) _current = prev.copy();
      });
    }
    if (_step == _Step.review) return setState(() => _step = _Step.source);
    context.pop();
  }

  Future<void> _bulk() async {
    final remaining = _queue.length - _index;
    final choice = await showAppSheet<bool>(
      context,
      title: 'Les $remaining restants d\'un coup',
      subtitle: 'Fréquence ${frequencyLabel(_current.value, _current.unit)}${_current.category != null ? ', catégorie ${_current.category}' : ''}, '
          'dernière rencontre le ${formatDate(_current.lastMeeting)}.',
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AppButton('Tout ajouter', icon: LucideIcons.userPlus, full: true, onPressed: () => Navigator.pop(ctx, true)),
        const SizedBox(height: 10),
        AppButton('Tout ignorer et terminer', variant: ButtonVariant.secondary, full: true, onPressed: () => Navigator.pop(ctx, false)),
      ]),
    );
    if (choice == null) return;
    for (var i = _index; i < _queue.length; i++) {
      _decisions[_queue[i].key] = choice ? _current.copy() : null;
    }
    setState(() => _step = _Step.confirm);
  }

  /* ------------------------------ step 3 ------------------------------ */

  List<ImportedContact> get _kept => _queue.where((c) => _decisions[c.key] != null).toList();

  Future<void> _import() async {
    final kept = _kept;
    setState(() => _saving = true);
    final inputs = [
      for (final c in kept)
        ContactInput(
          name: c.name,
          phone: c.phone,
          email: c.email,
          birthday: c.birthday,
          notes: c.notes,
          category: _decisions[c.key]!.category,
          lastMeetingDate: _decisions[c.key]!.lastMeeting,
          frequencyValue: _decisions[c.key]!.value,
          frequencyUnit: _decisions[c.key]!.unit,
        ),
    ];
    final n = await guard(() => ref.read(apiProvider).createContacts(inputs));
    if (!mounted) return;
    setState(() => _saving = false);
    if (n == null) return;
    showToast(n > 1 ? '$n contacts importés' : '$n contact importé');
    refreshData(ref);
    context.go('/contacts');
  }

  /* ------------------------------- build ------------------------------- */

  @override
  Widget build(BuildContext context) {
    final stepNo = _step.index + 1;
    return PopScope(
      canPop: _step == _Step.source,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AppScaffold(
        title: 'Importer des contacts',
        subtitle: 'Étape $stepNo sur 3',
        back: true,
        onBack: _back,
        bottom: _bottom(),
        body: switch (_step) {
          _Step.source => _sourceStep(),
          _Step.review => _reviewStep(),
          _Step.confirm => _confirmStep(),
        },
      ),
    );
  }

  Widget? _bottom() {
    switch (_step) {
      case _Step.source:
        if (_phoneBook == null) return null;
        return BottomActionBar(
          child: AppButton(_picked.isEmpty ? 'Choisissez des contacts' : 'Continuer (${_picked.length})',
              size: ButtonSize.lg, full: true, onPressed: _picked.isEmpty ? null : _startReview),
        );
      case _Step.review:
        return BottomActionBar(
          child: Row(children: [
            Expanded(child: AppButton('Ignorer', variant: ButtonVariant.secondary, size: ButtonSize.lg, full: true, onPressed: () => _decide(false))),
            const SizedBox(width: 10),
            Expanded(child: AppButton('Ajouter', icon: LucideIcons.check, size: ButtonSize.lg, full: true, onPressed: () => _decide(true))),
          ]),
        );
      case _Step.confirm:
        final n = _kept.length;
        return BottomActionBar(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AppButton(n > 1 ? 'Importer $n contacts' : 'Importer $n contact',
                size: ButtonSize.lg, full: true, loading: _saving, onPressed: n == 0 ? null : _import),
            const SizedBox(height: 6),
            AppButton('Revoir la sélection',
                variant: ButtonVariant.ghost,
                full: true,
                onPressed: () => setState(() {
                      _step = _Step.review;
                      _index = 0;
                    })),
          ]),
        );
    }
  }

  Widget _sourceStep() {
    final c = context.colors;
    if (_phoneBook == null) {
      return PageList(children: [
        const SizedBox(height: 12),
        EmptyState(
          icon: LucideIcons.bookUser,
          title: 'Depuis votre carnet d\'adresses',
          message:
              'Choisissez les personnes à suivre dans SeeU. Vous réglerez ensuite la fréquence de chacune. Rien n\'est enregistré avant la confirmation finale.',
          actions: [
            AppButton('Accéder à mes contacts', icon: LucideIcons.bookUser, size: ButtonSize.lg, loading: _loading, onPressed: _loadPhoneBook),
          ],
        ),
        if (_denied)
          InfoBox(
            tone: Tone.amber,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SeeU n\'a pas accès à vos contacts. Autorisez-le dans les réglages du téléphone, puis réessayez.'),
              const SizedBox(height: 8),
              AppButton('Ouvrir les réglages',
                  size: ButtonSize.sm, variant: ButtonVariant.outline, onPressed: () => fc.FlutterContacts.permissions.openSettings()),
            ]),
          ),
      ]);
    }
    final list = _phoneBook!.where((x) => matchesAny([x.name, x.phone, x.email], _q.text)).toList();
    final allPicked = list.isNotEmpty && list.every((x) => _picked.contains(x.key));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: SearchField(controller: _q, hint: 'Rechercher…', onChanged: (_) => setState(() {})),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Expanded(child: Text('${plural(_phoneBook!.length, 'contact')} · ${_picked.length} choisi${_picked.length > 1 ? 's' : ''}',
              style: TextStyle(color: c.textMuted))),
          TextButton(
            onPressed: () => setState(() => allPicked ? _picked.removeAll(list.map((x) => x.key)) : _picked.addAll(list.map((x) => x.key))),
            child: Text(allPicked ? 'Tout désélectionner' : 'Tout sélectionner', style: TextStyle(color: c.brandText)),
          ),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: list.length,
          itemBuilder: (_, i) {
            final x = list[i];
            final on = _picked.contains(x.key);
            return CheckboxListTile(
              value: on,
              activeColor: Palette.brand600,
              onChanged: (_) => setState(() => on ? _picked.remove(x.key) : _picked.add(x.key)),
              secondary: Avatar(name: x.name, size: 40),
              title: Text(x.name, style: TextStyle(fontWeight: FontWeight.w500, color: c.text)),
              subtitle: (x.phone ?? x.email) == null ? null : Text((x.phone ?? x.email)!, style: TextStyle(color: c.textMuted, fontSize: 13)),
            );
          },
        ),
      ),
    ]);
  }

  Widget _reviewStep() {
    final c = context.colors;
    final person = _queue[_index];
    final remaining = _queue.length - _index;
    final presetSelected = frequencyPresets.where((f) => f.value == _current.value && f.unit == _current.unit).firstOrNull;
    return PageList(children: [
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: (_index + 1) / _queue.length,
          minHeight: 6,
          backgroundColor: c.secondaryFill,
          color: Palette.brand600,
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Text('Contact ${_index + 1} sur ${_queue.length}', style: TextStyle(color: c.textMuted)),
        const Spacer(),
        if (_dedupe != null && (_dedupe!.alreadyThere + _dedupe!.duplicates) > 0)
          Text('${_dedupe!.alreadyThere + _dedupe!.duplicates} déjà présent(s) écarté(s)', style: TextStyle(color: c.textSubtle, fontSize: 12.5)),
      ]),
      const SizedBox(height: 14),
      AppCard(
        child: Row(children: [
          Avatar(name: person.name, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(person.name, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: c.text)),
              for (final line in [person.phone, person.email, if (person.birthday != null) 'Né(e) le ${formatDate(person.birthday!)}'])
                if (line != null) Text(line, style: TextStyle(color: c.textMuted, fontSize: 14)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 18),
      LabeledField(
        label: 'Fréquence',
        child: ChipWrap(children: [
          for (final f in frequencyPresets)
            AppChip(f.label,
                selected: presetSelected == f,
                onTap: () => setState(() {
                      _current.value = f.value;
                      _current.unit = f.unit;
                    })),
        ]),
      ),
      LabeledField(
        label: 'Catégorie',
        child: ChipWrap(children: [
          for (final cat in categorySuggestions)
            AppChip(cat, selected: _current.category == cat, onTap: () => setState(() => _current.category = _current.category == cat ? null : cat)),
        ]),
      ),
      LabeledField(
        label: 'Dernière rencontre',
        child: DateField(value: _current.lastMeeting, last: today(), onChanged: (d) => setState(() => _current.lastMeeting = d ?? today())),
      ),
      if (remaining > 1)
        Center(
          child: TextButton(
            onPressed: _bulk,
            child: Text('Les ${remaining - 1} restants d\'un coup…', style: TextStyle(color: c.brandText, fontWeight: FontWeight.w600)),
          ),
        ),
    ]);
  }

  Widget _confirmStep() {
    final c = context.colors;
    final kept = _kept;
    final ignored = _queue.length - kept.length;
    return PageList(children: [
      const SizedBox(height: 8),
      Text(
        kept.isEmpty ? 'Aucun contact retenu.' : '${plural(kept.length, 'contact retenu', 'contacts retenus')}${ignored > 0 ? ' · ${plural(ignored, 'ignoré')}' : ''}',
        style: TextStyle(fontSize: 16, color: c.text, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      if (kept.isNotEmpty)
        RowsCard(children: [
          for (final x in kept)
            ListTile(
              leading: Avatar(name: x.name, size: 40),
              title: Text(x.name, style: TextStyle(fontWeight: FontWeight.w500, color: c.text)),
              subtitle: Text(
                [frequencyLabel(_decisions[x.key]!.value, _decisions[x.key]!.unit), ?_decisions[x.key]!.category].join(' · '),
                style: TextStyle(color: c.textMuted, fontSize: 13),
              ),
              trailing: IconButton(
                tooltip: 'Retirer ${x.name}',
                icon: Icon(LucideIcons.x, color: c.textMuted),
                onPressed: () => setState(() => _decisions[x.key] = null),
              ),
            ),
        ]),
    ]);
  }
}
