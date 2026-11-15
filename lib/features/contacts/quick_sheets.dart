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
import '../../ui/pickers.dart';
import '../../core/i18n.dart';

Future<void> showMarkSeenSheet(BuildContext context, Contact contact) =>
    showAppSheet(context, title: tr.markSeenTitle(contact.name), builder: (_) => _MarkSeen(contact));

Future<void> showSnoozeSheet(BuildContext context, Contact contact) =>
    showAppSheet(context, title: tr.snoozeTitle(contact.name), builder: (_) => _Snooze(contact));

Future<void> showFrequencySheet(BuildContext context, Contact contact) => showAppSheet(context,
    title: tr.editFrequency, subtitle: tr.frequencySheetSub(contact.name), builder: (_) => _Frequency(contact));

Future<void> showSeeSoonSheet(BuildContext context, {required Set<String> excludeIds}) => showAppSheet(
      context,
      title: tr.seeSoonTitle,
      subtitle: tr.seeSoonSub,
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
      success: tr.meetingSaved(widget.contact.name),
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
        label: tr.whenDidYouSee,
        required: true,
        child: DateField(value: _date, last: today(), onChanged: (d) => setState(() => _date = d ?? today())),
      ),
      LabeledField(
        label: tr.noteOptional,
        child: AppTextField(controller: _notes, hint: tr.noteHint, maxLines: 3),
      ),
      Text(
        tr.markSeenHelp,
        style: TextStyle(fontSize: 13, color: c.textMuted, height: 1.35),
      ),
      const SizedBox(height: 16),
      AppButton(tr.saveMeeting, icon: LucideIcons.check, size: ButtonSize.lg, full: true, loading: _busy, onPressed: _save),
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
        success: tr.snoozedUntil(formatDate(until)));
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
      (tr.nDays(3), addFrequency(t, 3, FrequencyUnit.days)),
      (tr.nWeeks(1), addFrequency(t, 1, FrequencyUnit.weeks)),
      (tr.nWeeks(2), addFrequency(t, 2, FrequencyUnit.weeks)),
      (tr.nMonths(1), addFrequency(t, 1, FrequencyUnit.months)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr.remindMeIn, style: TextStyle(fontSize: 15, color: c.textMuted)),
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
        label: tr.orOnDate,
        child: DateField(value: _custom, first: t, onChanged: (d) => setState(() => _custom = d)),
      ),
      AppButton(tr.snooze, full: true, loading: _busy, onPressed: _custom == null ? null : () => _apply(_custom!)),
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
        success: tr.addedToSeeSoon(contact.name));
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
      SearchField(controller: _q, hint: tr.searchContact, onChanged: (_) => setState(() {})),
      const SizedBox(height: 8),
      ConstrainedBox(
        constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height * 0.3),
        child: shown.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(all.isEmpty ? tr.allAlreadyInList : tr.noMatchingContact,
                    textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
              )
            : Column(children: [
                for (final x in shown)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    enabled: _busyId == null,
                    leading: Avatar(name: x.name, path: x.photoPath, size: 40, seeu: x.linkedUserId != null),
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


class _Frequency extends ConsumerStatefulWidget {
  const _Frequency(this.contact);
  final Contact contact;
  @override
  ConsumerState<_Frequency> createState() => _FrequencyState();
}

class _FrequencyState extends ConsumerState<_Frequency> {
  late int _value = widget.contact.frequencyValue;
  late FrequencyUnit _unit = widget.contact.frequencyUnit;
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await guard(
      () => ref.read(apiProvider).updateContact(widget.contact.id, {'frequency_value': _value, 'frequency_unit': _unit.name}),
      success: tr.frequencyUpdated,
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
    final valid = _value >= 1;
    final start = widget.contact.lastMeetingDate ?? widget.contact.addedOn ?? today();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FrequencyPicker(value: _value, unit: _unit, onChanged: (v, u) => setState(() => (_value = v, _unit = u))),
      const SizedBox(height: 12),
      Text(
        valid ? '${tr.nextDue} : ${formatDateLong(addFrequency(start, _value, _unit))}' : tr.frequencyMin,
        style: TextStyle(fontSize: 13.5, color: valid ? c.textMuted : c.tone(Tone.red).text, height: 1.35),
      ),
      const SizedBox(height: 16),
      AppButton(tr.save, icon: LucideIcons.check, size: ButtonSize.lg, full: true, loading: _busy, onPressed: valid ? _save : null),
    ]);
  }
}
