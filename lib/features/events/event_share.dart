// "Inviter avec un lien": a secret link anyone can use to join the event
// (private or friends events). The organizer always may create one; guests
// only when the event lets them invite. Clear warning: whoever has the link
// can join.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config.dart';
import '../../core/i18n.dart';
import '../../core/links.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../ui/feedback.dart';
import '../../ui/copy_link.dart';
import '../../ui/kit.dart';

Future<void> showEventLinkSheet(BuildContext context, {required String eventId, required String title, required bool isOrganizer}) =>
    showAppSheet(
      context,
      title: tr.inviteWithLink,
      builder: (_) => _EventLinkBody(eventId: eventId, title: title, isOrganizer: isOrganizer),
    );

class _EventLinkBody extends ConsumerStatefulWidget {
  const _EventLinkBody({required this.eventId, required this.title, required this.isOrganizer});
  final String eventId;
  final String title;
  final bool isOrganizer;
  @override
  ConsumerState<_EventLinkBody> createState() => _EventLinkBodyState();
}

class _EventLinkBodyState extends ConsumerState<_EventLinkBody> {
  bool _loading = true;
  bool _busy = false;
  String? _token;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await guard(() => ref.read(apiProvider).myEventLink(widget.eventId));
    if (!mounted) return;
    setState(() {
      _token = token;
      _loading = false;
    });
  }

  Future<void> _create({bool renew = false}) async {
    setState(() => _busy = true);
    final token = await guard(() => ref.read(apiProvider).createEventLink(widget.eventId, renew: renew),
        success: renew ? tr.linkRenewed : null);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (token != null) _token = token;
    });
  }

  Future<void> _revoke() async {
    final ok = await confirmSheet(
      context,
      title: tr.disableLinkTitle,
      message: widget.isOrganizer ? tr.disableLinkMessageOrganizer : tr.disableLinkMessage,
      confirmLabel: tr.disableLink,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final done = await guard(() async {
      await ref.read(apiProvider).revokeEventLink(widget.eventId, all: widget.isOrganizer);
      return true;
    }, success: tr.linkDisabled);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (done != null) _token = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final warning = InfoBox(
      tone: Tone.amber,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(LucideIcons.triangleAlert, size: 18, color: c.tone(Tone.amber).text),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr.linkAnyoneTitle, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: c.tone(Tone.amber).fg)),
            const SizedBox(height: 2),
            Text(tr.linkAnyoneBody, style: TextStyle(fontSize: 13.5, height: 1.35, color: c.tone(Tone.amber).fg)),
          ]),
        ),
      ]),
    );
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    }
    final token = _token;
    if (token == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr.inviteWithLinkHelp, style: TextStyle(color: c.textMuted, fontSize: 14, height: 1.4)),
        const SizedBox(height: 12),
        warning,
        const SizedBox(height: 16),
        AppButton(tr.createLink, icon: LucideIcons.link, full: true, loading: _busy, onPressed: _busy ? null : _create),
      ]);
    }
    final link = eventInviteLink(token);
    final appLink = eventInviteAppLink(token);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      warning,
      const SizedBox(height: 14),
      CopyLinkBox(link: link),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: CopyLinkButton(link: link)),
        const SizedBox(width: 8),
        Expanded(
          child: AppButton(tr.share,
              icon: LucideIcons.share2,
              size: ButtonSize.sm,
              full: true,
              onPressed: () => SharePlus.instance.share(ShareParams(text: tr.shareInviteText(widget.title, link)))),
        ),
      ]),
      if (Config.showAppLinks) ...[
        const SizedBox(height: 16),
        TestAppLink(link: appLink),
      ],
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: AppButton(tr.newLink,
              icon: LucideIcons.refreshCw,
              variant: ButtonVariant.secondary,
              size: ButtonSize.sm,
              full: true,
              onPressed: _busy ? null : () => _create(renew: true)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AppButton(tr.disableLink,
              icon: LucideIcons.unlink, variant: ButtonVariant.danger, size: ButtonSize.sm, full: true, onPressed: _busy ? null : _revoke),
        ),
      ]),
      const SizedBox(height: 8),
      Text(tr.newLinkHelp, style: TextStyle(color: c.textSubtle, fontSize: 12, height: 1.35)),
    ]);
  }
}
