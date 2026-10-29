/// Reusable AdMob manager for Flutter.
library;

export 'src/config/ad_format.dart';
export 'src/config/ad_placement.dart';
export 'src/config/ad_rules.dart';
export 'src/config/ads_banner_size.dart';
export 'src/config/ads_config.dart';
export 'src/consent/consent_helper.dart';
export 'src/core/ad_events.dart';
export 'src/core/ad_status.dart';
export 'src/core/ads_manager.dart';
export 'src/policy/ad_gate.dart';
export 'src/policy/ad_policy.dart';
export 'src/storage/ad_storage.dart';
export 'src/storage/shared_prefs_ad_storage.dart';
export 'src/widgets/ad_builders.dart';
export 'src/widgets/ads_banner.dart';
export 'src/widgets/ads_native.dart';

// SDK types that appear in the public API (AdsEventListener...).
export 'package:google_mobile_ads/google_mobile_ads.dart'
    show AdError, LoadAdError, PrecisionType, RewardItem, NativeTemplateStyle, NativeTemplateTextStyle, TemplateType, ConsentDebugSettings, DebugGeography;
