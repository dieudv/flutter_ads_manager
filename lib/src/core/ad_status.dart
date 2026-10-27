import '../policy/ad_gate.dart';

enum AdStatus { idle, loading, loaded, showing, failed }

enum AdShowStatus {
  /// Ad đã hiển thị và đã đóng.
  shown,

  /// Bị luật chặn (xem [AdShowResult.gate]).
  blocked,

  /// Chưa load xong. Manager sẽ tự load để lần sau dùng được.
  notReady,

  /// SDK báo lỗi khi show.
  failed,
}

/// Kết quả của `show*`. Future hoàn tất SAU KHI ad đóng, nên có thể
/// `await` rồi điều hướng tiếp.
class AdShowResult {
  const AdShowResult._(this.status, {this.gate, this.rewardEarned = false});

  const AdShowResult.shown({bool rewardEarned = false})
      : this._(AdShowStatus.shown, rewardEarned: rewardEarned);
  const AdShowResult.blocked(AdGateResult gate) : this._(AdShowStatus.blocked, gate: gate);
  const AdShowResult.notReady() : this._(AdShowStatus.notReady);
  const AdShowResult.failed() : this._(AdShowStatus.failed);

  final AdShowStatus status;
  final AdGateResult? gate;

  /// Chỉ có ý nghĩa với rewarded / rewarded interstitial.
  final bool rewardEarned;

  bool get shown => status == AdShowStatus.shown;

  @override
  String toString() => 'AdShowResult(${status.name}${gate != null ? ', $gate' : ''}, rewardEarned=$rewardEarned)';
}
