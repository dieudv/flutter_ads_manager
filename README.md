# ads_manager

Reusable AdMob management for Flutter projects. The display rules (pure Dart, unit-testable) are separated from the code that calls the SDK.

> Target versions: `google_mobile_ads ^9.1.0`, Flutter >= 3.38.1.
> This code has not been compiled in the environment where it was written. Run `flutter pub get && flutter analyze && flutter test` first. All SDK calls live in `formats/fullscreen_controllers.dart`, `widgets/*` and `consent/consent_helper.dart`, so if the SDK API differs, fix it in those files.

## Installation

```yaml
dependencies:
  ads_manager:
    path: ../ads_manager        # or git: url
```

Declare your App ID as described by `google_mobile_ads`:
- Android: `<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" .../>` in `AndroidManifest.xml`
- iOS: `GADApplicationIdentifier` (and `SKAdNetworkItems`) in `Info.plist`

## Quick start

```dart
// 1. Declare placements in one file
abstract class AppAds {
  static const homeBanner   = AdPlacement.banner('home_banner',   android: '...', ios: '...');
  static const detailBanner = AdPlacement.banner('detail_banner', android: '...', ios: '...');
  static const afterSave    = AdPlacement.interstitial('after_save', android: '...', ios: '...');
  static const removeAds    = AdPlacement.rewarded('remove_ads', android: '...', ios: '...');
  static const appOpen      = AdPlacement.appOpen('app_open', android: '...', ios: '...');
}

// 2. Initialize in main()
await AdsManager.I.initialize(
  const AdsConfig(
    rules: AdRules(minActiveDays: 3, minSessionTime: Duration(seconds: 30)),
    appOpenPlacement: AppAds.appOpen,
    preload: [AppAds.afterSave, AppAds.removeAds],
  ),
  isPremium: purchased,
  gatherConsent: true,
);

// 3. Use
const AdsBanner(placement: AppAds.homeBanner);
await AdsManager.I.showInterstitial(AppAds.afterSave);  // completes when the ad closes
final r = await AdsManager.I.showRewarded(AppAds.removeAds);
if (r.rewardEarned) await AdsManager.I.disableAdsFor(const Duration(hours: 24), accumulate: true);
AdsManager.I.setPremium(true);
```

In debug mode Google's test ids are used automatically (set `AdsConfig.useTestIds` to force either way).

## Display rules

| Rule | Configuration | Notes |
|---|---|---|
| Minimum active days | `AdRules.minActiveDays` | The first day the app is opened is day 1. The day changes by local time, and it is also checked when the app resumes after staying in the background overnight. |
| Full-screen cooldown | `fullscreenCooldown`, `cooldownOverrides` | One shared reference time for Interstitial, Rewarded Interstitial, Rewarded and App Open, measured from when the ad closes. Kept in memory (reset when the app is killed). |
| Timed disable | `disableAdsFor(d, accumulate:)` | Persisted. `accumulate: true` adds to the remaining time, `false` resets to now + d. `disableBlocksPassiveAds` chooses whether banner/native are hidden too. |
| Minimum session time | `minSessionTime` | Counted per session (reset after the app stays in the background longer than `sessionResetAfterBackground`). App Open is exempt because it is shown when the app opens or resumes. |
| Premium | `setPremium(bool)` | Blocks everything, including rewarded; stops loading and discards held ads. |
| Rewarded | `rewardedBypassRules` | By default skips days, session time, cooldown and disable (so users can accumulate time). It still updates the cooldown reference when closed. |

Banner/native ads load only while their widget is mounted and the rules allow it; full-screen ads are preloaded and shown as soon as the rules allow.

## Ad state for UI

- `AdReadyBuilder(placement:, builder: (ctx, isReady) => ...)`
- `AdsEnabledBuilder(builder: (ctx, enabled) => ...)`
- `AdsManager.I.adsEnabled`, `isPremium`, `disabledRemaining` (countdown) and `statusOf(placement)` are `ValueListenable`s.
- `AdsManager.I.explain(placement)` returns why a placement is blocked; `debugSummary()` prints the state of the rules.

## App Open

- Cold start: call `await AdsManager.I.showAppOpenOnLaunch()` on the splash screen.
- Resume: shown automatically when `autoShowAppOpenOnResume` is on (the default). It is not shown right after another full-screen ad closes.
- Wrap the image picker, permission requests and share sheets with `AdsManager.I.runWithoutAppOpen(() async {...})`.

## Analytics

```dart
class MyListener extends AdsEventListener {
  @override
  void onAdPaid(AdPlacement p, double valueMicros, PrecisionType t, String currency) { /* send to Firebase */ }
}
AdsManager.I.addEventListener(MyListener());
```

## Remote Config

```dart
AdsManager.I.updateConfig(config.copyWith(
  rules: config.rules.copyWith(fullscreenCooldown: const Duration(seconds: 90)),
  disabledPlacements: {'home_banner'},
));
```

## Structure

```
lib/src/
  config/    AdFormat, AdPlacement, AdRules, AdsConfig
  policy/    AdPolicy (rules, pure Dart), AdGateResult
  storage/   AdStorage, MemoryAdStorage, SharedPrefsAdStorage
  formats/   FullscreenAdController + 4 controllers that call the SDK
  widgets/   AdsBanner, AdsNative, AdReadyBuilder, AdsEnabledBuilder
  core/      AdsManager, AdsEventListener, AdStatus, AdShowResult
  consent/   ConsentHelper (UMP)
```

## Known limitations

- Changing the device clock can corrupt the active-day count and the disable timer (the device time is used).
- Several banner widgets sharing one placement share one `statusOf`; the status belongs to the widget that updated it last.
- There is no debug overlay yet; use `explain()` / `debugSummary()`.
