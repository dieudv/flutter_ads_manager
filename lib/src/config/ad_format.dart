/// AdMob ad unit types.
enum AdFormat {
  banner,
  interstitial,
  rewardedInterstitial,
  rewarded,
  nativeAdvanced,
  appOpen,
}

extension AdFormatX on AdFormat {
  /// Full-screen ads (they share a single cooldown reference).
  bool get isFullscreen => this != AdFormat.banner && this != AdFormat.nativeAdvanced;
}
