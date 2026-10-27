import 'ad_format.dart';

/// Toàn bộ "luật" hiển thị quảng cáo. Thuần Dart, không phụ thuộc SDK.
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

  /// Chỉ hiện ads khi số ngày hoạt động >= giá trị này.
  /// Ngày mở app đầu tiên là ngày 1, nên `3` nghĩa là bắt đầu từ ngày thứ 3.
  final int minActiveDays;

  /// Thời gian dùng tối thiểu trong một phiên trước khi được hiện ads
  /// (không áp dụng cho App Open vì nó vốn hiện lúc mở/quay lại app).
  final Duration minSessionTime;

  /// Khoảng cách tối thiểu giữa hai quảng cáo toàn màn hình bất kỳ
  /// (tính từ lúc ad trước ĐÓNG).
  final Duration fullscreenCooldown;

  /// Cooldown riêng cho từng format, ghi đè [fullscreenCooldown].
  /// Mốc thời gian vẫn dùng chung, chỉ khác khoảng cách yêu cầu.
  final Map<AdFormat, Duration> cooldownOverrides;

  /// Rewarded (user chủ động xem) bỏ qua: số ngày, thời gian phiên, cooldown
  /// và cả trạng thái disable. Chỉ bị chặn khi premium.
  final bool rewardedBypassRules;

  /// `true`: disableAdsFor ẩn cả banner/native. `false`: chỉ chặn full-screen.
  final bool disableBlocksPassiveAds;

  /// App Open ad cũ hơn mức này bị coi là hết hạn và phải load lại.
  final Duration appOpenMaxAge;

  /// Nền quá lâu thì tính là phiên mới (reset [minSessionTime]).
  final Duration sessionResetAfterBackground;

  /// Số lần tự retry khi load fail (exponential backoff 2s, 4s, 8s... tối đa 60s).
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
