/// Các loại ad unit của AdMob.
enum AdFormat {
  banner,
  interstitial,
  rewardedInterstitial,
  rewarded,
  nativeAdvanced,
  appOpen,
}

extension AdFormatX on AdFormat {
  /// Quảng cáo toàn màn hình (dùng chung một mốc cooldown).
  bool get isFullscreen => this != AdFormat.banner && this != AdFormat.nativeAdvanced;
}
