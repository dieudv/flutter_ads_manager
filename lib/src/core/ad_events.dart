import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_placement.dart';
import '../policy/ad_gate.dart';

/// Listens to ad events so they can be forwarded to analytics (Firebase, AppsFlyer...).
/// Extend this class and override only the callbacks you need.
class AdsEventListener {
  const AdsEventListener();

  void onAdLoaded(AdPlacement placement) {}
  void onAdLoadFailed(AdPlacement placement, LoadAdError error) {}
  void onAdShown(AdPlacement placement) {}
  void onAdImpression(AdPlacement placement) {}
  void onAdClicked(AdPlacement placement) {}
  void onAdDismissed(AdPlacement placement) {}
  void onAdShowFailed(AdPlacement placement, AdError error) {}
  void onAdBlocked(AdPlacement placement, AdGateResult gate) {}
  void onAdRewardEarned(AdPlacement placement, RewardItem reward) {}

  /// Revenue per impression. [valueMicros] is in micro units (1e-6).
  void onAdPaid(AdPlacement placement, double valueMicros, PrecisionType precision, String currencyCode) {}
}
