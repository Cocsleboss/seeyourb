// Mute (an event, or all events & messages of a person) and block, from an event,
// a chat message or a contact. Managed later in Settings → Masqués et bloqués.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../ui/feedback.dart';

Future<bool> _run(WidgetRef ref, Future<void> Function() action, String success) async {
  final ok = await guard(() async {
    await action();
    return true;
  }, success: success);
  if (ok != null) refreshData(ref);
  return ok != null;
}

Future<bool> setEventMuted(WidgetRef ref, String eventId, bool muted) => _run(
      ref,
      () => muted ? ref.read(apiProvider).muteEvent(eventId) : ref.read(apiProvider).unmuteEvent(eventId),
      muted ? tr.eventMuted : tr.eventUnmuted,
    );

Future<bool> setPersonMuted(WidgetRef ref, String userId, String name, bool muted) => _run(
      ref,
      () => muted ? ref.read(apiProvider).muteUser(userId) : ref.read(apiProvider).unmuteUser(userId),
      muted ? tr.personMuted(name) : tr.personUnmuted(name),
    );

Future<bool> confirmBlock(BuildContext context, WidgetRef ref, String userId, String name) async {
  final ok = await confirmSheet(context, title: tr.blockTitle(name), message: tr.blockMessage, confirmLabel: tr.block);
  if (!ok) return false;
  return _run(ref, () => ref.read(apiProvider).blockUser(userId), tr.blocked(name));
}

class ModerationAction {
  const ModerationAction(this.icon, this.label, this.onTap, {this.danger = false});
  final IconData icon;
  final String label;
  final Future<void> Function() onTap;
  final bool danger;
}

/// Bottom sheet listing moderation actions.
Future<void> showModerationSheet(BuildContext context, {required String title, required List<ModerationAction> actions}) async {
  final picked = await showAppSheet<ModerationAction>(
    context,
    title: title,
    builder: (ctx) {
      final c = ctx.colors;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        for (final a in actions)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: Icon(a.icon, color: a.danger ? c.tone(Tone.red).text : c.text),
            title: Text(a.label, style: TextStyle(fontWeight: FontWeight.w600, color: a.danger ? c.tone(Tone.red).text : c.text)),
            onTap: () => Navigator.pop(ctx, a),
          ),
      ]);
    },
  );
  await picked?.onTap();
}

/// Actions about a person (organizer of an event, author of a message, linked contact).
List<ModerationAction> personActions(BuildContext context, WidgetRef ref, {required String userId, required String name, required bool muted}) => [
      muted
          ? ModerationAction(LucideIcons.bell, tr.unmutePerson(name), () => setPersonMuted(ref, userId, name, false))
          : ModerationAction(LucideIcons.bellOff, tr.mutePerson(name), () => setPersonMuted(ref, userId, name, true)),
      ModerationAction(LucideIcons.ban, tr.blockName(name), () => confirmBlock(context, ref, userId, name), danger: true),
    ];
