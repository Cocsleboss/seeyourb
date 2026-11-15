# Ads — what is ready, how to turn them on

Nothing is shown today. The app has the **placements**, a provider-agnostic
**`AdsService`** and a clean **"Sponsorisé" tile**; plugging an ad network is a
self-contained change in `lib/ads/`.

## Placements (`AdPlacement`)

| Placement | Where | Frequency |
| --- | --- | --- |
| `homeAgenda` | Home → Mon agenda, under the upcoming events | 1 tile |
| `friendsFeed` | Home → Entre amis | after the 3rd event, then every 5 |
| `exploreFeed` | Home → Explorer (public events) | after the 3rd event, then every 5 |
| `history` | History list, after the first month | 1 tile |
| `publicEvent` | Public event page (preview), under the details | 1 tile |

Never in: chats, forms, invitations, settings, private events. Those would feel
intrusive in a "people you care about" app.

Other places that could work later: the day review of the history calendar (one
tile under the photos), the end of the contact import flow ("all done" screen),
and sponsored public events in Explorer (a native "event" format sold directly,
marked *Sponsorisé*, which fits better than generic banners).

To review the placements with grey placeholders:
`flutter run --dart-define-from-file=config/env.json --dart-define=ADS_DEMO=true`.

## Going live (Google AdMob + Meta through mediation)

1. Create an AdMob account, an app per platform and **native** ad units (one per placement).
2. `flutter pub add google_mobile_ads` and add the AdMob app ids:
   - Android `AndroidManifest.xml`: `<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="ca-app-pub-…~…"/>`
   - iOS `Info.plist`: `GADApplicationIdentifier`, `SKAdNetworkItems`, and
     `NSUserTrackingUsageDescription` (+ the `app_tracking_transparency` package).
3. **Consent first** (EU/UK users — GDPR): use the UMP SDK (`ConsentInformation` /
   `ConsentForm` in google_mobile_ads) at startup, then the iOS ATT prompt, and only
   then `MobileAds.instance.initialize()`. Without consent, request non-personalized ads.
4. Implement `AdsService` (e.g. `AdMobAdsService`) that preloads one `NativeAd` per
   placement (a `NativeTemplateStyle` "small" template matches the tile) and returns an
   `AdWidget` from `nativeAd()`, or `null` when nothing is loaded. Register it in
   `adsServiceProvider`. `AdTile` already adds the "Sponsorisé" label and takes no space
   when there is no ad.
5. **Meta Audience Network**: add it as a mediation network in AdMob, then add the
   `gma_mediation_meta` package. No code change in the app.
6. Store listings: declare ads ("Contains ads" on Google Play, data collection in the
   App Store privacy labels) and add an ad-free option to the privacy policy if relevant.
