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
import '../../domain/selectors.dart';
import '../../ui/kit.dart';
import '../../ui/pickers.dart';
import '../../ui/scaffold.dart';
import '../../core/i18n.dart';

enum _Step { source, review, confirm }

/// Settings chosen for one imported person.
class _Choice {
  _Choice({required this.value, required this.unit, this.categories = const [], this.lastMeeting});
  int value;
  FrequencyUnit unit;
  List<String> categories;
  DateTime? lastMeeting;
  _Choice copy() => _Choice(value: value, unit: unit, categories: [...categories], lastMeeting: lastMeeting);
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
  _Choice _current = _Choice(value: 1, unit: FrequencyUnit.months);
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
      showToast(tr.importReadFailed, kind: ToastKind.error);
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
    if (res.fresh.isEmpty) showToast(tr.importAllThere, kind: ToastKind.info);
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
      title: tr.importRestTitle(remaining),
      subtitle: '${[
        tr.importRestFreq(frequencyLabel(_current.value, _current.unit)),
        if (_current.categories.isNotEmpty) tr.importRestCats(_current.categories.join(', ')),
        if (_current.lastMeeting != null) tr.importRestLast(formatDate(_current.lastMeeting!)),
      ].join(', ')}.',
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AppButton(tr.addAll, icon: LucideIcons.userPlus, full: true, onPressed: () => Navigator.pop(ctx, true)),
        const SizedBox(height: 10),
        AppButton(tr.ignoreAllFinish, variant: ButtonVariant.secondary, full: true, onPressed: () => Navigator.pop(ctx, false)),
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
          categories: _decisions[c.key]!.categories,
          lastMeetingDate: _decisions[c.key]!.lastMeeting,
          frequencyValue: _decisions[c.key]!.value,
          frequencyUnit: _decisions[c.key]!.unit,
        ),
    ];
    final n = await guard(() => ref.read(apiProvider).createContacts(inputs));
    if (!mounted) return;
    setState(() => _saving = false);
    if (n == null) return;
    showToast(tr.nImported(n));
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
        title: tr.importContacts,
        subtitle: tr.stepOf(stepNo),
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
          child: AppButton(_picked.isEmpty ? tr.chooseContacts : tr.continueN(_picked.length),
              size: ButtonSize.lg, full: true, onPressed: _picked.isEmpty ? null : _startReview),
        );
      case _Step.review:
        return BottomActionBar(
          child: Row(children: [
            Expanded(child: AppButton(tr.ignore, variant: ButtonVariant.secondary, size: ButtonSize.lg, full: true, onPressed: () => _decide(false))),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(tr.add,
                  icon: LucideIcons.check, size: ButtonSize.lg, full: true, onPressed: _current.value < 1 ? null : () => _decide(true)),
            ),
          ]),
        );
      case _Step.confirm:
        final n = _kept.length;
        return BottomActionBar(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AppButton(tr.importN(n),
                size: ButtonSize.lg, full: true, loading: _saving, onPressed: n == 0 ? null : _import),
            const SizedBox(height: 6),
            AppButton(tr.reviewSelection,
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
          title: tr.fromAddressBook,
          message:
              tr.fromAddressBookHelp,
          actions: [
            AppButton(tr.accessMyContacts, icon: LucideIcons.bookUser, size: ButtonSize.lg, loading: _loading, onPressed: _loadPhoneBook),
          ],
        ),
        if (_denied)
          InfoBox(
            tone: Tone.amber,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr.contactsAccessDenied),
              const SizedBox(height: 8),
              AppButton(tr.openPhoneSettings,
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
        child: SearchField(controller: _q, hint: tr.searchEllipsis, onChanged: (_) => setState(() {})),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Expanded(child: Text('${tr.nContacts(_phoneBook!.length)} · ${tr.nChosen(_picked.length)}',
              style: TextStyle(color: c.textMuted))),
          TextButton(
            onPressed: () => setState(() => allPicked ? _picked.removeAll(list.map((x) => x.key)) : _picked.addAll(list.map((x) => x.key))),
            child: Text(allPicked ? tr.deselectAll : tr.selectAll, style: TextStyle(color: c.brandText)),
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
              secondary: Avatar(name: x.name, size: 40, seeu: false),
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
        Text(tr.contactNofM(_index + 1, _queue.length), style: TextStyle(color: c.textMuted)),
        const Spacer(),
        if (_dedupe != null && (_dedupe!.alreadyThere + _dedupe!.duplicates) > 0)
          Text(tr.duplicatesSkipped(_dedupe!.alreadyThere + _dedupe!.duplicates), style: TextStyle(color: c.textSubtle, fontSize: 12.5)),
      ]),
      const SizedBox(height: 14),
      AppCard(
        child: Row(children: [
          Avatar(name: person.name, size: 56, seeu: false),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(person.name, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: c.text)),
              for (final line in [person.phone, person.email, if (person.birthday != null) tr.bornOn(formatDate(person.birthday!))])
                if (line != null) Text(line, style: TextStyle(color: c.textMuted, fontSize: 14)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 18),
      LabeledField(
        label: tr.frequency,
        error: _current.value < 1 ? tr.frequencyMin : null,
        child: FrequencyPicker(
          key: ValueKey('freq-${person.key}'),
          value: _current.value,
          unit: _current.unit,
          onChanged: (v, u) => setState(() {
            _current.value = v;
            _current.unit = u;
          }),
        ),
      ),
      LabeledField(
        label: tr.categories,
        child: CategoryPicker(
          selected: _current.categories,
          known: usedCategories(ref.watch(contactsProvider).value ?? const []),
          onChanged: (v) => setState(() => _current.categories = v),
        ),
      ),
      LabeledField(
        label: tr.lastMeeting,
        hint: tr.optional,
        child: DateField(
          value: _current.lastMeeting,
          last: today(),
          clearable: true,
          placeholder: tr.noMeetingRecorded,
          onChanged: (d) => setState(() => _current.lastMeeting = d),
        ),
      ),
      if (remaining > 1)
        Center(
          child: TextButton(
            onPressed: _bulk,
            child: Text(tr.restAtOnce(remaining - 1), style: TextStyle(color: c.brandText, fontWeight: FontWeight.w600)),
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
        kept.isEmpty ? tr.noneKept : '${tr.nKept(kept.length)}${ignored > 0 ? ' · ${tr.nIgnored(ignored)}' : ''}',
        style: TextStyle(fontSize: 16, color: c.text, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      if (kept.isNotEmpty)
        RowsCard(children: [
          for (final x in kept)
            ListTile(
              leading: Avatar(name: x.name, size: 40, seeu: false),
              title: Text(x.name, style: TextStyle(fontWeight: FontWeight.w500, color: c.text)),
              subtitle: Text(
                [frequencyLabel(_decisions[x.key]!.value, _decisions[x.key]!.unit), ..._decisions[x.key]!.categories].join(' · '),
                style: TextStyle(color: c.textMuted, fontSize: 13),
              ),
              trailing: IconButton(
                tooltip: tr.removeName(x.name),
                icon: Icon(LucideIcons.x, color: c.textMuted),
                onPressed: () => setState(() => _decisions[x.key] = null),
              ),
            ),
        ]),
    ]);
  }
}
