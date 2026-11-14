// "Activer les rappels" banner (§4.3 item 2). Dismissed → comes back after 7 days.
import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/push.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../ui/feedback.dart';
import '../../ui/kit.dart';

const _dismissKey = 'seeu.push-banner-dismissed';

final pushPermissionProvider = FutureProvider<PushPermission>((ref) => PushService.instance.permission());

class PushBanner extends ConsumerStatefulWidget {
  const PushBanner({super.key});
  @override
  ConsumerState<PushBanner> createState() => _PushBannerState();
}

class _PushBannerState extends ConsumerState<PushBanner> {
  bool? _dismissed;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final at = p.getInt(_dismissKey) ?? 0;
      if (mounted) setState(() => _dismissed = DateTime.now().millisecondsSinceEpoch - at < const Duration(days: 7).inMilliseconds);
    }).catchError((_) {
      if (mounted) setState(() => _dismissed = false);
    });
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    try {
      (await SharedPreferences.getInstance()).setInt(_dismissKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> _enable() async {
    setState(() => _busy = true);
    final res = await PushService.instance.enable(ref.read(apiProvider));
    if (!mounted) return;
    setState(() => _busy = false);
    ref.invalidate(pushPermissionProvider);
    if (res == PushPermission.granted) showToast('Notifications activées 🎉');
  }

  @override
  Widget build(BuildContext context) {
    final perm = ref.watch(pushPermissionProvider).value;
    if (_dismissed != false || perm == null || perm == PushPermission.granted || perm == PushPermission.unsupported) {
      return const SizedBox.shrink();
    }
    final c = context.colors;
    final blocked = perm == PushPermission.denied;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: AppCard(
        color: c.brandSoft,
        borderColor: c.isDark ? Palette.brand900 : Palette.brand200,
        child: Stack(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
              child: Icon(blocked ? LucideIcons.bellOff : LucideIcons.bellRing, color: c.brandText),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(blocked ? 'Notifications bloquées' : 'Activer les rappels',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: c.text)),
                  const SizedBox(height: 4),
                  Text(
                    blocked
                        ? 'Autorisez-les dans les réglages de votre téléphone (Notifications → SeeU), ou activez les rappels par email dans les Réglages de l\'app.'
                        : 'Recevez une notification quand un contact est à recontacter et avant chaque rendez-vous.',
                    style: TextStyle(fontSize: 14, color: c.textMuted, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  if (blocked)
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      AppButton('Ouvrir les réglages',
                          size: ButtonSize.sm, onPressed: () => AppSettings.openAppSettings(type: AppSettingsType.notification)),
                      AppButton('Réglages SeeU', size: ButtonSize.sm, variant: ButtonVariant.ghost, onPressed: () => context.go('/settings')),
                    ])
                  else
                    AppButton('Activer', icon: LucideIcons.bell, size: ButtonSize.sm, loading: _busy, onPressed: _enable),
                ]),
              ),
            ),
          ]),
          Positioned(
            right: -8,
            top: -8,
            child: IconButton(
              tooltip: 'Fermer',
              onPressed: _dismiss,
              icon: Icon(LucideIcons.x, size: 18, color: c.textMuted),
            ),
          ),
        ]),
      ),
    );
  }
}
