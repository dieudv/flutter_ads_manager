import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_placement.dart';
import '../policy/ad_gate.dart';

/// Lắng nghe sự kiện quảng cáo để đẩy vào analytics (Firebase, AppsFlyer...).
/// Extend class này và chỉ override những callback cần dùng.
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

  /// Doanh thu theo từng lần hiển thị. [valueMicros] là đơn vị micro (1e-6).
  void onAdPaid(AdPlacement placement, double valueMicros, PrecisionType precision, String currencyCode) {}
}
