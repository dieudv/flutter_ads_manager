import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_placement.dart';
import '../config/ad_rules.dart';
import '../policy/ad_gate.dart';
import 'ad_events.dart';
import 'ad_status.dart';

/// The part of AdsManager that controllers/widgets need.
/// Split into an interface so controllers do not depend directly on the singleton.
abstract class AdsHost {
  DateTime now();
  AdRules get rules;
  AdRequest get adRequest;
  AdsEventListener get events;
  bool get isFullscreenShowing;

  String? unitIdOf(AdPlacement placement);
  AdGateResult gateLoad(AdPlacement placement);
  AdGateResult gateShow(AdPlacement placement);
  ValueNotifier<AdStatus> statusNotifier(AdPlacement placement);

  void onFullscreenStarted(AdPlacement placement);
  void onFullscreenEnded(AdPlacement placement, {required bool shown});
}
