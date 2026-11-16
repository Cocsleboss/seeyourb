// iOS: single-line fields close the keyboard with their ✓ key, but multi-line
// fields only have "return" and number / phone pads have no key at all. For
// those, a small "OK" bar sits above the keyboard.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/i18n.dart';
import '../core/theme.dart';

class KeyboardDoneBar extends StatefulWidget {
  const KeyboardDoneBar({super.key, required this.child});
  final Widget child;

  @override
  State<KeyboardDoneBar> createState() => _KeyboardDoneBarState();
}

class _KeyboardDoneBarState extends State<KeyboardDoneBar> {
  @override
  void initState() {
    super.initState();
    if (Platform.isIOS) FocusManager.instance.addListener(_onFocus);
  }

  @override
  void dispose() {
    if (Platform.isIOS) FocusManager.instance.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  /// The focused field has no key to close the keyboard.
  bool get _needsBar {
    final ctx = FocusManager.instance.primaryFocus?.context;
    final field = ctx?.findAncestorWidgetOfExactType<EditableText>();
    if (field == null) return false;
    final multiline = field.maxLines == null || field.maxLines! > 1;
    final type = field.keyboardType;
    final noReturnKey =
        type == TextInputType.phone || type.index == TextInputType.number.index;
    return multiline || noReturnKey;
  }

  void _close() {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) return widget.child;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final show = inset > 0 && _needsBar;
    final c = context.colors;
    final mq = MediaQuery.of(context);
    // Always the same structure (Stack > MediaQuery > child): changing it when
    // the keyboard opens would rebuild the page and steal the field's focus.
    return Stack(
      children: [
        // Pages make room for the bar too, so a focused field never hides behind it.
        MediaQuery(
          data: show
              ? mq.copyWith(
                  viewInsets: mq.viewInsets.copyWith(bottom: inset + 44),
                )
              : mq,
          child: widget.child,
        ),
        if (show)
          Positioned(
            left: 0,
            right: 0,
            bottom: inset,
            child: Material(
              color: c.isDark ? Palette.gray800 : const Color(0xFFF1F2F4),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.border)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _close,
                  child: Text(
                    tr.keyboardDone,
                    style: TextStyle(
                      color: c.brandText,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
