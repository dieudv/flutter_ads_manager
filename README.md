# ads_manager

Quản lý AdMob dùng lại được cho nhiều project Flutter. Tách "luật hiển thị" (thuần Dart, test được) khỏi phần gọi SDK.

> Phiên bản mục tiêu: `google_mobile_ads ^9.1.0`, Flutter ≥ 3.38.1.
> Code chưa được compile trong môi trường tạo ra nó. Hãy chạy `flutter pub get && flutter analyze && flutter test` trước. Mọi chỗ gọi SDK nằm ở `formats/fullscreen_controllers.dart`, `widgets/*` và `consent/consent_helper.dart` nên nếu SDK lệch API thì sửa trong các file này.

## Cài đặt

```yaml
dependencies:
  ads_manager:
    path: ../ads_manager        # hoặc git: url
```

Khai báo App ID theo hướng dẫn của `google_mobile_ads`:
- Android: `<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" .../>` trong `AndroidManifest.xml`
- iOS: `GADApplicationIdentifier` (và `SKAdNetworkItems`) trong `Info.plist`

## Dùng nhanh

```dart
// 1. Khai báo placement ở một file
abstract class AppAds {
  static const homeBanner   = AdPlacement.banner('home_banner',   android: '...', ios: '...');
  static const detailBanner = AdPlacement.banner('detail_banner', android: '...', ios: '...');
  static const afterSave    = AdPlacement.interstitial('after_save', android: '...', ios: '...');
  static const removeAds    = AdPlacement.rewarded('remove_ads', android: '...', ios: '...');
  static const appOpen      = AdPlacement.appOpen('app_open', android: '...', ios: '...');
}

// 2. Khởi tạo trong main()
await AdsManager.I.initialize(
  const AdsConfig(
    rules: AdRules(minActiveDays: 3, minSessionTime: Duration(seconds: 30)),
    appOpenPlacement: AppAds.appOpen,
    preload: [AppAds.afterSave, AppAds.removeAds],
  ),
  isPremium: purchased,
  gatherConsent: true,
);

// 3. Dùng
const AdsBanner(placement: AppAds.homeBanner);
await AdsManager.I.showInterstitial(AppAds.afterSave);  // xong khi ad đóng
final r = await AdsManager.I.showRewarded(AppAds.removeAds);
if (r.rewardEarned) await AdsManager.I.disableAdsFor(const Duration(hours: 24), accumulate: true);
AdsManager.I.setPremium(true);
```

Debug mode tự dùng test id của Google (`AdsConfig.useTestIds` để ép).

## Luật hiển thị

| Luật | Cấu hình | Ghi chú |
|---|---|---|
| Số ngày hoạt động tối thiểu | `AdRules.minActiveDays` | Ngày mở app đầu tiên là ngày 1. Đổi ngày theo giờ local, kiểm tra cả khi app resume sau khi nằm nền qua đêm. |
| Cooldown full-screen | `fullscreenCooldown`, `cooldownOverrides` | Một mốc chung cho Interstitial, Rewarded Interstitial, Rewarded và App Open, tính từ lúc ad đóng. Lưu trong bộ nhớ (reset khi kill app). |
| Tắt theo giờ | `disableAdsFor(d, accumulate:)` | Lưu bền. `accumulate: true` cộng dồn, `false` đặt lại thành now + d. `disableBlocksPassiveAds` chọn có ẩn cả banner/native hay không. |
| Thời gian dùng tối thiểu | `minSessionTime` | Tính theo phiên (reset nếu nền quá `sessionResetAfterBackground`). App Open được miễn vì nó vốn hiện lúc mở app. |
| Premium | `setPremium(bool)` | Chặn tất cả kể cả rewarded, dừng load và huỷ ad đang giữ. |
| Rewarded | `rewardedBypassRules` | Mặc định bỏ qua ngày, phiên, cooldown, disable (để người dùng cộng dồn thời gian). Vẫn cập nhật mốc cooldown khi đóng. |

Banner/native chỉ load khi widget được mount và luật cho phép; full-screen được preload và show ngay khi đủ điều kiện.

## Trạng thái để ẩn/hiện UI

- `AdReadyBuilder(placement:, builder: (ctx, isReady) => ...)`
- `AdsEnabledBuilder(builder: (ctx, enabled) => ...)`
- `AdsManager.I.adsEnabled`, `isPremium`, `disabledRemaining` (đếm ngược), `statusOf(placement)` là `ValueListenable`.
- `AdsManager.I.explain(placement)` trả về lý do bị chặn, `debugSummary()` in trạng thái các luật.

## App Open

- Cold start: ở splash gọi `await AdsManager.I.showAppOpenOnLaunch()`.
- Resume: tự hiện nếu `autoShowAppOpenOnResume` (mặc định bật). Không hiện ngay sau khi đóng ad full-screen khác.
- Bọc image picker, xin quyền, share sheet bằng `AdsManager.I.runWithoutAppOpen(() async {...})`.

## Analytics

```dart
class MyListener extends AdsEventListener {
  @override
  void onAdPaid(AdPlacement p, double valueMicros, PrecisionType t, String currency) { /* gửi Firebase */ }
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

## Cấu trúc

```
lib/src/
  config/    AdFormat, AdPlacement, AdRules, AdsConfig
  policy/    AdPolicy (luật, thuần Dart), AdGateResult
  storage/   AdStorage, MemoryAdStorage, SharedPrefsAdStorage
  formats/   FullscreenAdController + 4 controller gọi SDK
  widgets/   AdsBanner, AdsNative, AdReadyBuilder, AdsEnabledBuilder
  core/      AdsManager, AdsEventListener, AdStatus, AdShowResult
  consent/   ConsentHelper (UMP)
```

## Giới hạn đã biết

- Đổi giờ hệ thống có thể làm sai số ngày hoạt động và thời gian disable (dùng giờ thiết bị).
- Nhiều widget banner cùng một placement chia sẻ một `statusOf`, trạng thái là của widget cập nhật sau cùng.
- Chưa có debug overlay; dùng `explain()` / `debugSummary()`.
