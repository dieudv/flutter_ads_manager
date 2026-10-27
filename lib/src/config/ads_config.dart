import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_placement.dart';
import 'ad_rules.dart';

/// Configuration passed to `AdsManager.initialize`.
/// Can be `copyWith`-ed and passed to `AdsManager.I.updateConfig` (e.g. from Remote Config).
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

  /// `null` = automatic (test ids in debug, real ids in release).
  final bool? useTestIds;

  /// App Open placement used for cold start and resume.
  final AdPlacement? appOpenPlacement;

  /// Automatically show App Open when the app returns from the background.
  final bool autoShowAppOpenOnResume;

  /// Full-screen placements to preload right after initialization.
  final List<AdPlacement> preload;

  /// Names of disabled placements (e.g. from Remote Config).
  final Set<String> disabledPlacements;

  final List<String> testDeviceIds;

  /// Customize the AdRequest (keywords, non-personalized ads...).
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
