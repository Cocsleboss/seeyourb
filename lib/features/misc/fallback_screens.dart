// §4.14 Écrans de secours: splash, offline, not found, deleted item.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/errors.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../ui/kit.dart';
import '../../ui/logo.dart';
import '../../ui/scaffold.dart';
import '../../core/i18n.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final c = context.colors;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SeeULogo(size: 72),
            const SizedBox(height: 24),
            if (session.profileError != null) ...[
              Text(errorMessage(session.profileError!), textAlign: TextAlign.center, style: TextStyle(color: c.textMuted, fontSize: 15)),
              const SizedBox(height: 16),
              AppButton(tr.retry, icon: LucideIcons.rotateCw, onAsync: session.reloadProfile),
              TextButton(
                onPressed: () => ref.read(supabaseProvider).auth.signOut(),
                child: Text(tr.signOut, style: TextStyle(color: c.brandText)),
              ),
            ] else
              const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5)),
          ]),
        ),
      ),
    );
  }
}

class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key, required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: EmptyState(
            icon: LucideIcons.wifiOff,
            title: tr.offlineTitle,
            message: tr.offlineMessage,
            actions: [AppButton(tr.retry, icon: LucideIcons.rotateCw, onPressed: onRetry)],
          ),
        ),
      ),
    );
  }
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: tr.pageNotFound,
      back: true,
      body: EmptyState(
        icon: LucideIcons.compass,
        title: tr.pageNotFound,
        message: tr.pageNotFoundMessage,
        actions: [AppButton(tr.backHome, onPressed: () => context.go('/'))],
      ),
    );
  }
}

/// "Contact ou rendez-vous introuvable".
class MissingItem extends StatelessWidget {
  const MissingItem({super.key, required this.title, required this.backLabel, required this.backPath});
  final String title;
  final String backLabel;
  final String backPath;
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
      back: true,
      body: EmptyState(
        icon: LucideIcons.searchX,
        title: title,
        message: tr.maybeDeleted,
        actions: [AppButton(backLabel, onPressed: () => context.go(backPath))],
      ),
    );
  }
}

/// The account was suspended by a moderator: nothing else is usable.
class BannedScreen extends ConsumerWidget {
  const BannedScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SeeULogo(size: 56),
              const SizedBox(height: 20),
              Icon(LucideIcons.shieldAlert, size: 40, color: c.tone(Tone.red).text),
              const SizedBox(height: 12),
              Text(tr.bannedTitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.text)),
              const SizedBox(height: 10),
              Text(tr.bannedMessage, textAlign: TextAlign.center, style: TextStyle(fontSize: 15.5, color: c.text, height: 1.4)),
              const SizedBox(height: 10),
              Text(tr.bannedHelp, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: c.textMuted, height: 1.4)),
              const SizedBox(height: 24),
              AppButton(tr.signOut, icon: LucideIcons.logOut, variant: ButtonVariant.outline, onAsync: () => ref.read(supabaseProvider).auth.signOut()),
            ]),
          ),
        ),
      ),
    );
  }
}
