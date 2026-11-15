// Ads: placements and a provider-agnostic service. Nothing is shown today.
//
// To go live (see docs/ADS.md): implement AdsService with google_mobile_ads (native
// ads, Meta Audience Network through AdMob mediation), run the consent flow (UMP,
// + App Tracking Transparency on iOS) before loading anything, and register it in
// [adsServiceProvider]. The screens already reserve the slots below.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../ui/kit.dart';

/// Where an ad may appear. Never in chats, forms, invitations or settings.
enum AdPlacement {
  /// "Mes rendez-vous": one tile under the upcoming events.
  homeAgenda,

  /// "Entre amis" feed: a tile every few events.
  friendsFeed,

  /// "Explorer" (public events): a tile every few events.
  exploreFeed,

  /// History list: one tile between months.
  history,

  /// Public event page (not private ones): under the details.
  publicEvent,
}

abstract class AdsService {
  /// A native ad for the placement, or null (no fill, no consent, disabled…).
  /// The returned widget is shown inside [AdTile]'s frame.
  Widget? nativeAd(BuildContext context, AdPlacement placement);
}

/// Today: no ads.
class NoAdsService implements AdsService {
  const NoAdsService();
  @override
  Widget? nativeAd(BuildContext context, AdPlacement placement) => null;
}

/// --dart-define=ADS_DEMO=true: grey placeholders, to review placements in the UI.
class DemoAdsService implements AdsService {
  const DemoAdsService();
  @override
  Widget? nativeAd(BuildContext context, AdPlacement placement) {
    final c = context.colors;
    return Row(children: [
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: c.secondaryFill, borderRadius: BorderRadius.circular(12)),
        child: Icon(LucideIcons.image, color: c.textSubtle),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Annonceur', style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
          const SizedBox(height: 2),
          Text(placement.name, style: TextStyle(color: c.textMuted, fontSize: 13.5)),
        ]),
      ),
    ]);
  }
}

const _demo = bool.fromEnvironment('ADS_DEMO');

final adsServiceProvider = Provider<AdsService>((ref) => _demo ? const DemoAdsService() : const NoAdsService());

/// Clean "Sponsorisé" card around a native ad; takes no space when there is no ad.
class AdTile extends ConsumerWidget {
  const AdTile(this.placement, {super.key, this.padding = const EdgeInsets.only(top: 14)});
  final AdPlacement placement;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ad = ref.watch(adsServiceProvider).nativeAd(context, placement);
    if (ad == null) return const SizedBox.shrink();
    final c = context.colors;
    return Padding(
      padding: padding,
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr.sponsored, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSubtle, letterSpacing: 0.3)),
          const SizedBox(height: 8),
          ad,
        ]),
      ),
    );
  }
}

/// Inserts an ad tile after the [first] item, then every [every] items.
List<Widget> withAds(List<Widget> items, AdPlacement placement, {int first = 3, int every = 6}) {
  final out = <Widget>[];
  for (var i = 0; i < items.length; i++) {
    out.add(items[i]);
    final n = i + 1;
    if (n == first || (n > first && (n - first) % every == 0)) out.add(AdTile(placement, key: ValueKey('ad-$placement-$n')));
  }
  return out;
}
