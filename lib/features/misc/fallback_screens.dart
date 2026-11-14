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
              AppButton('Réessayer', icon: LucideIcons.rotateCw, onPressed: session.reloadProfile),
              TextButton(
                onPressed: () => ref.read(supabaseProvider).auth.signOut(),
                child: Text('Se déconnecter', style: TextStyle(color: c.brandText)),
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
            title: 'Vous êtes hors ligne',
            message: 'SeeU a besoin d\'une connexion internet pour fonctionner. Vérifiez votre réseau puis réessayez.',
            actions: [AppButton('Réessayer', icon: LucideIcons.rotateCw, onPressed: onRetry)],
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
      title: 'Page introuvable',
      back: true,
      body: EmptyState(
        icon: LucideIcons.compass,
        title: 'Page introuvable',
        message: 'Cette page n\'existe pas ou plus.',
        actions: [AppButton('Retour à l\'accueil', onPressed: () => context.go('/'))],
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
        message: 'Il a peut-être été supprimé.',
        actions: [AppButton(backLabel, onPressed: () => context.go(backPath))],
      ),
    );
  }
}
