import 'package:flutter/widgets.dart';

import '../config/ad_placement.dart';
import '../core/ads_manager.dart';

/// Builds UI depending on whether the ad of a placement is ready.
///
/// Example: only show the "Watch a video to remove ads" button once the rewarded ad has loaded.
class AdReadyBuilder extends StatelessWidget {
  const AdReadyBuilder({super.key, required this.placement, required this.builder});

  final AdPlacement placement;
  final Widget Function(BuildContext context, bool isReady) builder;

  @override
  Widget build(BuildContext context) {
    final ads = AdsManager.I;
    return ListenableBuilder(
      listenable: Listenable.merge([ads.statusOf(placement), ads]),
      builder: (context, _) => builder(context, ads.isReady(placement)),
    );
  }
}

/// Builds UI depending on whether ads are enabled in general
/// (e.g. hide the banner container, hide the "Remove ads" button once premium).
class AdsEnabledBuilder extends StatelessWidget {
  const AdsEnabledBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, bool adsEnabled) builder;

  @override
  Widget build(BuildContext context) {
    final ads = AdsManager.I;
    return ValueListenableBuilder<bool>(
      valueListenable: ads.adsEnabled,
      builder: (context, enabled, _) => builder(context, enabled),
    );
  }
}
