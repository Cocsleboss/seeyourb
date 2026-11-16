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

/// Fake native ads, to judge how they fit (Settings → Demo ads in debug builds,
/// or --dart-define=ADS_DEMO=true). They look like what AdMob's "small native
/// template" would render: visual, headline, body, advertiser, call to action.
class DemoAdsService implements AdsService {
  const DemoAdsService();

  static const _fr = [
    ('Café Belga', 'Brunch du dimanche -20 %', 'Réservez une table pour 4 et profitez du brunch à prix doux.', LucideIcons.coffee, Color(0xFFF59E0B)),
    ('Cinéma Galeries', 'Avant-premières du mois', 'Une séance offerte pour deux places achetées en ligne.', LucideIcons.clapperboard, Color(0xFFEF4444)),
    ('Escape Bruxelles', 'Le jeu d\'évasion entre amis', '60 minutes pour sortir. Équipes de 3 à 6, dès 19 €/pers.', LucideIcons.keyRound, Color(0xFF8B5CF6)),
    ('Villo!', 'Vos sorties à vélo', 'Abonnement annuel à 39 €. Des stations partout en ville.', LucideIcons.bike, Color(0xFF10B981)),
  ];
  static const _en = [
    ('Café Belga', 'Sunday brunch -20%', 'Book a table for 4 and enjoy brunch at a sweet price.', LucideIcons.coffee, Color(0xFFF59E0B)),
    ('Galeries Cinema', 'This month\'s previews', 'One free ticket for two bought online.', LucideIcons.clapperboard, Color(0xFFEF4444)),
    ('Escape Brussels', 'The escape game for friends', '60 minutes to get out. Teams of 3 to 6, from €19 each.', LucideIcons.keyRound, Color(0xFF8B5CF6)),
    ('Villo!', 'Get around by bike', 'Yearly pass for €39. Stations all over town.', LucideIcons.bike, Color(0xFF10B981)),
  ];

  @override
  Widget? nativeAd(BuildContext context, AdPlacement placement) {
    final ads = currentLanguage == 'fr' ? _fr : _en;
    final (advertiser, headline, body, icon, color) = ads[placement.index % ads.length];
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(headline, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: c.text)),
            const SizedBox(height: 2),
            Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textMuted, fontSize: 13.5, height: 1.3)),
          ]),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Text(advertiser, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSubtle))),
        AppButton(tr.adCta, size: ButtonSize.sm, variant: ButtonVariant.secondary, onPressed: () {}),
      ]),
    ]);
  }
}

const _demoFromEnv = bool.fromEnvironment('ADS_DEMO');

/// Demo ads on/off (debug builds: Settings → Application).
final adsDemoProvider = NotifierProvider<AdsDemo, bool>(AdsDemo.new);

class AdsDemo extends Notifier<bool> {
  @override
  bool build() => _demoFromEnv;
  void set(bool v) => state = v;
}

final adsServiceProvider = Provider<AdsService>((ref) => ref.watch(adsDemoProvider) ? const DemoAdsService() : const NoAdsService());

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
  // Few items: the ad still shows, after the last one.
  if (items.isNotEmpty && items.length < first) out.add(AdTile(placement, key: ValueKey('ad-$placement-end')));
  return out;
}
