// Sharing my profile (and an event): copy the link, the phone's share sheet
// (Instagram, WhatsApp, Messenger…), or a QR code to scan.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/i18n.dart';
import '../../core/links.dart';
import '../../core/theme.dart';
import '../../ui/feedback.dart';
import '../../ui/kit.dart';

Future<void> shareProfile(String username) =>
    SharePlus.instance.share(ShareParams(text: tr.shareProfileText(username, profileLink(username))));

Future<void> copyProfileLink(String username) async {
  await Clipboard.setData(ClipboardData(text: profileLink(username)));
  showToast(tr.linkCopied);
}

Future<void> shareEvent(String eventId, String title) =>
    SharePlus.instance.share(ShareParams(text: tr.shareEventText(title, eventLink(eventId))));

Future<void> showProfileQr(BuildContext context, String username) => showAppSheet(
      context,
      title: tr.qrCodeTitle,
      subtitle: tr.qrCodeHelp,
      builder: (_) => _QrBody(username: username),
    );

class _QrBody extends StatelessWidget {
  const _QrBody({required this.username});
  final String username;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          // Always dark on white: scanners need the contrast, also in dark mode.
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: QrImageView(
            data: profileLink(username),
            size: 220,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Palette.gray900),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Palette.gray900),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text('@$username', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: c.text)),
      const SizedBox(height: 16),
      AppButton(tr.share, icon: LucideIcons.share2, full: true, onPressed: () => shareProfile(username)),
    ]);
  }
}

/// "Votre lien de profil" card: the link, Copy / Share / QR code.
class ProfileLinkCard extends StatelessWidget {
  const ProfileLinkCard({super.key, required this.username});
  final String username;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr.myProfileLink, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: c.text)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: c.secondaryFill, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(LucideIcons.link, size: 18, color: c.brandText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(profileLink(username),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.text, fontWeight: FontWeight.w500)),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        Text(tr.myProfileLinkHelp, style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.35)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: AppButton(tr.copyLink,
                icon: LucideIcons.copy, variant: ButtonVariant.secondary, size: ButtonSize.sm, full: true, onPressed: () => copyProfileLink(username)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppButton(tr.share, icon: LucideIcons.share2, size: ButtonSize.sm, full: true, onPressed: () => shareProfile(username)),
          ),
        ]),
        const SizedBox(height: 8),
        AppButton(tr.showQrCode,
            icon: LucideIcons.qrCode, variant: ButtonVariant.secondary, size: ButtonSize.sm, full: true, onPressed: () => showProfileQr(context, username)),
      ]),
    );
  }
}
