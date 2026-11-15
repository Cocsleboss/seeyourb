// §4.9 Nouveau rendez-vous / Modifier le rendez-vous — now an event:
// visibility (privé / entre amis / public), one date or several timeslots,
// my contacts, invitations to friends. Members (not organizer) only edit
// their personal fields (notes, contacts, status).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
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
import '../events/event_widgets.dart';
import '../misc/fallback_screens.dart';

const maxSlots = 10;

class RdvFormScreen extends ConsumerWidget {
  const RdvFormScreen({super.key, this.editId, this.preselectContactId, this.initialVisibility});
  final String? editId;
  final String? preselectContactId;
  final EventVisibility? initialVisibility;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider);
    final rdv = editId == null ? null : ref.watch(rdvProvider(editId!));
    if (rdv != null && rdv.hasValue && rdv.value == null) {
      return MissingItem(title: tr.errRdvNotFound, backLabel: tr.backToHome, backPath: '/');
    }
    final existing = rdv?.value;
    final slots = existing != null && existing.slotsOpen ? ref.watch(slotsProvider(existing.eventId!)) : null;
    final ready = contacts.hasValue && (rdv == null || rdv.hasValue) && (slots == null || slots.hasValue);
    if (!ready) {
      final waiting = contacts.hasError ? contacts : (rdv ?? contacts);
      return AppScaffold(
        title: editId == null ? tr.newRdv : tr.editRdv,
        back: true,
        body: Padding(padding: const EdgeInsets.all(16), child: AsyncBody(value: waiting, builder: (_) => const SizedBox())),
      );
    }
    return _RdvForm(
      contacts: contacts.requireValue,
      existing: existing,
      existingSlots: slots?.value ?? const [],
      preselect: preselectContactId,
      initialVisibility: initialVisibility,
    );
  }
}

class _RdvForm extends ConsumerStatefulWidget {
  const _RdvForm({required this.contacts, this.existing, this.existingSlots = const [], this.preselect, this.initialVisibility});
  final List<Contact> contacts;
  final Rendezvous? existing;
  final List<EventSlot> existingSlots;
  final String? preselect;
  final EventVisibility? initialVisibility;
  @override
  ConsumerState<_RdvForm> createState() => _RdvFormState();
}

class _RdvFormState extends ConsumerState<_RdvForm> {
  late final Set<String> _selected;
  late DateTime _date;
  late TimeOfDay _time;
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _description;
  late final TextEditingController _notes;
  final _search = TextEditingController();
  late EventVisibility _visibility;
  bool _multi = false;
  late List<DateTime> _slots;
  bool _done = false;
  bool _doneTouched = false;
  RdvStatus? _status;
  bool _share = true;
  late bool _guestsCanInvite;
  bool _busy = false;
  String? _error;

  bool get _editing => widget.existing != null;

