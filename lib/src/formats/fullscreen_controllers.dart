import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'fullscreen_ad_controller.dart';

// Mỗi class dưới đây chỉ chứa phần gọi SDK của đúng một format.
// Nếu google_mobile_ads đổi API thì chỉ cần sửa file này.

class InterstitialController extends FullscreenAdController<InterstitialAd> {
  InterstitialController(super.host, super.placement);

  @override
  void requestAd(String unitId, AdRequest request, void Function(InterstitialAd) onLoaded, void Function(LoadAdError) onFailed) {
    InterstitialAd.load(
      adUnitId: unitId,
      request: request,
      adLoadCallback: InterstitialAdLoadCallback(onAdLoaded: onLoaded, onAdFailedToLoad: onFailed),
    );
  }

  @override
  void present(InterstitialAd ad, FullScreenContentCallback<InterstitialAd> callback, AdPaidCallback onPaid, void Function(RewardItem) onReward) {
    ad
      ..fullScreenContentCallback = callback
      ..onPaidEvent = onPaid
      ..show();
  }
}

class RewardedInterstitialController extends FullscreenAdController<RewardedInterstitialAd> {
  RewardedInterstitialController(super.host, super.placement);

  @override
  void requestAd(String unitId, AdRequest request, void Function(RewardedInterstitialAd) onLoaded, void Function(LoadAdError) onFailed) {
    RewardedInterstitialAd.load(
      adUnitId: unitId,
      request: request,
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(onAdLoaded: onLoaded, onAdFailedToLoad: onFailed),
    );
  }

  @override
  void present(RewardedInterstitialAd ad, FullScreenContentCallback<RewardedInterstitialAd> callback, AdPaidCallback onPaid, void Function(RewardItem) onReward) {
    ad
      ..fullScreenContentCallback = callback
      ..onPaidEvent = onPaid
      ..show(onUserEarnedReward: (_, reward) => onReward(reward));
  }
}

class RewardedController extends FullscreenAdController<RewardedAd> {
  RewardedController(super.host, super.placement);

  @override
  void requestAd(String unitId, AdRequest request, void Function(RewardedAd) onLoaded, void Function(LoadAdError) onFailed) {
    RewardedAd.load(
      adUnitId: unitId,
      request: request,
      rewardedAdLoadCallback: RewardedAdLoadCallback(onAdLoaded: onLoaded, onAdFailedToLoad: onFailed),
    );
  }

  @override
  void present(RewardedAd ad, FullScreenContentCallback<RewardedAd> callback, AdPaidCallback onPaid, void Function(RewardItem) onReward) {
    ad
      ..fullScreenContentCallback = callback
      ..onPaidEvent = onPaid
      ..show(onUserEarnedReward: (_, reward) => onReward(reward));
  }
}

class AppOpenController extends FullscreenAdController<AppOpenAd> {
  AppOpenController(super.host, super.placement);

  @override
  Duration? get maxAge => host.rules.appOpenMaxAge;

  @override
  void requestAd(String unitId, AdRequest request, void Function(AppOpenAd) onLoaded, void Function(LoadAdError) onFailed) {
    AppOpenAd.load(
      adUnitId: unitId,
      request: request,
      adLoadCallback: AppOpenAdLoadCallback(onAdLoaded: onLoaded, onAdFailedToLoad: onFailed),
    );
  }

  @override
  void present(AppOpenAd ad, FullScreenContentCallback<AppOpenAd> callback, AdPaidCallback onPaid, void Function(RewardItem) onReward) {
    ad
      ..fullScreenContentCallback = callback
      ..onPaidEvent = onPaid
      ..show();
  }
}
