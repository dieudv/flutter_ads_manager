import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_placement.dart';
import 'ad_rules.dart';

/// Cấu hình truyền vào `AdsManager.initialize`.
/// Có thể `copyWith` rồi gọi `AdsManager.I.updateConfig` (vd từ Remote Config).
class AdsConfig {
  const AdsConfig({
    this.rules = const AdRules(),
    this.useTestIds,
    this.appOpenPlacement,
    this.autoShowAppOpenOnResume = true,
    this.preload = const [],
    this.disabledPlacements = const {},
    this.testDeviceIds = const [],
    this.requestBuilder,
  });

  final AdRules rules;

  /// `null` = tự động (test id khi debug, id thật khi release).
  final bool? useTestIds;

  /// Placement App Open dùng cho cold start và resume.
  final AdPlacement? appOpenPlacement;

  /// Tự hiện App Open khi app quay lại từ nền.
  final bool autoShowAppOpenOnResume;

  /// Các placement full-screen preload ngay sau khi khởi tạo.
  final List<AdPlacement> preload;

  /// Tên các placement bị tắt (vd từ Remote Config).
  final Set<String> disabledPlacements;

  final List<String> testDeviceIds;

  /// Tuỳ biến AdRequest (keywords, non-personalized...).
  final AdRequest Function()? requestBuilder;

  AdsConfig copyWith({
    AdRules? rules,
    bool? useTestIds,
    AdPlacement? appOpenPlacement,
    bool? autoShowAppOpenOnResume,
    List<AdPlacement>? preload,
    Set<String>? disabledPlacements,
    List<String>? testDeviceIds,
    AdRequest Function()? requestBuilder,
  }) =>
      AdsConfig(
        rules: rules ?? this.rules,
        useTestIds: useTestIds ?? this.useTestIds,
        appOpenPlacement: appOpenPlacement ?? this.appOpenPlacement,
        autoShowAppOpenOnResume: autoShowAppOpenOnResume ?? this.autoShowAppOpenOnResume,
        preload: preload ?? this.preload,
        disabledPlacements: disabledPlacements ?? this.disabledPlacements,
        testDeviceIds: testDeviceIds ?? this.testDeviceIds,
        requestBuilder: requestBuilder ?? this.requestBuilder,
      );
}