  /// Shared fields (date, place, visibility…) belong to the organizer.
  bool get _organizer => widget.existing?.isOrganizer ?? true;

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
    _visibility = e?.visibility ?? widget.initialVisibility ?? EventVisibility.private;
    _title = TextEditingController(text: e?.title ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _description = TextEditingController(text: e?.event?.description ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _multi = e?.slotsOpen ?? false;
    _guestsCanInvite = e?.event?.guestsCanInvite ?? true;
    _slots = widget.existingSlots.isNotEmpty
        ? [for (final s in widget.existingSlots) s.startsAt]
        : [at, at.add(const Duration(days: 1))];
  }

  @override
  void dispose() {
    for (final c in [_title, _location, _description, _notes, _search]) {
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

  bool get _contactsRequired => _visibility == EventVisibility.private && _organizer;

  /// "Already happened" only makes sense for a private meetup with one date.
  bool get _canBeDone => !_editing && _visibility == EventVisibility.private && !_multi;

  Future<void> _save() async {
    if (_contactsRequired && _selected.isEmpty) return setState(() => _error = tr.chooseOneContact);
    final slots = (_slots.toSet().toList()..sort());
    if (_multi && slots.length < 2) return setState(() => _error = tr.slotsAtLeastTwo);
    setState(() {
      _error = null;
      _busy = true;
    });
    final api = ref.read(apiProvider);
    final done = _canBeDone && _done;
    final invite = !_editing && _share && _visibility != EventVisibility.public
        ? _friendParticipants.map((f) => f.linkedUserId!).toList()
        : <String>[];
    final input = EventInput(
      rdvId: widget.existing?.id,
      visibility: _visibility,
      title: _title.text,
      location: _location.text,
      description: _visibility == EventVisibility.private ? null : _description.text,
      notes: _notes.text,
      appointmentAt: _multi ? null : (_organizer ? _at : widget.existing!.appointmentAt),
      status: _editing ? (_status ?? RdvStatus.planifie) : (done ? RdvStatus.valide : RdvStatus.planifie),
      slots: _multi ? slots : const [],
      contactIds: _selected.toList(),
      inviteUserIds: invite,
      guestsCanInvite: _guestsCanInvite,
    );
    final id = await guard(
      () => api.saveEvent(input),
      success: _editing
          ? tr.rdvUpdated
          : done
              ? tr.meetingRecorded
              : invite.isEmpty
                  ? tr.rdvPlanned
                  : invite.length == 1
                      ? tr.invitationSentTo(_friendParticipants.first.name)
                      : tr.invitationsSentN(invite.length),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (id == null) return;
    refreshData(ref);
    if (_editing) {
      context.pop();
    } else {
      context.pushReplacement('/rdv/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selected = _selectedContacts;
    final friends = _friendParticipants;
    final shown = (widget.contacts.where((x) => contactMatches(x, _search.text)).toList()..sort((a, b) => compareNames(a.name, b.name)));
    final placeholderTitle = selected.isEmpty ? tr.titleExample : rdvTitle(null, selected.map((s) => s.name).toList());
    final canPublic = ref.watch(canCreatePublicProvider).value ?? false;
    final e = widget.existing;

    return AppScaffold(
      title: _editing ? tr.editRdv : tr.newRdv,
      back: true,
      bottom: BottomActionBar(
        child: AppButton(
          _editing ? tr.saveChanges : (_canBeDone && _done ? tr.saveMeeting : (_multi ? tr.proposeSlots : tr.planTheRdv)),
          size: ButtonSize.lg,
          full: true,
          loading: _busy,
          onPressed: _save,
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: PageList(children: [
          // 0. Who can see it
          if (_organizer)
            LabeledField(
              label: tr.whoCanSee,
              child: VisibilityPicker(
                value: _visibility,
                publicAllowed: canPublic || _visibility == EventVisibility.public,
                onChanged: (v) => setState(() {
                  _visibility = v;
                  if (v == EventVisibility.public) _multi = false;
                }),
              ),
            )
          else if (e != null) ...[
            const SizedBox(height: 12),
            InfoBox(
              tone: Tone.brand,
              child: Text(tr.memberEditHint, style: const TextStyle(fontSize: 13.5)),
            ),
            const SizedBox(height: 4),
          ],

          // 1. My contacts taking part
          LabeledField(
            label: _contactsRequired ? tr.participants : tr.withWhomOptional,
            required: _contactsRequired,
            hint: _visibility == EventVisibility.private || !_organizer ? null : tr.withWhomHint,
            error: _error == tr.chooseOneContact ? _error : null,
            child: widget.contacts.isEmpty
                ? AppCard(
                    child: Column(children: [
                      Text(tr.createContactFirst, textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
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
                                    subtitle: x.categoryLabel == null
                                        ? null
                                        : Text(x.categoryLabel!, style: TextStyle(fontSize: 12.5, color: c.textMuted)),
                                  );
                                },
                              ),
                      ),
                    ),
                  ]),
          ),

          // 2. When: one date or several timeslots (organizer)
          if (_organizer) ...[
            if (_visibility != EventVisibility.public && !(_editing && !_multi && e!.status != RdvStatus.planifie)) ...[
              const SizedBox(height: 16),
              SegmentedControl<bool>(
                options: [(false, tr.oneDate), (true, tr.severalSlots)],
                value: _multi,
                onChanged: (v) => setState(() {
                  _multi = v;
                  _error = null;
                }),
              ),
            ],
            if (_multi)
              _SlotsEditor(
                slots: _slots,
                error: _error == tr.slotsAtLeastTwo ? _error : null,
                onChanged: (v) => setState(() => _slots = v),
              )
            else
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

            // 3. Title, place, description
            LabeledField(label: tr.titleOptional, child: AppTextField(controller: _title, hint: placeholderTitle, maxLength: 120)),
            LabeledField(label: tr.placeOptional, child: AppTextField(controller: _location, hint: tr.placeHint, maxLength: 200)),
            if (_visibility != EventVisibility.private)
              LabeledField(
                label: tr.descriptionLabel,
                hint: tr.descriptionHint,
                child: AppTextField(controller: _description, hint: tr.descriptionPlaceholder, maxLines: 4, maxLength: 2000),
              ),
          ] else if (e != null) ...[
            const SizedBox(height: 16),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.displayTitle, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: c.text)),
                const SizedBox(height: 4),
                Text(e.slotsOpen ? tr.dateToChoose : formatDayTime(e.appointmentAt), style: TextStyle(color: c.textMuted)),
                if (e.location != null) Text(e.location!, style: TextStyle(color: c.textMuted)),
              ]),
            ),
          ],

          // 3b. May guests bring their own friends? (public events: anyone joins anyway)
          if (_organizer && _visibility != EventVisibility.public) ...[
            const SizedBox(height: 16),
            AppCard(
              child: ToggleRow(
                title: tr.guestsCanInvite,
                subtitle: _guestsCanInvite ? null : tr.guestsCanInviteHelp,
                value: _guestsCanInvite,
                onChanged: (v) => setState(() => _guestsCanInvite = v),
              ),
            ),
          ],

          // 4. Private notes
          LabeledField(
            label: tr.notesOptional,
            hint: tr.notesPrivateHint,
            child: AppTextField(controller: _notes, hint: tr.notesRdvHint, maxLines: 4),
          ),

          if (_editing && !(e?.slotsOpen ?? false))
            LabeledField(
              label: tr.status,
              hint: switch (_status) {
                RdvStatus.valide => tr.statusHintDone,
                RdvStatus.annule => _organizer && _visibility != EventVisibility.private ? tr.statusHintCancelledAll : tr.statusHintCancelled,
                _ => tr.statusHintPlanned,
              },
              child: SegmentedControl<RdvStatus>(
                options: [
                  for (final s in RdvStatus.values)
                    if (_organizer || s != RdvStatus.annule || _status == RdvStatus.annule) (s, s.label),
                ],
                value: _status ?? RdvStatus.planifie,
                onChanged: (v) => setState(() => _status = v),
              ),
            ),

          if (!_editing) ...[
            // 5. Already happened (private, one date)
            if (_canBeDone)
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: CheckboxListTile(
                  value: _done,
                  activeColor: Palette.brand600,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr.alreadyHappened, style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
                  subtitle: Text(tr.alreadyHappenedHelp, style: TextStyle(fontSize: 13, color: c.textMuted, height: 1.35)),
                  onChanged: (v) => setState(() {
                    _done = v ?? false;
                    _doneTouched = true;
                  }),
                ),
              ),
            // 6. Invite the friends among my contacts
            if (friends.isNotEmpty && _visibility != EventVisibility.public) ...[
              const SizedBox(height: 12),
              AppCard(
                color: c.brandSoft,
                borderColor: c.isDark ? Palette.brand900 : Palette.brand200,
                child: ToggleRow(
                  title: tr.sendTo(joinNames(friends.map((f) => f.name).toList())),
                  subtitle: !_share
                      ? tr.shareOffHelp
                      : _canBeDone && _done
                          ? tr.shareDoneHelp
                          : _multi
                              ? tr.shareSlotsHelp
                              : tr.sharePlannedHelp,
                  value: _share,
                  onChanged: (v) => setState(() => _share = v),
                ),
              ),
            ],
            if (_visibility == EventVisibility.contacts) ...[
              const SizedBox(height: 12),
              InfoBox(tone: Tone.violet, child: Text(tr.contactsBroadcastHint, style: const TextStyle(fontSize: 13.5))),
            ],
            const SizedBox(height: 12),
            Text(_visibility == EventVisibility.public ? tr.publicPhotosHint : tr.photosAfterSave,
                style: TextStyle(color: c.textMuted, fontSize: 13)),
          ],
        ]),
      ),
    );
  }
}

