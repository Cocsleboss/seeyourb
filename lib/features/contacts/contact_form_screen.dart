// §4.7 Nouveau contact / Modifier le contact.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../domain/text.dart';
import '../../ui/feedback.dart';
import '../../ui/forms.dart';
import '../../ui/kit.dart';
import '../../ui/scaffold.dart';
import '../misc/fallback_screens.dart';
import '../photos/photo_section.dart';

/// Values to prefill a new contact (e.g. from a SeeU friend).
class ContactPrefill {
  const ContactPrefill({this.name, this.email, this.linkedUserId});
  final String? name;
  final String? email;
  final String? linkedUserId;
}

class ContactFormScreen extends ConsumerWidget {
  const ContactFormScreen({super.key, this.editId, this.prefill});
  final String? editId;
  final ContactPrefill? prefill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (editId == null) return _ContactForm(prefill: prefill);
    final value = ref.watch(contactProvider(editId!));
    if (value.hasValue && value.value == null) {
      return const MissingItem(title: 'Contact introuvable', backLabel: 'Voir mes contacts', backPath: '/contacts');
    }
    if (!value.hasValue) {
      return AppScaffold(
        title: 'Modifier le contact',
        back: true,
        body: Padding(
            padding: const EdgeInsets.all(16),
            child: AsyncBody(value: value, onRetry: () => ref.invalidate(contactsProvider), builder: (_) => const SizedBox())),
      );
    }
    return _ContactForm(existing: value.value);
  }
}

class _ContactForm extends ConsumerStatefulWidget {
  const _ContactForm({this.existing, this.prefill});
  final Contact? existing;
  final ContactPrefill? prefill;
  @override
  ConsumerState<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends ConsumerState<_ContactForm> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _notes;
  late final TextEditingController _customCategory;
  late final TextEditingController _customValue;
  String? _category;
  bool _otherCategory = false;
  late DateTime _lastMeeting;
  late int _freqValue;
  late FrequencyUnit _freqUnit;
  bool _customFreq = false;
  DateTime? _birthday;

  // photo: null = unchanged; _removePhoto = remove
  Uint8List? _newPhoto;
  bool _removePhoto = false;

