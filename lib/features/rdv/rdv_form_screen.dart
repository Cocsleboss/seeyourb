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
import '../../core/i18n.dart';

class RdvFormScreen extends ConsumerWidget {
  const RdvFormScreen({super.key, this.editId, this.preselectContactId});
  final String? editId;
  final String? preselectContactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider);
    final rdv = editId == null ? null : ref.watch(rdvProvider(editId!));
    if (rdv != null && rdv.hasValue && rdv.value == null) {
      return MissingItem(title: tr.errRdvNotFound, backLabel: tr.backToHome, backPath: '/');
    }
    final ready = contacts.hasValue && (rdv == null || rdv.hasValue);
    if (!ready) {
      return AppScaffold(
        title: editId == null ? tr.newRdv : tr.editRdv,
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

  /// Edit mode: the status can be changed here too.
  RdvStatus? _status;
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
    _status = e?.status;
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
    if (_selected.isEmpty) return setState(() => _error = tr.chooseOneContact);
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
      status: _editing ? _status : (_done ? RdvStatus.valide : RdvStatus.planifie),
    );
    final saved = await guard(() async {
      if (_editing) return api.updateRdv(widget.existing!.id, input.toJson(), contactIds: _selected.toList());
      return api.createRdv(input, _selected.toList());
    }, success: _editing ? tr.rdvUpdated : (_done ? tr.meetingRecorded : tr.rdvPlanned));

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
        showToast(tr.inviteSendFailed, kind: ToastKind.error);
      } else if (sent > 0) {
        showToast(sent == 1 ? tr.invitationSentTo(friends.first.name) : tr.invitationsSentN(sent));
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
    final placeholderTitle = selected.isEmpty ? tr.titleExample : rdvTitle(null, selected.map((s) => s.name).toList());

    return AppScaffold(
      title: _editing ? tr.editRdv : tr.newRdv,
      back: true,
      bottom: BottomActionBar(
        child: AppButton(
          _editing ? tr.saveChanges : (_done ? tr.saveMeeting : tr.planTheRdv),
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
            label: tr.participants,
            required: true,
            error: _error,
            child: widget.contacts.isEmpty
                ? AppCard(
                    child: Column(children: [
                      Text(tr.createContactFirst,
                          textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
                      const SizedBox(height: 12),
                      AppButton(tr.createAContact, icon: LucideIcons.userPlus, onPressed: () => context.push('/contacts/new')),
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
                            deleteButtonTooltipMessage: tr.removeName(s.name),
                            onDeleted: () => setState(() => _selected.remove(s.id)),
                          ),
                      ]),
                      const SizedBox(height: 10),
                    ],
                    SearchField(controller: _search, hint: tr.searchContact, onChanged: (_) => setState(() {})),
                    const SizedBox(height: 8),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 260),
                        child: shown.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(tr.noMatchingContact, textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
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
                                    subtitle: x.categoryLabel == null ? null : Text(x.categoryLabel!, style: TextStyle(fontSize: 12.5, color: c.textMuted)),
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
                label: tr.date,
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
                label: tr.time,
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
          LabeledField(label: tr.titleOptional, child: AppTextField(controller: _title, hint: placeholderTitle, maxLength: 120)),
          LabeledField(label: tr.placeOptional, child: AppTextField(controller: _location, hint: tr.placeHint, maxLength: 200)),
          LabeledField(
            label: tr.notesOptional,
            hint: tr.notesPrivateHint,
            child: AppTextField(controller: _notes, hint: tr.notesRdvHint, maxLines: 4),
          ),

          if (_editing)
            LabeledField(
              label: tr.status,
              hint: switch (_status) {
                RdvStatus.valide => tr.statusHintDone,
                RdvStatus.annule => tr.statusHintCancelled,
                _ => tr.statusHintPlanned,
              },
              child: SegmentedControl<RdvStatus>(
                options: [for (final s in RdvStatus.values) (s, s.label)],
                value: _status ?? RdvStatus.planifie,
                onChanged: (v) => setState(() => _status = v),
              ),
            ),

          if (!_editing) ...[
            // 5. Already happened: a plain checkbox, the text describes what checking it does
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: CheckboxListTile(
                value: _done,
                activeColor: Palette.brand600,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(tr.alreadyHappened, style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
                subtitle: Text(
                  tr.alreadyHappenedHelp,
                  style: TextStyle(fontSize: 13, color: c.textMuted, height: 1.35),
                ),
                onChanged: (v) => setState(() {
                  _done = v ?? false;
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
                  title: tr.sendTo(joinNames(friends.map((f) => f.name).toList())),
                  subtitle: !_share
                      ? tr.shareOffHelp
                      : _done
                          ? tr.shareDoneHelp
                          : tr.sharePlannedHelp,
                  value: _share,
                  onChanged: (v) => setState(() => _share = v),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(tr.photosAfterSave,
                style: TextStyle(color: c.textMuted, fontSize: 13)),
          ],
        ]),
      ),
    );
  }
}
