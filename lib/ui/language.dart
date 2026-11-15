// Language picker: compact button (login / account creation) and the sheet it opens.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import 'feedback.dart';

/// Opens the language sheet; null = follow the phone.
Future<void> pickLanguage(BuildContext context, WidgetRef ref) async {
  final choice = ref.read(languageChoiceProvider);
  final picked = await showAppSheet<String>(
    context,
    title: tr.languageTitle,
    builder: (ctx) {
      final c = ctx.colors;
      Widget option(String value, String label, {String? sub}) {
        final selected = (choice ?? 'system') == value;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
          subtitle: sub == null ? null : Text(sub, style: TextStyle(color: c.textMuted)),
          trailing: selected ? Icon(LucideIcons.check, color: c.brandText) : null,
          onTap: () => Navigator.pop(ctx, value),
        );
      }

      return Column(mainAxisSize: MainAxisSize.min, children: [
        option('system', tr.languageSystem, sub: appLanguages[systemLanguage()]),
        for (final e in appLanguages.entries) option(e.key, e.value),
      ]);
    },
  );
  if (picked == null) return;
  await ref.read(languageChoiceProvider.notifier).set(picked == 'system' ? null : picked);
}

/// "🌐 Français" pill, for screens shown before the settings are reachable.
class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final lang = ref.watch(languageProvider);
    return TextButton.icon(
      onPressed: () => pickLanguage(context, ref),
      icon: Icon(LucideIcons.globe, size: 18, color: c.textMuted),
      label: Text(appLanguages[lang] ?? lang, style: TextStyle(color: c.textMuted, fontWeight: FontWeight.w600)),
    );
  }
}
