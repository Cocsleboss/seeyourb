// §4.9 Nouveau rendez-vous / Modifier le rendez-vous.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../../ui/scaffold.dart';
import '../misc/fallback_screens.dart';

class RdvFormScreen extends ConsumerWidget {
  const RdvFormScreen({super.key, this.editId, this.preselectContactId});
  final String? editId;
  final String? preselectContactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider);
    final rdv = editId == null ? null : ref.watch(rdvProvider(editId!));
    if (rdv != null && rdv.hasValue && rdv.value == null) {
      return const MissingItem(title: 'Rendez-vous introuvable', backLabel: "Retour à l'accueil", backPath: '/');
    }
    final ready = contacts.hasValue && (rdv == null || rdv.hasValue);
    if (!ready) {
      return AppScaffold(
        title: editId == null ? 'Nouveau rendez-vous' : 'Modifier le rendez-vous',
        back: true,
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: AsyncBody(value: contacts.hasError ? contacts : (rdv ?? contacts), builder: (_) => const SizedBox()),
        ),
      );
    }
    return _RdvForm(contacts: contacts.requireValue, existing: rdv?.value, preselect: preselectContactId);
  }
}

class _RdvForm extends ConsumerStatefulWidget {
  const _RdvForm({required this.contacts, this.existing, this.preselect});
  final List<Contact> contacts;
  final Rendezvous? existing;
  final String? preselect;
  @override
  ConsumerState<_RdvForm> createState() => _RdvFormState();
}

class _RdvFormState extends ConsumerState<_RdvForm> {
  late final Set<String> _selected;
  late DateTime _date;
  late TimeOfDay _time;
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _notes;
  final _search = TextEditingController();
  bool _done = false;
  bool _doneTouched = false;
  bool _share = true;
  bool _busy = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _selected = {
      ...?e?.contacts.map((c) => c.id),
      if (widget.preselect != null && widget.contacts.any((c) => c.id == widget.preselect)) widget.preselect!,
    };
    final at = e?.appointmentAt ?? nextQuarterHour();
    _date = dayOf(at);
    _time = TimeOfDay(hour: at.hour, minute: at.minute);
    _title = TextEditingController(text: e?.title ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
  }

  @override
  void dispose() {
    for (final c in [_title, _location, _notes, _search]) {
      c.dispose();
    }
    super.dispose();
  }

  DateTime get _at => DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  void _autoDone() {
    if (!_doneTouched && !_editing) _done = _at.isBefore(DateTime.now());
  }

  List<Contact> get _selectedContacts =>
      widget.contacts.where((c) => _selected.contains(c.id)).toList()..sort((a, b) => compareNames(a.name, b.name));

  List<Contact> get _friendParticipants => _selectedContacts.where((c) => c.linkedUserId != null).toList();

