// §4.4 Quick action sheets: "Vu Marie", "Reporter Marie", "À voir bientôt".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../domain/selectors.dart';
import '../../domain/text.dart';
import '../../ui/feedback.dart';
import '../../ui/forms.dart';
import '../../ui/kit.dart';

Future<void> showMarkSeenSheet(BuildContext context, Contact contact) =>
    showAppSheet(context, title: 'Vu ${contact.name}', builder: (_) => _MarkSeen(contact));

Future<void> showSnoozeSheet(BuildContext context, Contact contact) =>
    showAppSheet(context, title: 'Reporter ${contact.name}', builder: (_) => _Snooze(contact));

Future<void> showSeeSoonSheet(BuildContext context, {required Set<String> excludeIds}) => showAppSheet(
      context,
      title: 'À voir bientôt',
      subtitle:
          "Choisissez quelqu'un à revoir sans attendre la fin de sa période. Il restera en tête de liste jusqu'à votre prochaine rencontre.",
      builder: (_) => _SeeSoon(excludeIds),
    );

class _MarkSeen extends ConsumerStatefulWidget {
  const _MarkSeen(this.contact);
  final Contact contact;
  @override
  ConsumerState<_MarkSeen> createState() => _MarkSeenState();
}

class _MarkSeenState extends ConsumerState<_MarkSeen> {
  DateTime _date = today();
  final _notes = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await guard(
      () => ref.read(apiProvider).logMeeting([widget.contact.id], _date, notes: _notes.text),
      success: 'Rencontre avec ${widget.contact.name} enregistrée',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok != null) {
      refreshData(ref);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LabeledField(
        label: "Quand l'avez-vous vu(e) ?",
        required: true,
        child: DateField(value: _date, last: today(), onChanged: (d) => setState(() => _date = d ?? today())),
      ),
      LabeledField(
        label: 'Une note (facultatif)',
        child: AppTextField(controller: _notes, hint: 'Un souvenir, un détail à retenir…', maxLines: 3),
      ),
      Text(
        "La date de dernière rencontre et la prochaine échéance seront mises à jour automatiquement. La rencontre apparaîtra dans l'historique.",
        style: TextStyle(fontSize: 13, color: c.textMuted, height: 1.35),
      ),
      const SizedBox(height: 16),
      AppButton('Enregistrer la rencontre', icon: LucideIcons.check, size: ButtonSize.lg, full: true, loading: _busy, onPressed: _save),
    ]);
  }
}

class _Snooze extends ConsumerStatefulWidget {
  const _Snooze(this.contact);
  final Contact contact;
  @override
  ConsumerState<_Snooze> createState() => _SnoozeState();
}

class _SnoozeState extends ConsumerState<_Snooze> {
  DateTime? _custom;
  bool _busy = false;

  Future<void> _apply(DateTime until) async {
    setState(() => _busy = true);
    final ok = await guard(() => ref.read(apiProvider).snoozeContact(widget.contact.id, until),
        success: 'Rappel reporté au ${formatDate(until)}');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok != null) {
      refreshData(ref);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = today();
    final options = [
      ('3 jours', addFrequency(t, 3, FrequencyUnit.days)),
      ('1 semaine', addFrequency(t, 1, FrequencyUnit.weeks)),
      ('2 semaines', addFrequency(t, 2, FrequencyUnit.weeks)),
      ('1 mois', addFrequency(t, 1, FrequencyUnit.months)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Me le rappeler plus tard, dans :', style: TextStyle(fontSize: 15, color: c.textMuted)),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3.4,
        children: [
          for (final (label, date) in options)
            AppButton(label, variant: ButtonVariant.secondary, onPressed: _busy ? null : () => _apply(date)),
        ],
      ),
      const SizedBox(height: 18),
      LabeledField(
        label: 'Ou à une date précise',
        child: DateField(value: _custom, first: t, onChanged: (d) => setState(() => _custom = d)),
      ),
      AppButton('Reporter', full: true, loading: _busy, onPressed: _custom == null ? null : () => _apply(_custom!)),
    ]);
  }
}

class _SeeSoon extends ConsumerStatefulWidget {
  const _SeeSoon(this.excludeIds);
  final Set<String> excludeIds;
  @override
  ConsumerState<_SeeSoon> createState() => _SeeSoonState();
}

class _SeeSoonState extends ConsumerState<_SeeSoon> {
  final _q = TextEditingController();
  String? _busyId;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _add(Contact contact) async {
    setState(() => _busyId = contact.id);
    final ok = await guard(() => ref.read(apiProvider).setSeeSoon(contact.id, true),
        success: '${contact.name} ajouté(e) à la liste « à voir bientôt »');
    if (!mounted) return;
    setState(() => _busyId = null);
    if (ok != null) {
      refreshData(ref);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final all = (ref.watch(contactsProvider).value ?? []).where((x) => !widget.excludeIds.contains(x.id)).toList()
      ..sort((a, b) => compareNames(a.name, b.name));
    final shown = all.where((x) => contactMatches(x, _q.text)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SearchField(controller: _q, hint: 'Rechercher un contact…', onChanged: (_) => setState(() {})),
      const SizedBox(height: 8),
      ConstrainedBox(
        constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height * 0.3),
        child: shown.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(all.isEmpty ? 'Tous vos contacts sont déjà dans la liste.' : 'Aucun contact ne correspond.',
                    textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
              )
            : Column(children: [
                for (final x in shown)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    enabled: _busyId == null,
                    leading: Avatar(name: x.name, path: x.photoPath, size: 40),
                    title: Text(x.name, style: TextStyle(fontWeight: FontWeight.w500, color: c.text)),
                    subtitle: x.categoryLabel == null ? null : Text(x.categoryLabel!, style: TextStyle(color: c.textMuted, fontSize: 13)),
                    trailing: _busyId == x.id
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(LucideIcons.star, color: c.tone(Tone.violet).text, size: 20),
                    onTap: () => _add(x),
                  ),
              ]),
      ),
    ]);
  }
}
