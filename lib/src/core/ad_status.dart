import '../policy/ad_gate.dart';

enum AdStatus { idle, loading, loaded, showing, failed }

enum AdShowStatus {
  /// The ad was shown and closed.
  shown,

  /// Blocked by the rules (see [AdShowResult.gate]).
  blocked,

  /// Not loaded yet. The manager loads it so it is available next time.
  notReady,

  /// The SDK reported an error while showing.
  failed,
}

/// Result of `show*`. The Future completes AFTER the ad closes, so you can
/// `await` it and then navigate onward.
class AdShowResult {
  const AdShowResult._(this.status, {this.gate, this.rewardEarned = false});

  const AdShowResult.shown({bool rewardEarned = false})
      : this._(AdShowStatus.shown, rewardEarned: rewardEarned);
  const AdShowResult.blocked(AdGateResult gate) : this._(AdShowStatus.blocked, gate: gate);
  const AdShowResult.notReady() : this._(AdShowStatus.notReady);
  const AdShowResult.failed() : this._(AdShowStatus.failed);

  final AdShowStatus status;
  final AdGateResult? gate;

  /// Only meaningful for rewarded / rewarded interstitial.
  final bool rewardEarned;

  bool get shown => status == AdShowStatus.shown;

  @override
  String toString() => 'AdShowResult(${status.name}${gate != null ? ', $gate' : ''}, rewardEarned=$rewardEarned)';
}
