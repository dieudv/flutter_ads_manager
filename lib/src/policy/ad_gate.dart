/// Why an ad is blocked (useful when QA asks why an ad is not showing).
enum AdBlockReason {
  none,
  unsupportedPlatform,
  notInitialized,
  consentRequired,
  placementDisabled,
  premium,
  notEnoughActiveDays,
  temporarilyDisabled,
  sessionTooShort,
  cooldown,
  fullscreenShowing,
}

class AdGateResult {
  const AdGateResult.ok()
      : reason = AdBlockReason.none,
        retryAfter = null;

  const AdGateResult.blocked(this.reason, {this.retryAfter});

  final AdBlockReason reason;

  /// Hint for how long until the block ends (cooldown, disable, session).
  final Duration? retryAfter;

  bool get allowed => reason == AdBlockReason.none;

  @override
  String toString() => allowed
      ? 'allowed'
      : 'blocked(${reason.name}${retryAfter != null ? ', retry in ${retryAfter!.inSeconds}s' : ''})';
}