  Future<void> _save() async {
    if (_selected.isEmpty) return setState(() => _error = 'Choisissez au moins un contact.');
    setState(() {
      _error = null;
      _busy = true;
    });
    final api = ref.read(apiProvider);
    final input = RdvInput(
      title: _title.text,
      location: _location.text,
      notes: _notes.text,
      appointmentAt: _at,
      status: _editing ? null : (_done ? RdvStatus.valide : RdvStatus.planifie),
    );
    final saved = await guard(() async {
      if (_editing) return api.updateRdv(widget.existing!.id, input.toJson(), contactIds: _selected.toList());
      return api.createRdv(input, _selected.toList());
    }, success: _editing ? 'Rendez-vous mis à jour' : (_done ? 'Rencontre enregistrée' : 'Rendez-vous planifié'));

    if (saved != null && !_editing && _share) {
      final friends = _friendParticipants;
      var sent = 0;
      for (final f in friends) {
        try {
          await api.sendRdvInvite(saved.id, f.linkedUserId!);
          sent++;
        } catch (_) {}
      }
      if (sent < friends.length) {
        showToast("Une invitation n'a pas pu être envoyée : réessayez depuis le rendez-vous.", kind: ToastKind.error);
      } else if (sent > 0) {
        showToast(sent == 1 ? 'Invitation envoyée à ${friends.first.name}' : 'Invitations envoyées à $sent amis');
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) return;
    refreshData(ref);
    if (_editing) {
      context.pop();
    } else {
      context.pushReplacement('/rdv/${saved.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selected = _selectedContacts;
    final friends = _friendParticipants;
    final shown = (widget.contacts.where((x) => contactMatches(x, _search.text)).toList()..sort((a, b) => compareNames(a.name, b.name)));
    final placeholderTitle = selected.isEmpty ? 'Ex. Déjeuner, café, visio…' : rdvTitle(null, selected.map((s) => s.name).toList());

    return AppScaffold(
      title: _editing ? 'Modifier le rendez-vous' : 'Nouveau rendez-vous',
      back: true,
      bottom: BottomActionBar(
        child: AppButton(
          _editing ? 'Enregistrer les modifications' : (_done ? 'Enregistrer la rencontre' : 'Planifier le rendez-vous'),
          size: ButtonSize.lg,
          full: true,
          loading: _busy,
          onPressed: _save,
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: PageList(children: [
          // 1. Participants
          LabeledField(
            label: 'Participants',
            required: true,
            error: _error,
            child: widget.contacts.isEmpty
                ? AppCard(
                    child: Column(children: [
                      Text("Créez d'abord un contact pour pouvoir planifier un rendez-vous.",
                          textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
                      const SizedBox(height: 12),
                      AppButton('Créer un contact', icon: LucideIcons.userPlus, onPressed: () => context.push('/contacts/new')),
                    ]),
                  )
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (selected.isNotEmpty) ...[
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final s in selected)
                          InputChip(
                            avatar: Avatar(name: s.name, path: s.photoPath, size: 24),
                            label: Text(s.name),
                            labelStyle: TextStyle(color: c.tone(Tone.brand).fg, fontWeight: FontWeight.w500),
                            backgroundColor: c.tone(Tone.brand).bg,
                            side: BorderSide.none,
                            shape: const StadiumBorder(),
                            deleteIcon: Icon(LucideIcons.x, size: 16, color: c.tone(Tone.brand).fg),
                            deleteButtonTooltipMessage: 'Retirer ${s.name}',
                            onDeleted: () => setState(() => _selected.remove(s.id)),
                          ),
                      ]),
                      const SizedBox(height: 10),
                    ],
                    SearchField(controller: _search, hint: 'Rechercher un contact…', onChanged: (_) => setState(() {})),
                    const SizedBox(height: 8),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 260),
                        child: shown.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text('Aucun contact ne correspond.', textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: shown.length,
                                itemBuilder: (_, i) {
                                  final x = shown[i];
                                  final on = _selected.contains(x.id);
                                  return CheckboxListTile(
                                    value: on,
                                    onChanged: (_) => setState(() => on ? _selected.remove(x.id) : _selected.add(x.id)),
                                    controlAffinity: ListTileControlAffinity.trailing,
                                    activeColor: Palette.brand600,
                                    shape: const RoundedRectangleBorder(),
                                    secondary: Avatar(name: x.name, path: x.photoPath, size: 36),
                                    title: Text(x.name, style: TextStyle(fontWeight: FontWeight.w500, color: c.text)),
                                    subtitle: x.category == null ? null : Text(x.category!, style: TextStyle(fontSize: 12.5, color: c.textMuted)),
                                  );
                                },
                              ),
                      ),
                    ),
                  ]),
          ),

          // 2. Date & time
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 3,
              child: LabeledField(
                label: 'Date',
                required: true,
                child: DateField(
                  compact: true,
                  value: _date,
                  onChanged: (d) => setState(() {
                    _date = d ?? _date;
                    _autoDone();
                  }),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: LabeledField(
                label: 'Heure',
                required: true,
                child: TimeField(
                  value: _time,
                  onChanged: (t) => setState(() {
                    _time = t;
                    _autoDone();
                  }),
                ),
              ),
            ),
          ]),

          // 3–4. Title, location, notes
          LabeledField(label: 'Titre (facultatif)', child: AppTextField(controller: _title, hint: placeholderTitle, maxLength: 120)),
          LabeledField(label: 'Lieu (facultatif)', child: AppTextField(controller: _location, hint: 'Café, adresse, visio…', maxLength: 200)),
          LabeledField(
            label: 'Notes (facultatif)',
            hint: 'Toujours privées, même si le rendez-vous est partagé.',
            child: AppTextField(controller: _notes, hint: 'Idées de sujets, à ne pas oublier…', maxLines: 4),
          ),

          if (!_editing) ...[
            // 5. Already happened
            AppCard(
              child: ToggleRow(
                title: 'Ce rendez-vous a déjà eu lieu',
                subtitle: _done
                    ? 'Il sera enregistré comme une rencontre passée : la date de dernière rencontre des participants sera mise à jour.'
                    : 'Il sera planifié : vous recevrez un rappel avant, puis pourrez le valider.',
                value: _done,
                onChanged: (v) => setState(() {
                  _done = v;
                  _doneTouched = true;
                }),
              ),
            ),
            // 6. Send to friends
            if (friends.isNotEmpty) ...[
              const SizedBox(height: 12),
              AppCard(
                color: c.brandSoft,
                borderColor: c.isDark ? Palette.brand900 : Palette.brand200,
                child: ToggleRow(
                  title: 'Envoyer à ${joinNames(friends.map((f) => f.name).toList())}',
                  subtitle: !_share
                      ? "Le rendez-vous reste uniquement chez vous. Vous pourrez l'envoyer plus tard depuis sa fiche."
                      : _done
                          ? "Votre ami recevra cette rencontre : s'il l'accepte, sa période est remise à zéro et vous partagez les photos."
                          : "Votre ami reçoit une invitation : s'il accepte, vous avez tous les deux le rendez-vous et une galerie de photos commune. Vos notes restent privées.",
                  value: _share,
                  onChanged: (v) => setState(() => _share = v),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text('Vous pourrez ajouter des photos une fois le rendez-vous enregistré.',
                style: TextStyle(color: c.textMuted, fontSize: 13)),
          ],
        ]),
      ),
    );
  }
}
