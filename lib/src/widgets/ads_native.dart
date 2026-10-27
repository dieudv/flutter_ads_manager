import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_format.dart';
import '../config/ad_placement.dart';
import '../core/ad_status.dart';
import '../core/ads_manager.dart';

/// Native advanced ad.
///
/// - By default uses Google's template (no native code needed): pass
///   [templateStyle] (small/medium + colors).
/// - For a fully custom look: register a `NativeAdFactory` on Android/iOS
///   and pass [factoryId].
class AdsNative extends StatefulWidget {
  const AdsNative({
    super.key,
    required this.placement,
    this.templateStyle,
    this.factoryId,
    this.constraints,
    this.reserveSpace = false,
  }) : assert(templateStyle == null || factoryId == null, 'Use either templateStyle or factoryId, not both');

  final AdPlacement placement;
  final NativeTemplateStyle? templateStyle;
  final String? factoryId;

  /// Defaults to the template size (small/medium). You should pass it when using [factoryId].
  final BoxConstraints? constraints;
  final bool reserveSpace;

  @override
  State<AdsNative> createState() => _AdsNativeState();
}

class _AdsNativeState extends State<AdsNative> {
  final AdsManager _ads = AdsManager.I;

  NativeAd? _ad;
  bool _loaded = false;
  int _attempt = 0;
  Timer? _retryTimer;

  NativeTemplateStyle get _style =>
      widget.templateStyle ?? NativeTemplateStyle(templateType: TemplateType.medium);

  BoxConstraints get _constraints {
    if (widget.constraints != null) return widget.constraints!;
    if (widget.factoryId != null) return const BoxConstraints(minWidth: 320, minHeight: 90, maxHeight: 400);
    return _style.templateType == TemplateType.small
        ? const BoxConstraints(minWidth: 320, minHeight: 90, maxWidth: 400, maxHeight: 200)
        : const BoxConstraints(minWidth: 320, minHeight: 320, maxWidth: 400, maxHeight: 400);
  }

  @override
  void initState() {
    super.initState();
    assert(widget.placement.format == AdFormat.nativeAdvanced, '${widget.placement.name} is not a native placement');
    _ads.addListener(_onGateChanged);
    _load();
  }

  @override
  void didUpdateWidget(AdsNative old) {
    super.didUpdateWidget(old);
    if (old.placement != widget.placement) {
      _reset();
      _load();
    }
  }

  void _onGateChanged() {
    if (!mounted) return;
    if (_ads.canShowPassive(widget.placement)) {
      if (_ad == null) _load();
    } else if (_ad != null) {
      setState(_reset);
    } else {
      setState(() {});
    }
  }

  void _reset() {
    _retryTimer?.cancel();
    _ad?.dispose();
    _ad = null;
    _loaded = false;
    _attempt = 0;
    _setStatus(AdStatus.idle);
  }

  void _setStatus(AdStatus status) {
    final notifier = _ads.statusNotifier(widget.placement);
    scheduleMicrotask(() => notifier.value = status);
  }

  void _load() {
    final placement = widget.placement;
    if (_ad != null || !_ads.canShowPassive(placement)) return;
    final unitId = _ads.unitIdOf(placement);
    if (unitId == null) return;

    final events = _ads.events;
    late final NativeAd ad;
    ad = NativeAd(
      adUnitId: unitId,
      request: _ads.adRequest,
      factoryId: widget.factoryId,
      nativeTemplateStyle: widget.factoryId == null ? _style : null,
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (!mounted || !identical(_ad, ad)) {
            ad.dispose();
            return;
          }
          setState(() => _loaded = true);
          _attempt = 0;
          _setStatus(AdStatus.loaded);
          events.onAdLoaded(placement);
        },
        onAdFailedToLoad: (failed, error) {
          failed.dispose();
          if (identical(_ad, ad)) _ad = null;
          events.onAdLoadFailed(placement, error);
          if (!mounted) return;
          _setStatus(AdStatus.failed);
          _scheduleRetry();
        },
        onAdImpression: (_) => events.onAdImpression(placement),
        onAdClicked: (_) => events.onAdClicked(placement),
        onPaidEvent: (_, value, precision, currency) => events.onAdPaid(placement, value, precision, currency),
      ),
    );
    _ad = ad;
    _setStatus(AdStatus.loading);
    ad.load();
  }

  void _scheduleRetry() {
    if (_attempt >= _ads.rules.maxLoadRetries) return;
    final seconds = math.min(60, 2 << _attempt);
    _attempt++;
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: seconds), _load);
  }

  @override
  void dispose() {
    _ads.removeListener(_onGateChanged);
    _retryTimer?.cancel();
    _ad?.dispose();
    _ad = null;
    _setStatus(AdStatus.idle);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ads.canShowPassive(widget.placement)) return const SizedBox.shrink();
    final ad = _ad;
    if (ad != null && _loaded) {
      return ConstrainedBox(constraints: _constraints, child: AdWidget(ad: ad));
    }
    if (widget.reserveSpace) return SizedBox(height: _constraints.minHeight);
    return const SizedBox.shrink();
  }
}