  bool _busy = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final p = widget.prefill;
    _name = TextEditingController(text: e?.name ?? p?.name ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _email = TextEditingController(text: e?.email ?? p?.email ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _category = e?.category;
    _otherCategory = _category != null && !categorySuggestions.contains(_category);
    _customCategory = TextEditingController(text: _otherCategory ? _category : '');
    _lastMeeting = e?.lastMeetingDate ?? today();
    _freqValue = e?.frequencyValue ?? 1;
    _freqUnit = e?.frequencyUnit ?? FrequencyUnit.months;
    _customFreq = e != null && !frequencyPresets.any((f) => f.value == _freqValue && f.unit == _freqUnit);
    _customValue = TextEditingController(text: '$_freqValue');
    _birthday = e?.birthday;
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _notes, _customCategory, _customValue]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _nameError => _name.text.trim().isEmpty ? 'Le nom est obligatoire.' : null;
  String? get _freqError => _freqValue < 1 ? 'La fréquence doit être d\'au moins 1.' : null;
  String? get _emailError => _email.text.trim().isNotEmpty && !isValidEmail(_email.text) ? 'Adresse email invalide.' : null;

  Future<void> _pickPhoto() async {
    final files = await pickPhotos(context, multiple: false);
    if (files.isEmpty) return;
    final bytes = await files.first.readAsBytes();
    setState(() {
      _newPhoto = bytes;
      _removePhoto = false;
    });
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (_nameError != null || _freqError != null || _emailError != null) return;
    setState(() => _busy = true);
    final api = ref.read(apiProvider);
    final input = ContactInput(
      name: _name.text,
      category: _otherCategory ? _customCategory.text : _category,
      phone: _phone.text,
      email: _email.text.trim().toLowerCase(),
      birthday: _birthday,
      notes: _notes.text,
      lastMeetingDate: _lastMeeting,
      frequencyValue: _freqValue,
      frequencyUnit: _freqUnit,
      linkedUserId: widget.prefill?.linkedUserId,
    );
    final existing = widget.existing;
    final saved = await guard(() async {
      var contact = existing == null ? await api.createContact(input) : await api.updateContact(existing.id, input.toJson());
      if (_newPhoto != null || (_removePhoto && contact.photoPath != null)) {
        contact = await api.setContactPhoto(contact, _removePhoto ? null : _newPhoto);
      }
      return contact;
    }, success: existing == null ? 'Contact ajouté' : 'Contact mis à jour');
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == null) return;
    refreshData(ref);
    if (existing == null) {
      context.pushReplacement('/contacts/${saved.id}');
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasPhoto = _newPhoto != null || (!_removePhoto && widget.existing?.photoPath != null);
    final next = addFrequency(_lastMeeting, _freqValue < 1 ? 1 : _freqValue, _freqUnit);

    return AppScaffold(
      title: widget.existing == null ? 'Nouveau contact' : 'Modifier le contact',
      back: true,
      bottom: BottomActionBar(
        child: AppButton(widget.existing == null ? 'Ajouter le contact' : 'Enregistrer',
            size: ButtonSize.lg, full: true, loading: _busy, onPressed: _save),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: PageList(children: [
          // Photo
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(
              width: 76,
              height: 76,
              child: _newPhoto != null
                  ? ClipOval(child: Image.memory(_newPhoto!, fit: BoxFit.cover))
                  : Avatar(
                      name: _name.text.isEmpty ? '?' : _name.text,
                      path: _removePhoto ? null : widget.existing?.photoPath,
                      size: 76,
                    ),
            ),
            const SizedBox(width: 14),
            if (!hasPhoto)
              AppButton('Ajouter une photo', icon: LucideIcons.camera, variant: ButtonVariant.secondary, size: ButtonSize.sm, onPressed: _pickPhoto)
            else ...[
              AppButton('Changer', variant: ButtonVariant.secondary, size: ButtonSize.sm, onPressed: _pickPhoto),
              const SizedBox(width: 8),
              AppButton('Retirer',
                  variant: ButtonVariant.ghost,
                  size: ButtonSize.sm,
                  onPressed: () => setState(() {
                        _newPhoto = null;
                        _removePhoto = true;
                      })),
            ],
          ]),
          const SizedBox(height: 20),

          LabeledField(
            label: 'Nom',
            required: true,
            error: _submitted ? _nameError : null,
            child: AppTextField(
              controller: _name,
              hint: 'Ex. Marie Dupont',
              maxLength: 120,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
            ),
          ),

          LabeledField(
            label: 'Catégorie',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ChipWrap(children: [
                for (final cat in categorySuggestions)
                  AppChip(cat,
                      selected: !_otherCategory && _category == cat,
                      onTap: () => setState(() {
                            _otherCategory = false;
                            _category = _category == cat ? null : cat;
                          })),
                AppChip('Autre…',
                    selected: _otherCategory,
                    onTap: () => setState(() {
                          _otherCategory = !_otherCategory;
                          if (!_otherCategory) _customCategory.clear();
                        })),
              ]),
              if (_otherCategory) ...[
                const SizedBox(height: 10),
                AppTextField(controller: _customCategory, hint: 'Ex. Voisins, Sport…', maxLength: 40, autofocus: true),
              ],
            ]),
          ),

          LabeledField(
            label: 'Dernière rencontre',
            required: true,
            child: DateField(value: _lastMeeting, last: today(), onChanged: (d) => setState(() => _lastMeeting = d ?? today())),
          ),

          LabeledField(
            label: 'Fréquence',
            required: true,
            error: _submitted ? _freqError : null,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ChipWrap(children: [
                for (final f in frequencyPresets)
                  AppChip(f.label,
                      selected: !_customFreq && f.value == _freqValue && f.unit == _freqUnit,
                      onTap: () => setState(() {
                            _customFreq = false;
                            _freqValue = f.value;
                            _freqUnit = f.unit;
                            _customValue.text = '${f.value}';
                          })),
                AppChip('Personnalisée', selected: _customFreq, onTap: () => setState(() => _customFreq = true)),
              ]),
              if (_customFreq) ...[
                const SizedBox(height: 10),
                Row(children: [
                  SizedBox(
                    width: 90,
                    child: AppTextField(
                      controller: _customValue,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      onChanged: (v) => setState(() => _freqValue = int.tryParse(v) ?? 0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppDropdown<FrequencyUnit>(
                      value: _freqUnit,
                      items: [for (final u in FrequencyUnit.values) (u, unitLabel(u, _freqValue))],
                      onChanged: (u) => setState(() => _freqUnit = u),
                    ),
                  ),
                ]),
              ],
              const SizedBox(height: 10),
              InfoBox(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: frequencyLabel(_freqValue < 1 ? 1 : _freqValue, _freqUnit), style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: ' · Prochaine échéance : ${formatDateLong(next)}'),
                ])),
              ),
            ]),
          ),

          LabeledField(
            label: 'Téléphone',
            child: AppTextField(
              controller: _phone,
              hint: 'Ex. 06 12 34 56 78',
              keyboardType: TextInputType.phone,
              maxLength: 40,
              autofillHints: const [AutofillHints.telephoneNumber],
            ),
          ),
          LabeledField(
            label: 'Email',
            error: _submitted ? _emailError : null,
            child: AppTextField(
              controller: _email,
              hint: 'Ex. marie@exemple.com',
              keyboardType: TextInputType.emailAddress,
              maxLength: 120,
              onChanged: (_) => setState(() {}),
            ),
          ),
          LabeledField(
            label: 'Anniversaire',
            child: DateField(value: _birthday, last: today(), clearable: true, onChanged: (d) => setState(() => _birthday = d)),
          ),
          LabeledField(
            label: 'Notes',
            child: AppTextField(controller: _notes, hint: 'Centres d\'intérêt, enfants, dernier sujet abordé…', maxLines: 5),
          ),
          Text('* champs obligatoires', style: TextStyle(color: c.textMuted, fontSize: 12.5)),
        ]),
      ),
    );
  }
}

