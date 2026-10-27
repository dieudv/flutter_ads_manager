/// Lý do một quảng cáo bị chặn (hữu ích khi QA hỏi "sao ad không hiện").
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

  /// Gợi ý còn bao lâu nữa thì hết bị chặn (cooldown, disable, session).
  final Duration? retryAfter;

  bool get allowed => reason == AdBlockReason.none;

  @override
  String toString() => allowed
      ? 'allowed'
      : 'blocked(${reason.name}${retryAfter != null ? ', retry in ${retryAfter!.inSeconds}s' : ''})';
}
