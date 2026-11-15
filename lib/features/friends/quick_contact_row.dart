// A SeeU friend without a contact card, made a contact in one tap: pick how
// often to see them and a category right in the list, then "Associer".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/text.dart';
import '../../ui/feedback.dart';
import '../../ui/kit.dart';
import '../../ui/rows.dart';
import '../contacts/contact_form_screen.dart';

const _quickPresets = [
  FrequencyPreset(1, FrequencyUnit.weeks),
  FrequencyPreset(2, FrequencyUnit.weeks),
  FrequencyPreset(1, FrequencyUnit.months),
  FrequencyPreset(3, FrequencyUnit.months),
];

class QuickFriendContactRow extends ConsumerStatefulWidget {
  const QuickFriendContactRow({super.key, required this.friend});
  final Friend friend;
  @override
  ConsumerState<QuickFriendContactRow> createState() => _QuickFriendContactRowState();
}

class _QuickFriendContactRowState extends ConsumerState<QuickFriendContactRow> {
  FrequencyPreset _freq = _quickPresets[2];
  String? _category;

  Future<void> _associate() async {
    final f = widget.friend;
    final ok = await guard(
      () => ref.read(apiProvider).createContact(ContactInput(
            name: f.displayName,
            categories: [?_category],
            frequencyValue: _freq.value,
            frequencyUnit: _freq.unit,
            linkedUserId: f.userId,
          )),
      success: tr.friendNowContact(f.displayName),
    );
    if (ok != null) refreshData(ref);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final f = widget.friend;
    Widget chip(String label, bool on, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: on ? Palette.brand600 : c.secondaryFill,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? Colors.white : c.text)),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          FriendAvatar(name: f.displayName, size: 42, isFriend: true, userId: f.userId),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: c.text)),
              Text(handle(f.username), style: TextStyle(color: c.textMuted, fontSize: 13)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Text(tr.quickHowOften, style: TextStyle(color: c.textMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final p in _quickPresets) chip(p.label, p == _freq, () => setState(() => _freq = p)),
        ]),
        const SizedBox(height: 10),
        Text(tr.quickCategory, style: TextStyle(color: c.textMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final cat in categorySuggestions) chip(cat, _category == cat, () => setState(() => _category = _category == cat ? null : cat)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: AppButton(tr.moreOptions,
                variant: ButtonVariant.secondary,
                size: ButtonSize.sm,
                full: true,
                onPressed: () => context.push('/contacts/new',
                    extra: ContactPrefill(
                        name: f.displayName,
                        linkedUserId: f.userId,
                        frequencyValue: _freq.value,
                        frequencyUnit: _freq.unit,
                        categories: [?_category]))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppButton(tr.associate, icon: LucideIcons.check, size: ButtonSize.sm, full: true, onAsync: _associate),
          ),
        ]),
      ]),
    );
  }
}
