// Toasts ("messages éclair"), bottom sheets ("panneaux bas") and confirmations.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/errors.dart';
import '../core/theme.dart';
import 'kit.dart';

enum ToastKind { success, error, info }

final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showToast(String message, {ToastKind kind = ToastKind.success}) {
  final messenger = rootMessengerKey.currentState;
  if (messenger == null) return;
  final (Color bg, IconData icon) = switch (kind) {
    ToastKind.success => (const Color(0xFF059669), LucideIcons.circleCheck),
    ToastKind.error => (const Color(0xFFDC2626), LucideIcons.circleAlert),
    ToastKind.info => (Palette.gray800, LucideIcons.info),
  };
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      duration: Duration(milliseconds: kind == ToastKind.error ? 4000 : 2500),
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15))),
      ]),
    ));
}

void showError(Object e) => showToast(errorMessage(e), kind: ToastKind.error);

/// Runs an async action, shows its error as a toast. Returns null on failure.
Future<T?> guard<T>(Future<T> Function() action, {String? success}) async {
  try {
    final r = await action();
    if (success != null) showToast(success);
    return r;
  } catch (e) {
    showError(e);
    return null;
  }
}

/// A sheet sliding from the bottom (~200 ms), closed by tapping outside.
Future<T?> showAppSheet<T>(BuildContext context, {required String title, String? subtitle, required Widget Function(BuildContext) builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    sheetAnimationStyle: const AnimationStyle(duration: Duration(milliseconds: 220), reverseDuration: Duration(milliseconds: 180)),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: SheetBody(title: title, subtitle: subtitle, child: builder(ctx)),
    ),
  );
}

class SheetBody extends StatelessWidget {
  const SheetBody({super.key, required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.text)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: TextStyle(fontSize: 15, color: c.textMuted, height: 1.4)),
            ],
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Destructive (or important) confirmation in a bottom sheet. Returns true if confirmed.
Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = true,
}) async {
  final ok = await showAppSheet<bool>(
    context,
    title: title,
    subtitle: message,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(confirmLabel,
            variant: danger ? ButtonVariant.danger : ButtonVariant.primary, full: true, onPressed: () => Navigator.pop(ctx, true)),
        const SizedBox(height: 10),
        AppButton('Annuler', variant: ButtonVariant.secondary, full: true, onPressed: () => Navigator.pop(ctx, false)),
      ],
    ),
  );
  return ok ?? false;
}
