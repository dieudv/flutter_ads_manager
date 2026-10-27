import 'ad_format.dart';

/// All ad display rules. Pure Dart, no SDK dependency.
class AdRules {
  const AdRules({
    this.minActiveDays = 1,
    this.minSessionTime = Duration.zero,
    this.fullscreenCooldown = const Duration(seconds: 60),
    this.cooldownOverrides = const {},
    this.rewardedBypassRules = true,
    this.disableBlocksPassiveAds = true,
    this.appOpenMaxAge = const Duration(hours: 4),
    this.sessionResetAfterBackground = const Duration(minutes: 30),
    this.maxLoadRetries = 5,
  });

  /// Ads are shown only when the number of active days is >= this value.
  /// The first day the app is opened counts as day 1, so `3` means ads start on the 3rd active day.
  final int minActiveDays;

  /// Minimum time spent in a session before ads may be shown
  /// (does not apply to App Open, which is shown when the app opens or resumes).
  final Duration minSessionTime;

  /// Minimum gap between any two full-screen ads
  /// (measured from when the previous ad was CLOSED).
  final Duration fullscreenCooldown;

  /// Per-format cooldown that overrides [fullscreenCooldown].
  /// The reference timestamp is still shared; only the required gap differs.
  final Map<AdFormat, Duration> cooldownOverrides;

  /// Rewarded ads (user-initiated) skip: active days, session time, cooldown
  /// and the disabled state. Only blocked for premium users.
  final bool rewardedBypassRules;

  /// `true`: disableAdsFor also hides banner/native. `false`: only blocks full-screen ads.
  final bool disableBlocksPassiveAds;

  /// An App Open ad older than this is considered expired and must be reloaded.
  final Duration appOpenMaxAge;

  /// Staying in the background longer than this starts a new session (resets [minSessionTime]).
  final Duration sessionResetAfterBackground;

  /// Number of automatic retries after a load failure (exponential backoff 2s, 4s, 8s... up to 60s).
  final int maxLoadRetries;

  Duration cooldownFor(AdFormat f) => cooldownOverrides[f] ?? fullscreenCooldown;

  AdRules copyWith({
    int? minActiveDays,
    Duration? minSessionTime,
    Duration? fullscreenCooldown,
    Map<AdFormat, Duration>? cooldownOverrides,
    bool? rewardedBypassRules,
    bool? disableBlocksPassiveAds,
    Duration? appOpenMaxAge,
    Duration? sessionResetAfterBackground,
    int? maxLoadRetries,
  }) =>
      AdRules(
        minActiveDays: minActiveDays ?? this.minActiveDays,
        minSessionTime: minSessionTime ?? this.minSessionTime,
        fullscreenCooldown: fullscreenCooldown ?? this.fullscreenCooldown,
        cooldownOverrides: cooldownOverrides ?? this.cooldownOverrides,
        rewardedBypassRules: rewardedBypassRules ?? this.rewardedBypassRules,
        disableBlocksPassiveAds: disableBlocksPassiveAds ?? this.disableBlocksPassiveAds,
        appOpenMaxAge: appOpenMaxAge ?? this.appOpenMaxAge,
        sessionResetAfterBackground: sessionResetAfterBackground ?? this.sessionResetAfterBackground,
        maxLoadRetries: maxLoadRetries ?? this.maxLoadRetries,
      );
}
