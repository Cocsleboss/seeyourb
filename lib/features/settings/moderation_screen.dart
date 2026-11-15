// Réglages → Masqués et bloqués: undo mutes (people, events) and blocks.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../domain/dates.dart';
import '../../domain/models.dart';
import '../../domain/text.dart';
import '../../ui/feedback.dart';
import '../../ui/kit.dart';
import '../../ui/scaffold.dart';

class ModerationScreen extends ConsumerWidget {
  const ModerationScreen({super.key});

  Future<void> _run(WidgetRef ref, Future<void> Function() action, String success) async {
    await guard(() async {
      await action();
      return true;
    }, success: success);
    refreshData(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final mutes = ref.watch(mutesProvider);
    final blocked = ref.watch(blockedProvider);

    Widget row({required Widget leading, required String title, String? subtitle, required String action, required Future<void> Function() onTap}) =>
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: leading,
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
          subtitle: subtitle == null ? null : Text(subtitle, style: TextStyle(color: c.textMuted, fontSize: 13.5)),
          trailing: AppButton(action, size: ButtonSize.sm, variant: ButtonVariant.secondary, onAsync: onTap),
        );

    return AppScaffold(
      title: tr.moderationTitle,
      back: true,
      body: PageList(
        onRefresh: () async {
          ref.invalidate(mutesProvider);
          ref.invalidate(blockedProvider);
          await ref.read(mutesProvider.future);
        },
        children: [
          const SizedBox(height: 8),
          Text(tr.moderationIntro, style: TextStyle(color: c.textMuted, fontSize: 14.5, height: 1.35)),
          SectionTitle(tr.mutedPeopleAndEvents),
          AsyncBody<List<MuteEntry>>(
            value: mutes,
            skeletonRows: 2,
            onRetry: () => ref.invalidate(mutesProvider),
            builder: (list) => list.isEmpty
                ? Text(tr.nothingMuted, style: TextStyle(color: c.textMuted))
                : RowsCard(children: [
                    for (final m in list)
                      m.isPerson
                          ? row(
                              leading: Avatar(name: m.userName ?? '?', size: 40),
                              title: m.userName ?? '?',
                              subtitle: [handle(m.username), tr.eventsMuted].where((s) => s.isNotEmpty).join(' · '),
                              action: tr.unmute,
                              onTap: () => _run(ref, () => ref.read(apiProvider).deleteMute(m.id), tr.personUnmuted(m.userName ?? '')),
                            )
                          : row(
                              leading: CircleAvatar(backgroundColor: c.secondaryFill, child: Icon(LucideIcons.bellOff, color: c.textMuted, size: 20)),
                              title: m.eventTitle ?? tr.rdvGeneric,
                              subtitle: m.eventAt == null ? null : formatDate(m.eventAt!),
                              action: tr.unmute,
                              onTap: () => _run(ref, () => ref.read(apiProvider).deleteMute(m.id), tr.eventUnmuted),
                            ),
                  ]),
          ),
          SectionTitle(tr.blockedPeople),
          AsyncBody<List<BlockedUser>>(
            value: blocked,
            skeletonRows: 1,
            onRetry: () => ref.invalidate(blockedProvider),
            builder: (list) => list.isEmpty
                ? Text(tr.nobodyBlocked, style: TextStyle(color: c.textMuted))
                : RowsCard(children: [
                    for (final b in list)
                      row(
                        leading: Avatar(name: b.name, size: 40, userId: b.userId),
                        title: b.name,
                        subtitle: handle(b.username),
                        action: tr.unblock,
                        onTap: () => _run(ref, () => ref.read(apiProvider).unblockUser(b.userId), tr.unblocked(b.name)),
                      ),
                  ]),
          ),
          const SizedBox(height: 12),
          Text(tr.unblockHint, style: TextStyle(color: c.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}
