// iOS has no key to close the keyboard on multi-line fields (only "return"):
// a small "OK" bar sits above the keyboard, on every screen.
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/theme.dart';

class KeyboardDoneBar extends StatelessWidget {
  const KeyboardDoneBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) return child;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final c = context.colors;
    final mq = MediaQuery.of(context);
    return Stack(children: [
      // Pages make room for the bar too, so a focused field never hides behind it.
      inset > 0 ? MediaQuery(data: mq.copyWith(viewInsets: mq.viewInsets.copyWith(bottom: inset + 44)), child: child) : child,
      if (inset > 0)
        Positioned(
          left: 0,
          right: 0,
          bottom: inset,
          child: Material(
            color: c.isDark ? Palette.gray800 : const Color(0xFFF1F2F4),
            child: Container(
              height: 44,
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
                child: Text(tr.keyboardDone, style: TextStyle(color: c.brandText, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ),
        ),
    ]);
  }
}
