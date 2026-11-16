// Frequency and category pickers shared by the contact form and the import review.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../domain/dates.dart';
import '../domain/models.dart';
import '../domain/text.dart';
import 'forms.dart';
import 'kit.dart';
import '../core/i18n.dart';

/// 7 presets + "Personnalisée" (a number and a unit).
class FrequencyPicker extends StatefulWidget {
  const FrequencyPicker({super.key, required this.value, required this.unit, required this.onChanged});
  final int value;
  final FrequencyUnit unit;
  final void Function(int value, FrequencyUnit unit) onChanged;

  @override
  State<FrequencyPicker> createState() => _FrequencyPickerState();
}

class _FrequencyPickerState extends State<FrequencyPicker> {
  late bool _custom = !_isPreset(widget.value, widget.unit);
  late final _number = TextEditingController(text: '${widget.value}');

  static bool _isPreset(int v, FrequencyUnit u) => u == FrequencyUnit.never || frequencyPresets.any((f) => f.value == v && f.unit == u);

  @override
  void didUpdateWidget(FrequencyPicker old) {
    super.didUpdateWidget(old);
    // value changed from outside (e.g. next contact in the import review)
    if (old.value != widget.value || old.unit != widget.unit) {
      if (int.tryParse(_number.text) != widget.value) _number.text = '${widget.value}';
      if (!_custom && !_isPreset(widget.value, widget.unit)) _custom = true;
    }
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ChipWrap(children: [
        for (final f in frequencyPresets)
          AppChip(f.label, selected: !_custom && f.value == widget.value && f.unit == widget.unit, onTap: () {
            setState(() => _custom = false);
            _number.text = '${f.value}';
            widget.onChanged(f.value, f.unit);
          }),
        AppChip(tr.freqCustom, selected: _custom, onTap: () {
          setState(() => _custom = true);
          if (widget.unit == FrequencyUnit.never) widget.onChanged(1, FrequencyUnit.months);
        }),
        // No recurring reminder for this person.
        AppChip(tr.freqNever,
            icon: LucideIcons.bellOff,
            selected: !_custom && widget.unit == FrequencyUnit.never,
            onTap: () {
              setState(() => _custom = false);
              widget.onChanged(1, FrequencyUnit.never);
            }),
      ]),
      if (_custom) ...[
        const SizedBox(height: 10),
        Row(children: [
          SizedBox(
            width: 90,
            child: AppTextField(
              controller: _number,
              keyboardType: TextInputType.number,
              maxLength: 4,
              onChanged: (v) => widget.onChanged(int.tryParse(v) ?? 0, widget.unit),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppDropdown<FrequencyUnit>(
              value: widget.unit,
              items: [for (final u in FrequencyUnit.values.where((u) => u != FrequencyUnit.never)) (u, unitLabel(u, widget.value))],
              onChanged: (u) => widget.onChanged(widget.value, u),
            ),
          ),
        ]),
      ],
    ]);
  }
}

/// Multi-select categories: suggestions, categories already used elsewhere, and free entries.
class CategoryPicker extends StatefulWidget {
  const CategoryPicker({super.key, required this.selected, required this.onChanged, this.known = const []});
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  /// Categories used on other contacts, offered as chips too.
  final List<String> known;

  @override
  State<CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<CategoryPicker> {
  bool _adding = false;
  final _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  bool _has(String c) => widget.selected.any((s) => normalizeText(s) == normalizeText(c));

  void _toggle(String c) {
    final next = _has(c)
        ? widget.selected.where((s) => normalizeText(s) != normalizeText(c)).toList()
        : [...widget.selected, c];
    widget.onChanged(next);
  }

  void _addCustom() {
    final v = _custom.text.trim();
    if (v.isEmpty) return;
    if (!_has(v)) widget.onChanged([...widget.selected, v.length > 40 ? v.substring(0, 40) : v]);
    _custom.clear();
    setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) {
    final options = <String>[];
    for (final c in [...categorySuggestions, ...widget.known, ...widget.selected]) {
      if (!options.any((o) => normalizeText(o) == normalizeText(c))) options.add(c);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ChipWrap(children: [
        for (final c in options) CategoryTag(c, selected: _has(c), onTap: () => _toggle(c)),
        AppChip(tr.categoryOther, icon: LucideIcons.plus, selected: _adding, onTap: () => setState(() => _adding = !_adding)),
      ]),
      if (_adding) ...[
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: AppTextField(
              controller: _custom,
              hint: tr.categoryHint,
              maxLength: 40,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addCustom(),
            ),
          ),
          const SizedBox(width: 8),
          AppButton(tr.add, size: ButtonSize.sm, onPressed: _addCustom),
        ]),
      ],
    ]);
  }
}
