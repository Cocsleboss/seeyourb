// Username input reused at sign-up, profile completion and settings (§4.1):
// fixed "@", cleaned while typing, availability checked ~350 ms after the last key.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/text.dart';
import '../../ui/forms.dart';
import '../../core/i18n.dart';

enum UsernameStatus { idle, invalid, checking, available, taken, error }

class UsernameField extends ConsumerStatefulWidget {
  const UsernameField({super.key, required this.controller, required this.onStatus, this.current, this.label});
  final TextEditingController controller;
  final ValueChanged<UsernameStatus> onStatus;

  /// The user's own current username (always "available").
  final String? current;
  final String? label;

  @override
  ConsumerState<UsernameField> createState() => _UsernameFieldState();
}

class _UsernameFieldState extends ConsumerState<UsernameField> {
  Timer? _debounce;
  UsernameStatus _status = UsernameStatus.idle;
  String? _formatError;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    if (widget.controller.text.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _check(widget.controller.text));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _setStatus(UsernameStatus s) {
    if (!mounted) return;
    setState(() => _status = s);
    widget.onStatus(s);
  }

  void _check(String value) {
    _debounce?.cancel();
    final err = value.isEmpty ? null : usernameFormatError(value);
    setState(() => _formatError = err);
    if (value.isEmpty) return _setStatus(UsernameStatus.idle);
    if (err != null) return _setStatus(UsernameStatus.invalid);
    if (value == widget.current) return _setStatus(UsernameStatus.available);
    _setStatus(UsernameStatus.checking);
    final seq = ++_seq;
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final ok = await ref.read(apiProvider).usernameAvailable(value);
        if (seq == _seq) _setStatus(ok ? UsernameStatus.available : UsernameStatus.taken);
      } catch (_) {
        if (seq == _seq) _setStatus(UsernameStatus.error);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final value = widget.controller.text;
    Widget? suffix;
    String? hint = usernameHint;
    String? error = _formatError;
    switch (_status) {
      case UsernameStatus.checking:
        suffix = const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)));
      case UsernameStatus.available:
        suffix = Icon(LucideIcons.circleCheck, color: c.tone(Tone.green).text);
        hint = value == widget.current ? usernameHint : tr.usernameAvailable(value);
      case UsernameStatus.taken:
        suffix = Icon(LucideIcons.circleX, color: c.tone(Tone.red).text);
        error = tr.errUsernameTaken;
      case UsernameStatus.error:
        hint = tr.usernameCheckFailed;
      default:
        break;
    }
    return LabeledField(
      label: widget.label ?? tr.usernameLabel,
      required: true,
      hint: hint,
      error: error,
      child: TextField(
        controller: widget.controller,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.visiblePassword,
        inputFormatters: [_UsernameFormatter()],
        onChanged: _check,
        style: TextStyle(fontSize: 16, color: c.text),
        decoration: InputDecoration(
          hintText: tr.usernamePlaceholder,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 4),
            child: Text('@', style: TextStyle(fontSize: 16, color: c.textMuted, fontWeight: FontWeight.w600)),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: suffix,
          // keep the hint/success text visible in green when available
          helperStyle: TextStyle(color: c.tone(Tone.green).text),
        ),
      ),
    );
  }
}

class _UsernameFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final cleaned = normalizeUsername(newValue.text);
    if (cleaned == newValue.text) return newValue;
    return TextEditingValue(text: cleaned, selection: TextSelection.collapsed(offset: cleaned.length));
  }
}
