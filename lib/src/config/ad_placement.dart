import 'package:flutter/foundation.dart';

import 'ad_format.dart';

class _TestId {
  const _TestId(this.android, this.ios);
  final String android;
  final String ios;
}

/// Google's official test ad units. Used automatically in debug mode.
const Map<AdFormat, _TestId> _testIds = {
  AdFormat.banner: _TestId('ca-app-pub-3940256099942544/6300978111', 'ca-app-pub-3940256099942544/2934735716'),
  AdFormat.interstitial: _TestId('ca-app-pub-3940256099942544/1033173712', 'ca-app-pub-3940256099942544/4411468910'),
  AdFormat.rewarded: _TestId('ca-app-pub-3940256099942544/5224354917', 'ca-app-pub-3940256099942544/1712485313'),
  AdFormat.rewardedInterstitial: _TestId('ca-app-pub-3940256099942544/5354046379', 'ca-app-pub-3940256099942544/6978759866'),
  AdFormat.nativeAdvanced: _TestId('ca-app-pub-3940256099942544/2247696110', 'ca-app-pub-3940256099942544/3986624511'),
  AdFormat.appOpen: _TestId('ca-app-pub-3940256099942544/9257395921', 'ca-app-pub-3940256099942544/5575463023'),
};

/// A place where an ad is shown (e.g. the banner on the home screen).
///
/// Each placement carries both the format and the Android/iOS ids, so a banner id
/// can never be used for an interstitial by mistake. [name] must be unique.
@immutable
class AdPlacement {
  const AdPlacement._(this.name, this.format, this.androidUnitId, this.iosUnitId, this.enabled);

  const AdPlacement.banner(String name, {required String android, required String ios, bool enabled = true})
      : this._(name, AdFormat.banner, android, ios, enabled);
  const AdPlacement.interstitial(String name, {required String android, required String ios, bool enabled = true})
      : this._(name, AdFormat.interstitial, android, ios, enabled);
  const AdPlacement.rewardedInterstitial(String name, {required String android, required String ios, bool enabled = true})
      : this._(name, AdFormat.rewardedInterstitial, android, ios, enabled);
  const AdPlacement.rewarded(String name, {required String android, required String ios, bool enabled = true})
      : this._(name, AdFormat.rewarded, android, ios, enabled);
  const AdPlacement.native(String name, {required String android, required String ios, bool enabled = true})
      : this._(name, AdFormat.nativeAdvanced, android, ios, enabled);
  const AdPlacement.appOpen(String name, {required String android, required String ios, bool enabled = true})
      : this._(name, AdFormat.appOpen, android, ios, enabled);

  final String name;
  final AdFormat format;
  final String androidUnitId;
  final String iosUnitId;

  /// Hard-disables the placement in code. It can be disabled at runtime via
  /// `AdsManager.I.setPlacementEnabled`.
  final bool enabled;

  /// Unit id for the current platform, `null` if the platform is unsupported (web/desktop).
  String? resolveUnitId({required bool useTestIds}) {
    if (kIsWeb) return null;
    final test = _testIds[format]!;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return useTestIds ? test.android : androidUnitId;
      case TargetPlatform.iOS:
        return useTestIds ? test.ios : iosUnitId;
      default:
        return null;
    }
  }

  @override
  bool operator ==(Object other) => other is AdPlacement && other.name == name && other.format == format;

  @override
  int get hashCode => Object.hash(name, format);

  @override
  String toString() => 'AdPlacement($name, ${format.name})';
}
