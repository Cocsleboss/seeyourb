// Mute (an event, or all events & messages of a person) and block, from an event,
// a chat message or a contact. Managed later in Settings → Masqués et bloqués.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../ui/feedback.dart';
import '../../ui/forms.dart';
import '../../ui/kit.dart';

Future<bool> _run(WidgetRef ref, Future<void> Function() action, String success) async {
  final ok = await guard(() async {
    await action();
    return true;
  }, success: success);
  if (ok != null) refreshData(ref);
  return ok != null;
}

Future<bool> setEventMuted(WidgetRef ref, String eventId, bool muted) => withProgress(() => _run(
      ref,
      () => muted ? ref.read(apiProvider).muteEvent(eventId) : ref.read(apiProvider).unmuteEvent(eventId),
      muted ? tr.eventMuted : tr.eventUnmuted,
    ));

Future<bool> setPersonMuted(WidgetRef ref, String userId, String name, bool muted) => withProgress(() => _run(
      ref,
      () => muted ? ref.read(apiProvider).muteUser(userId) : ref.read(apiProvider).unmuteUser(userId),
      muted ? tr.personMuted(name) : tr.personUnmuted(name),
    ));

/// Blocks a person after confirmation. My contact linked to them is deleted too
/// (with its photos), so the catch-up reminders stop.
Future<bool> confirmBlock(BuildContext context, WidgetRef ref, String userId, String name) async {
  final contacts = ref.read(contactsProvider).value ?? const <Contact>[];
  final contact = contacts.where((c) => c.linkedUserId == userId).firstOrNull;
  final ok = await confirmSheet(
    context,
    title: tr.blockTitle(name),
    message: [tr.blockMessage, if (contact != null) tr.blockContactDeleted(contact.name)].join('\n\n'),
    confirmLabel: tr.block,
  );
  if (!ok) return false;
  return withProgress(() => _run(ref, () async {
        final api = ref.read(apiProvider);
        if (contact != null) await api.deleteContact(contact);
        await api.blockUser(userId);
      }, contact != null ? tr.blockedAndDeleted(name) : tr.blocked(name)));
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
/// [onBlocked]: what to do once blocked (usually leave the page, whose content is gone).
List<ModerationAction> personActions(BuildContext context, WidgetRef ref,
        {required String userId, required String name, required bool muted, VoidCallback? onBlocked}) =>
    [
      muted
          ? ModerationAction(LucideIcons.bell, tr.unmutePerson(name), () => setPersonMuted(ref, userId, name, false))
          : ModerationAction(LucideIcons.bellOff, tr.mutePerson(name), () => setPersonMuted(ref, userId, name, true)),
      ModerationAction(LucideIcons.flag, tr.reportPerson(name),
          () => showReportSheet(context, ref, title: tr.reportPerson(name), name: name, userId: userId, onBlocked: onBlocked)),
      ModerationAction(LucideIcons.ban, tr.blockName(name), () async {
        final done = await confirmBlock(context, ref, userId, name);
        if (done) onBlocked?.call();
      }, danger: true),
    ];

/* ------------------------------------------------------------------ */
/*  Reports                                                            */
/* ------------------------------------------------------------------ */

/// Report a person, or one of their events, photos or messages (the most specific
/// id given is the target). [userId] + [name]: offers to block them too.
Future<void> showReportSheet(BuildContext context, WidgetRef ref,
    {required String title,
    String? name,
    String? userId,
    String? eventId,
    String? photoId,
    String? messageId,
    VoidCallback? onBlocked}) async {
  final blocked = await showAppSheet<bool>(
    context,
    title: title,
    subtitle: tr.reportSub,
    builder: (_) => _ReportSheet(userId: userId, eventId: eventId, photoId: photoId, messageId: messageId, canBlock: userId != null),
  );
  if (blocked == true) {
    refreshData(ref);
    onBlocked?.call();
  }
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({this.userId, this.eventId, this.photoId, this.messageId, required this.canBlock});
  final String? userId;
  final String? eventId;
  final String? photoId;
  final String? messageId;
  final bool canBlock;
  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  ReportReason? _reason;
  final _comment = TextEditingController();
  bool _block = false;
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null) return;
    setState(() => _busy = true);
    final api = ref.read(apiProvider);
    final ok = await guard(() async {
      // reported first: blocking can hide what is being reported
      await api.report(reason,
          comment: _comment.text, userId: widget.userId, eventId: widget.eventId, photoId: widget.photoId, messageId: widget.messageId);
      if (_block && widget.userId != null) {
        final contact = (ref.read(contactsProvider).value ?? const <Contact>[]).where((c) => c.linkedUserId == widget.userId).firstOrNull;
        if (contact != null) await api.deleteContact(contact);
        await api.blockUser(widget.userId!);
      }
      return true;
    }, success: tr.reportSent);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok != null) Navigator.pop(context, _block);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr.reportReason, style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
      const SizedBox(height: 4),
      RadioGroup<ReportReason>(
        groupValue: _reason,
        onChanged: (v) => setState(() => _reason = v),
        child: Column(children: [
          for (final r in ReportReason.values)
            RadioListTile<ReportReason>(
              value: r,
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: Palette.brand600,
              title: Text(r.label, style: TextStyle(color: c.text, fontSize: 15)),
            ),
        ]),
      ),
      const SizedBox(height: 8),
      LabeledField(
        label: tr.reportComment,
        child: AppTextField(controller: _comment, hint: tr.reportCommentHint, maxLines: 3, maxLength: 1000),
      ),
      if (widget.canBlock)
        ToggleRow(title: tr.reportAlsoBlock, value: _block, onChanged: (v) => setState(() => _block = v)),
      const SizedBox(height: 12),
      AppButton(tr.sendReport,
          icon: LucideIcons.flag, variant: ButtonVariant.danger, full: true, loading: _busy, onPressed: _reason == null ? null : _send),
    ]);
  }
}

/// Leaves the current page (or goes home when it was opened directly).
void leavePage(BuildContext context) {
  if (!context.mounted) return;
  context.canPop() ? context.pop() : context.go('/');
}
