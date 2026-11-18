// §4.7 Nouveau contact / Modifier le contact.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'link_friend_field.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../domain/text.dart';
import '../../ui/feedback.dart';
import '../../ui/forms.dart';
import '../../ui/kit.dart';
import '../../ui/pickers.dart';
import '../../domain/selectors.dart';
import '../../ui/scaffold.dart';
import '../../maps/place_field.dart';
import '../misc/fallback_screens.dart';
import '../photos/photo_section.dart';
import '../../core/i18n.dart';

/// Values to prefill a new contact (e.g. from a SeeU friend).
class ContactPrefill {
  const ContactPrefill(
      {this.name,
      this.email,
      this.linkedUserId,
      this.linkedUsername,
      this.frequencyValue,
      this.frequencyUnit,
      this.categories,
      this.birthday,
      this.city,
      this.country,
      this.request});
  final DateTime? birthday;
  final String? city;
  final String? country;

  /// Someone seen on SeeU who isn't a friend yet: a request is sent with the card.
  final FriendLinkChoice? request;
  final String? name;
  final String? email;
  final String? linkedUserId;
  final String? linkedUsername;
  final int? frequencyValue;
  final FrequencyUnit? frequencyUnit;
  final List<String>? categories;
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
      return MissingItem(title: tr.contactNotFound, backLabel: tr.seeMyContacts, backPath: '/contacts');
    }
    if (!value.hasValue) {
      return AppScaffold(
        title: tr.editContact,
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
  late final TextEditingController _city;
  String? _country;
  double? _lat;
  double? _lng;
  late List<String> _categories;
  DateTime? _lastMeeting;
  late int _freqValue;
  late FrequencyUnit _freqUnit;
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
    _city = TextEditingController(text: e?.city ?? p?.city ?? '');
    _country = e?.country ?? p?.country;
    _lat = e?.lat;
    _lng = e?.lng;
    _link = p?.request;
    _categories = [...?(e?.categories ?? p?.categories)];
    _lastMeeting = e?.lastMeetingDate;
    _freqValue = e?.frequencyValue ?? p?.frequencyValue ?? 1;
    _freqUnit = e?.frequencyUnit ?? p?.frequencyUnit ?? FrequencyUnit.never; // new contacts: no recurring reminder by default
    _birthday = e?.birthday ?? p?.birthday;
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _notes, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _nameError => _name.text.trim().isEmpty ? tr.nameRequired : null;
  String? get _freqError => _freqValue < 1 ? tr.frequencyMin : null;
  String? get _emailError => _email.text.trim().isNotEmpty && !isValidEmail(_email.text) ? tr.errInvalidEmail : null;

  Future<void> _pickPhoto() async {
    final files = await pickPhotos(context, multiple: false);
    if (files.isEmpty) return;
    final bytes = await files.first.readAsBytes();
    setState(() {
      _newPhoto = bytes;
      _removePhoto = false;
    });
  }

  /// New contact: SeeU friend to link now, or someone to send a request to.
  FriendLinkChoice? _link;

  /// The SeeU account this card is (or will be) linked to.
  String? get _linkedUserId =>
      widget.existing?.linkedUserId ?? widget.prefill?.linkedUserId ?? (_link?.isFriend == true ? _link!.userId : null);

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (_nameError != null || _freqError != null || _emailError != null) return;
    setState(() => _busy = true);
    final api = ref.read(apiProvider);
    final input = ContactInput(
      name: _name.text,
      categories: _categories,
      phone: _phone.text,
      email: _email.text.trim().toLowerCase(),
      birthday: _birthday,
      notes: _notes.text,
      lastMeetingDate: _lastMeeting,
      frequencyValue: _freqValue,
      frequencyUnit: _freqUnit,
      linkedUserId: widget.prefill?.linkedUserId ?? (_link?.isFriend == true ? _link!.userId : null),
      city: _city.text,
      country: _city.text.trim().isEmpty ? null : _country,
      lat: _city.text.trim().isEmpty ? null : _lat,
      lng: _city.text.trim().isEmpty ? null : _lng,
    );
    final request = widget.existing == null && _link != null && !_link!.isFriend ? _link : null;
    final existing = widget.existing;
    final saved = await guard(() async {
      var contact = existing == null ? await api.createContact(input) : await api.updateContact(existing.id, input.toJson());
      if (_newPhoto != null || (_removePhoto && contact.photoPath != null)) {
        contact = await api.setContactPhoto(contact, _removePhoto ? null : _newPhoto);
      }
      // Not friends yet: the request is tied to this new contact (linked on accept).
      if (request?.username != null) await api.sendFriendRequest(request!.username!, contactId: contact.id);
      return contact;
    }, success: existing == null ? tr.contactAdded : tr.contactUpdated);
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
    final start = _lastMeeting ?? widget.existing?.addedOn ?? today();
    final next = addFrequency(start, _freqValue < 1 ? 1 : _freqValue, _freqUnit);

    return AppScaffold(
      title: widget.existing == null ? tr.newContact : tr.editContact,
      back: true,
      bottom: BottomActionBar(
        child: AppButton(widget.existing == null ? tr.addTheContact : tr.save,
            size: ButtonSize.lg, full: true, loading: _busy, onPressed: _save),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: PageList(children: [
          // Created from a SeeU friend: say it clearly.
          if (widget.existing == null && widget.prefill?.linkedUserId != null) ...[
            const SizedBox(height: 8),
            InfoBox(
              tone: Tone.brand,
              child: Row(children: [
                Icon(LucideIcons.heartHandshake, size: 20, color: c.brandText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr.contactFromFriendBanner(
                        '${widget.prefill!.name ?? ''}${widget.prefill!.linkedUsername == null ? '' : ' (${handle(widget.prefill!.linkedUsername)})'}'),
                    style: const TextStyle(fontSize: 13.5, height: 1.35),
                  ),
                ),
              ]),
            ),
          ],
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
                      seeu: (widget.existing?.linkedUserId ?? widget.prefill?.linkedUserId) != null,
                      userId: widget.existing?.linkedUserId ?? widget.prefill?.linkedUserId,
                    ),
            ),
            const SizedBox(width: 14),
            if (!hasPhoto)
              AppButton(tr.photoAdd, icon: LucideIcons.camera, variant: ButtonVariant.secondary, size: ButtonSize.sm, onPressed: _pickPhoto)
            else ...[
              AppButton(tr.change, variant: ButtonVariant.secondary, size: ButtonSize.sm, onPressed: _pickPhoto),
              const SizedBox(width: 8),
              AppButton(tr.remove,
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
            label: tr.name,
            required: true,
            error: _submitted ? _nameError : null,
            child: AppTextField(
              controller: _name,
              hint: tr.nameHintFull,
              maxLength: 120,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
            ),
          ),

          // SeeU friend (new contact; existing ones are linked from their page)
          if (widget.existing == null && widget.prefill?.linkedUserId == null)
            LabeledField(
              label: tr.seeuFriend,
              hint: tr.contactLinkHint,
              child: LinkFriendField(value: _link, onChanged: (v) => setState(() => _link = v)),
            ),

          LabeledField(
            label: tr.categories,
            hint: tr.categoriesHint,
            child: CategoryPicker(
              selected: _categories,
              known: usedCategories(ref.watch(contactsProvider).value ?? const []),
              onChanged: (v) => setState(() => _categories = v),
            ),
          ),

          LabeledField(
            label: tr.lastMeeting,
            hint: _lastMeeting == null ? tr.lastMeetingOptional : null,
            child: DateField(
              value: _lastMeeting,
              last: today(),
              clearable: true,
              placeholder: tr.noMeetingRecorded,
              onChanged: (d) => setState(() => _lastMeeting = d),
            ),
          ),

          LabeledField(
            label: tr.frequency,
            required: true,
            error: _submitted ? _freqError : null,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              FrequencyPicker(
                value: _freqValue,
                unit: _freqUnit,
                onChanged: (v, u) => setState(() {
                  _freqValue = v;
                  _freqUnit = u;
                }),
              ),
              const SizedBox(height: 10),
              InfoBox(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: frequencyLabel(_freqValue < 1 ? 1 : _freqValue, _freqUnit), style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (_freqUnit != FrequencyUnit.never) TextSpan(text: ' · ${tr.nextDueInline(formatDateLong(next))}'),
                ])),
              ),
            ]),
          ),

          LabeledField(
            label: tr.phone,
            child: AppTextField(
              controller: _phone,
              hint: tr.phoneHint,
              keyboardType: TextInputType.phone,
              maxLength: 40,
              autofillHints: const [AutofillHints.telephoneNumber],
            ),
          ),
          LabeledField(
            label: tr.emailLabel,
            error: _submitted ? _emailError : null,
            child: AppTextField(
              controller: _email,
              hint: tr.emailExample,
              keyboardType: TextInputType.emailAddress,
              maxLength: 120,
              onChanged: (_) => setState(() {}),
            ),
          ),
          LabeledField(
            label: tr.birthday,
            child: DateField(value: _birthday, last: today(), clearable: true, onChanged: (d) => setState(() => _birthday = d)),
          ),
          // A SeeU friend: their own city (from their account), not editable here.
          if (_linkedUserId != null)
            LabeledField(
              label: tr.contactCityLabel,
              icon: LucideIcons.mapPin,
              hint: tr.friendCityHelp,
              child: _FriendCity(userId: _linkedUserId!),
            )
          else
          LabeledField(
            label: tr.contactCityLabel,
            icon: LucideIcons.mapPin,
            hint: tr.contactCityHelp,
            child: PlaceField(
              cities: true,
              controller: _city,
              lat: _lat,
              lng: _lng,
              hint: tr.cityHint,
              onPlace: (p) => setState(() {
                _lat = p?.lat;
                _lng = p?.lng;
                _country = p?.country;
                if (p?.city != null) _city.text = p!.city!;
              }),
            ),
          ),
          LabeledField(
            label: tr.notes,
            child: AppTextField(controller: _notes, hint: tr.notesHint, maxLines: 5),
          ),
          Text(tr.requiredFields, style: TextStyle(color: c.textMuted, fontSize: 12.5)),
        ]),
      ),
    );
  }
}



/// Read-only city of a SeeU friend (as they share it with friends).
class _FriendCity extends ConsumerWidget {
  const _FriendCity({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final city = ref.watch(friendCityProvider(userId));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(color: c.secondaryFill, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(LucideIcons.lock, size: 16, color: c.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: city.isLoading && !city.hasValue
              ? Text('…', style: TextStyle(color: c.textMuted))
              : Text(city.value ?? tr.friendNoCity,
                  style: TextStyle(fontSize: 15.5, color: city.value == null ? c.textMuted : c.text)),
        ),
      ]),
    );
  }
}
