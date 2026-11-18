// A SeeU friend without a contact card. Two mini tabs:
//   • Lier: attach them to one of my existing contacts (suggestions + search)
//   • Créer: a new contact in one tap (how often + category), or the full form
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
import '../../ui/rows.dart';
import '../contacts/contact_form_screen.dart';

const _quickPresets = [
  FrequencyPreset(1, FrequencyUnit.never), // default: no recurring reminder
  FrequencyPreset(1, FrequencyUnit.weeks),
  FrequencyPreset(2, FrequencyUnit.weeks),
  FrequencyPreset(1, FrequencyUnit.months),
  FrequencyPreset(3, FrequencyUnit.months),
];

enum _Tab { link, create }

/// Same first name (accents / case ignored).
bool friendMatchesContact(Friend f, Contact c) {
  final a = normalizeText(f.displayName.split(RegExp(r'\s+')).first);
  return a.isNotEmpty && normalizeText(c.name.split(RegExp(r'\s+')).first) == a;
}

class FriendToContactCard extends ConsumerStatefulWidget {
  const FriendToContactCard({super.key, required this.friend});
  final Friend friend;
  @override
  ConsumerState<FriendToContactCard> createState() => _FriendToContactCardState();
}

class _FriendToContactCardState extends ConsumerState<FriendToContactCard> {
  _Tab? _tab;
  FrequencyPreset _freq = _quickPresets[0];
  String? _category;
  DateTime? _birthday;
  final _q = TextEditingController();
  String? _busy;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final f = widget.friend;
    final ok = await guard(
      () => ref.read(apiProvider).createContact(ContactInput(
            name: f.displayName,
            categories: [?_category],
            frequencyValue: _freq.value,
            frequencyUnit: _freq.unit,
            birthday: _birthday,
            linkedUserId: f.userId,
          )),
      success: tr.friendNowContact(f.displayName),
    );
    if (ok != null) refreshData(ref);
  }

  Future<void> _link(Contact x) async {
    setState(() => _busy = x.id);
    final ok = await guard(() async {
      await ref.read(apiProvider).linkFriendToContact(widget.friend.userId, x.id);
      return true;
    }, success: tr.linkedContactToFriend(x.name, widget.friend.displayName));
    if (!mounted) return;
    setState(() => _busy = null);
    if (ok != null) refreshData(ref);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final f = widget.friend;
    final contacts = ref.watch(contactsProvider).value ?? const <Contact>[];
    final unlinked = contacts.where((x) => x.linkedUserId == null).toList();
    final suggested = unlinked.where((x) => friendMatchesContact(f, x)).toList();
    // Default tab: link when a likely card exists, otherwise create.
    final tab = _tab ?? (suggested.isNotEmpty ? _Tab.link : _Tab.create);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // friend on the left, the two mini tabs on the right
        Row(children: [
          FriendAvatar(name: f.displayName, size: 42, isFriend: true, userId: f.userId),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: c.text)),
              Text(handle(f.username), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textMuted, fontSize: 12.5)),
            ]),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 140,
            child: SegmentedControl<_Tab>(
              options: [(_Tab.link, tr.tabLink), (_Tab.create, tr.tabCreate)],
              value: tab,
              onChanged: (t) => setState(() => _tab = t),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (tab == _Tab.link) ..._linkTab(c, unlinked, suggested) else ..._createTab(c),
      ]),
    );
  }

  List<Widget> _linkTab(AppColors c, List<Contact> unlinked, List<Contact> suggested) {
    if (unlinked.isEmpty) {
      return [Text(tr.noContactToLink, style: TextStyle(color: c.textMuted, fontSize: 13.5))];
    }
    final q = _q.text.trim();
    final shown = q.isEmpty
        ? suggested.take(3).toList()
        : (unlinked.where((x) => contactMatches(x, q)).toList()..sort((a, b) => compareNames(a.name, b.name))).take(4).toList();
    return [
      SearchField(controller: _q, hint: tr.searchContactToLink, onChanged: (_) => setState(() {})),
      const SizedBox(height: 6),
      if (q.isEmpty && suggested.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Text(tr.suggested, style: TextStyle(color: c.textMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
      for (final x in shown)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 2),
          dense: true,
          leading: Avatar(name: x.name, path: x.photoPath, size: 36, seeu: false),
          title: Text(x.name, style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
          subtitle: ContactKindLine(linkedUserId: null, categories: x.categories),
          trailing: AppButton(tr.link,
              icon: LucideIcons.link2, size: ButtonSize.sm, loading: _busy == x.id, onPressed: _busy == null ? () => _link(x) : null),
        ),
      if (shown.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(q.isEmpty ? tr.noSuggestionSearch : tr.noMatchingContact, style: TextStyle(color: c.textMuted, fontSize: 13)),
        ),
    ];
  }

  List<Widget> _createTab(AppColors c) {
    final f = widget.friend;
    Widget chip(String label, bool on, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: on ? Palette.brand600 : c.secondaryFill, borderRadius: BorderRadius.circular(99)),
            child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? Colors.white : c.text)),
          ),
        );
    return [
      Text(tr.quickHowOften, style: TextStyle(color: c.textMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final p in _quickPresets) chip(p.label, p == _freq, () => setState(() => _freq = p)),
      ]),
      const SizedBox(height: 10),
      Text(tr.quickCategory, style: TextStyle(color: c.textMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final cat in categorySuggestions)
          CategoryTag(cat, selected: _category == cat, onTap: () => setState(() => _category = _category == cat ? null : cat)),
      ]),
      const SizedBox(height: 10),
      Text(tr.quickBirthday, style: TextStyle(color: c.textMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      DateField(
        value: _birthday,
        last: today(),
        clearable: true,
        compact: true,
        placeholder: tr.optionalShort,
        onChanged: (d) => setState(() => _birthday = d),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: AppButton(tr.fullForm,
              icon: LucideIcons.squarePen,
              variant: ButtonVariant.secondary,
              size: ButtonSize.sm,
              full: true,
              onPressed: () => context.push('/contacts/new',
                  extra: ContactPrefill(
                      name: f.displayName,
                      linkedUserId: f.userId,
                      linkedUsername: f.username,
                      frequencyValue: _freq.value,
                      frequencyUnit: _freq.unit,
                      categories: [?_category],
                      birthday: _birthday))),
        ),
        const SizedBox(width: 8),
        Expanded(child: AppButton(tr.createContactShort, icon: LucideIcons.check, size: ButtonSize.sm, full: true, onAsync: _create)),
      ]),
    ];
  }
}
