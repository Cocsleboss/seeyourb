// Form building blocks: labeled fields, date/time pickers, segmented control, toggles.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme.dart';
import '../domain/dates.dart';
import 'kit.dart';
import '../core/i18n.dart';

class LabeledField extends StatelessWidget {
  const LabeledField({super.key, this.label, required this.child, this.hint, this.error, this.required = false, this.tag, this.icon});
  final String? label;

  /// Small icon before the label.
  final IconData? icon;

  /// Muted note after the label, e.g. "(personnel)".
  final String? tag;
  final Widget child;
  final String? hint;
  final String? error;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text.rich(TextSpan(children: [
                if (icon != null) ...[
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(icon, size: 16, color: c.brandText),
                    ),
                  ),
                ],
                TextSpan(text: label),
                if (required) TextSpan(text: ' *', style: TextStyle(color: c.tone(Tone.red).text)),
                if (tag != null) TextSpan(text: ' $tag', style: TextStyle(color: c.textSubtle, fontWeight: FontWeight.w400)),
              ]), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.isDark ? Palette.gray300 : Palette.gray700)),
            ),
          child,
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(error!, style: TextStyle(color: c.tone(Tone.red).text, fontSize: 14)),
            )
          else if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(hint!, style: TextStyle(color: c.textMuted, fontSize: 12.5)),
            ),
        ],
      ),
    );
  }
}

/// Text field with the app style.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.hint,
    this.keyboardType,
    this.maxLength,
    this.maxLines = 1,
    this.obscure = false,
    this.onChanged,
    this.prefix,
    this.suffix,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int? maxLines;
  final bool obscure;
  final ValueChanged<String>? onChanged;
  final Widget? prefix;
  final Widget? suffix;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      maxLines: obscure ? 1 : maxLines,
      minLines: maxLines != null && maxLines! > 1 ? 3 : null,
      obscureText: obscure,
      onChanged: onChanged,
      autofocus: autofocus,
      enabled: enabled,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      autofillHints: autofillHints,
      textCapitalization: textCapitalization,
      style: TextStyle(fontSize: 16, color: context.colors.text),
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        prefixIcon: prefix,
        prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 0),
        suffixIcon: suffix,
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.controller, required this.hint, this.onChanged});
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) => AppTextField(
        controller: controller,
        hint: hint,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        prefix: Padding(
          padding: const EdgeInsets.only(left: 12, right: 6),
          child: Icon(LucideIcons.search, size: 20, color: context.colors.textMuted),
        ),
        suffix: value.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(LucideIcons.x, size: 18, color: context.colors.textMuted),
                onPressed: () {
                  controller.clear();
                  onChanged?.call('');
                },
              ),
      ),
    );
  }
}

/// Looks like an input; opens a picker when tapped.
class PickerField extends StatelessWidget {
  const PickerField({super.key, required this.text, required this.icon, required this.onTap, this.placeholder = false});
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: c.inputFill,
          border: Border.all(color: c.inputBorder),
          borderRadius: BorderRadius.circular(Radii.input),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: c.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, color: placeholder ? c.textSubtle : c.text)),
          ),
        ]),
      ),
    );
  }
}

class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.first,
    this.last,
    this.placeholder,
    this.clearable = false,
    this.compact = false,
  });
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? first;
  final DateTime? last;
  final String? placeholder;
  final bool clearable;

  /// "sam. 14 nov. 2026" instead of "samedi 14 novembre 2026" (narrow fields).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final field = PickerField(
      text: value == null ? (placeholder ?? tr.pickDate) : (compact ? formatDateMedium(value!) : formatDateLong(value!)),
      placeholder: value == null,
      icon: LucideIcons.calendar,
      onTap: () async {
        final firstDate = first ?? DateTime(1900);
        final lastDate = last ?? DateTime(2100);
        var initial = value ?? today();
        if (initial.isBefore(firstDate)) initial = firstDate;
        if (initial.isAfter(lastDate)) initial = lastDate;
        final d = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: firstDate,
          lastDate: lastDate,
        );
        if (d != null) onChanged(dayOf(d));
      },
    );
    if (!clearable || value == null) return field;
    return Row(children: [
      Expanded(child: field),
      IconButton(tooltip: tr.clear, onPressed: () => onChanged(null), icon: Icon(LucideIcons.x, color: context.colors.textMuted)),
    ]);
  }
}

class TimeField extends StatelessWidget {
  const TimeField({super.key, required this.value, required this.onChanged});
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return PickerField(
      text: text,
      icon: LucideIcons.clock,
      onTap: () async {
        final t = await showTimePicker(
          context: context,
          initialTime: value,
          builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
        );
        if (t != null) onChanged(t);
      },
    );
  }
}

/// iOS-like segmented control (Tous / A eu lieu / Annulés).
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({super.key, required this.options, required this.value, required this.onChanged});
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.secondaryFill, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (final (v, label) in options)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: v == value ? (c.isDark ? Palette.gray900 : Colors.white) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: v == value && !c.isDark ? const [BoxShadow(color: Color(0x1A000000), blurRadius: 3, offset: Offset(0, 1))] : null,
                  ),
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: v == value ? FontWeight.w600 : FontWeight.w500,
                        color: v == value ? c.text : c.textMuted,
                      )),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ToggleRow extends StatelessWidget {
  const ToggleRow({super.key, required this.title, this.subtitle, required this.value, required this.onChanged});
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: c.text)),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitle!, style: TextStyle(fontSize: 13, color: c.textMuted)),
              ),
          ]),
        ),
        const SizedBox(width: 12),
        Switch.adaptive(value: value, onChanged: onChanged),
      ]),
    );
  }
}

/// Simple dropdown styled like the inputs.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({super.key, required this.value, required this.items, required this.onChanged});
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      borderRadius: BorderRadius.circular(14),
      dropdownColor: context.colors.card,
      icon: Icon(LucideIcons.chevronDown, size: 18, color: context.colors.textMuted),
      items: [for (final (v, l) in items) DropdownMenuItem(value: v, child: Text(l))],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