/// Three cards: private / friends / public (public only for allowed creators).
class VisibilityPicker extends StatelessWidget {
  const VisibilityPicker({super.key, required this.value, required this.onChanged, this.publicAllowed = false});
  final EventVisibility value;
  final ValueChanged<EventVisibility> onChanged;
  final bool publicAllowed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget option(EventVisibility v, String help) {
      final selected = v == value;
      final enabled = v != EventVisibility.public || publicAllowed;
      final t = c.tone(visibilityTone(v));
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            borderColor: selected ? t.solid : null,
            color: selected ? t.bg : null,
            onTap: enabled ? () => onChanged(v) : null,
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: selected ? t.solid : t.bg, shape: BoxShape.circle),
                child: Icon(visibilityIcon(v), size: 19, color: selected ? Colors.white : t.fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(v.label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: c.text)),
                  const SizedBox(height: 2),
                  Text(enabled ? help : tr.publicReserved, style: TextStyle(fontSize: 13, color: c.textMuted, height: 1.3)),
                ]),
              ),
              if (selected) Icon(LucideIcons.circleCheck, color: t.solid),
            ]),
          ),
        ),
      );
    }

    return Column(children: [
      option(EventVisibility.private, tr.visPrivateHelp),
      option(EventVisibility.contacts, tr.visContactsHelp),
      option(EventVisibility.public, tr.visPublicHelp),
    ]);
  }
}

