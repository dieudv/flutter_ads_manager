import 'package:flutter/widgets.dart';

import '../config/ad_placement.dart';
import '../core/ads_manager.dart';

/// Dựng UI theo việc ad của một placement đã sẵn sàng hay chưa.
///
/// Ví dụ: chỉ hiện nút "Xem video để bỏ quảng cáo" khi rewarded đã load.
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

/// Dựng UI theo việc quảng cáo nói chung có đang được bật hay không
/// (vd ẩn banner container, ẩn nút "Remove ads" khi đã premium).
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
