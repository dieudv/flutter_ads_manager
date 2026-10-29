/// Banner sizes supported by `AdsBanner`.
enum AdsBannerSize {
  /// Anchored adaptive banner (default). Fits the available width and is
  /// meant to stick to the top or bottom edge of the screen.
  anchoredAdaptive,

  /// Inline adaptive banner for banners placed inside scrolling content.
  /// Its height is decided by the SDK (use `AdsBanner.inlineMaxHeight` to cap it).
  inlineAdaptive,

  /// 320x50
  banner,

  /// 320x100
  largeBanner,

  /// 300x250
  mediumRectangle,

  /// 468x60 (tablets)
  fullBanner,

  /// 728x90 (tablets)
  leaderboard;

  bool get isAdaptive => this == anchoredAdaptive || this == inlineAdaptive;
}