class _SlotsEditor extends StatelessWidget {
  const _SlotsEditor({required this.slots, required this.onChanged, this.error});
  final List<DateTime> slots;
  final ValueChanged<List<DateTime>> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LabeledField(
      label: tr.slotsLabel,
      hint: tr.slotsHint,
      error: error,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < slots.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                flex: 3,
                child: DateField(
                  compact: true,
                  value: dayOf(slots[i]),
                  onChanged: (d) {
                    if (d == null) return;
                    final s = slots[i];
                    onChanged([...slots]..[i] = DateTime(d.year, d.month, d.day, s.hour, s.minute));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TimeField(
                  value: TimeOfDay(hour: slots[i].hour, minute: slots[i].minute),
                  onChanged: (t) {
                    final s = slots[i];
                    onChanged([...slots]..[i] = DateTime(s.year, s.month, s.day, t.hour, t.minute));
                  },
                ),
              ),
              IconButton(
                tooltip: tr.remove,
                onPressed: slots.length <= 2 ? null : () => onChanged([...slots]..removeAt(i)),
                icon: Icon(LucideIcons.x, color: slots.length <= 2 ? c.textSubtle : c.textMuted),
              ),
            ]),
          ),
        if (slots.length < maxSlots)
          AppButton(
            tr.addSlot,
            icon: LucideIcons.plus,
            variant: ButtonVariant.secondary,
            onPressed: () => onChanged([...slots, slots.last.add(const Duration(days: 1))]),
          ),
      ]),
    );
  }
}
