import 'package:ads_manager/ads_manager.dart';

/// Toàn bộ placement của app khai báo tại MỘT chỗ.
/// Id dưới đây là id test chính thức của Google; thay bằng id thật của bạn.
abstract class AppAds {
  static const appOpen = AdPlacement.appOpen('app_open',
      android: 'ca-app-pub-3940256099942544/9257395921', ios: 'ca-app-pub-3940256099942544/5575463023');

  static const homeBanner = AdPlacement.banner('home_banner',
      android: 'ca-app-pub-3940256099942544/6300978111', ios: 'ca-app-pub-3940256099942544/2934735716');
  static const detailBanner = AdPlacement.banner('detail_banner',
      android: 'ca-app-pub-3940256099942544/6300978111', ios: 'ca-app-pub-3940256099942544/2934735716');

  static const afterSave = AdPlacement.interstitial('after_save',
      android: 'ca-app-pub-3940256099942544/1033173712', ios: 'ca-app-pub-3940256099942544/4411468910');

  static const bonusRewardedInter = AdPlacement.rewardedInterstitial('bonus_rewarded_inter',
      android: 'ca-app-pub-3940256099942544/5354046379', ios: 'ca-app-pub-3940256099942544/6978759866');

  static const removeAdsReward = AdPlacement.rewarded('remove_ads_reward',
      android: 'ca-app-pub-3940256099942544/5224354917', ios: 'ca-app-pub-3940256099942544/1712485313');

  static const listNative = AdPlacement.native('list_native',
      android: 'ca-app-pub-3940256099942544/2247696110', ios: 'ca-app-pub-3940256099942544/3986624511');
}
