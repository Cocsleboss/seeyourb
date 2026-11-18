// Copying a link with visible feedback: the box / button itself turns into
// "Copié ✓" for a moment (a toast would be hidden behind a bottom sheet).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/config.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import 'kit.dart';

/// Copies [text] and runs [onCopied]; the caller shows its "copied" state.
Future<void> copyText(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  HapticFeedback.lightImpact();
}

mixin _CopiedState<T extends StatefulWidget> on State<T> {
  bool copied = false;
  Timer? _timer;

  Future<void> copy(String text) async {
    await copyText(text);
    if (!mounted) return;
    setState(() => copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => copied = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// The link in a grey box; tap to copy.
class CopyLinkBox extends StatefulWidget {
  const CopyLinkBox({super.key, required this.link, this.small = false});
  final String link;
  final bool small;
  @override
  State<CopyLinkBox> createState() => _CopyLinkBoxState();
}

class _CopyLinkBoxState extends State<CopyLinkBox> with _CopiedState {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final green = c.tone(Tone.green);
    return Material(
      color: copied ? green.bg : c.secondaryFill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => copy(widget.link),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Icon(LucideIcons.link, size: widget.small ? 16 : 18, color: c.brandText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(widget.link,
                  maxLines: widget.small ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.text, fontWeight: FontWeight.w500, fontSize: widget.small ? 12.5 : 14.5)),
            ),
            const SizedBox(width: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: copied
                  ? Row(key: const ValueKey('done'), mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.check, size: 16, color: green.text),
                      const SizedBox(width: 3),
                      Text(tr.copied, style: TextStyle(color: green.text, fontWeight: FontWeight.w700, fontSize: 13)),
                    ])
                  : Icon(LucideIcons.copy, key: const ValueKey('copy'), size: 16, color: c.textMuted),
            ),
          ]),
        ),
      ),
    );
  }
}

/// "Copier le lien" button that shows "Copié ✓" once pressed.
class CopyLinkButton extends StatefulWidget {
  const CopyLinkButton({super.key, required this.link, this.size = ButtonSize.sm});
  final String link;
  final ButtonSize size;
  @override
  State<CopyLinkButton> createState() => _CopyLinkButtonState();
}

class _CopyLinkButtonState extends State<CopyLinkButton> with _CopiedState {
  @override
  Widget build(BuildContext context) => AppButton(copied ? tr.copied : tr.copyLink,
      icon: copied ? LucideIcons.check : LucideIcons.copy,
      variant: ButtonVariant.secondary,
      size: widget.size,
      full: true,
      onPressed: () => copy(widget.link));
}

/// The seeu:// version of a link, to test opening the app before the website
/// exists (hidden with SHOW_APP_LINKS=false).
class TestAppLink extends StatelessWidget {
  const TestAppLink({super.key, required this.link});
  final String link;

  @override
  Widget build(BuildContext context) {
    if (!Config.showAppLinks) return const SizedBox.shrink();
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr.testAppLink, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: c.textMuted)),
      const SizedBox(height: 6),
      CopyLinkBox(link: link, small: true),
      const SizedBox(height: 4),
      Text(tr.testAppLinkHelp, style: TextStyle(color: c.textSubtle, fontSize: 12, height: 1.35)),
    ]);
  }
}
