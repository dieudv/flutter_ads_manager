import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_format.dart';
import '../config/ad_placement.dart';
import '../config/ads_banner_size.dart';
import '../core/ad_status.dart';
import '../core/ads_manager.dart';

/// Banner (anchored adaptive by default, see [AdsBannerSize]). Hides itself when premium / disabled / conditions are not met
/// and shows again when the conditions are satisfied.
class AdsBanner extends StatefulWidget {
  const AdsBanner({
    super.key,
    required this.placement,
    this.size = AdsBannerSize.anchoredAdaptive,
    this.adaptiveWidth,
    this.inlineMaxHeight,
    this.reserveSpace = false,
  });

  final AdPlacement placement;

  final AdsBannerSize size;

  /// Width (logical pixels) used to compute adaptive sizes. Defaults to the
  /// screen width; pass the real available width when the banner is narrower
  /// than the screen (e.g. inside horizontal padding).
  final double? adaptiveWidth;

  /// Maximum height for [AdsBannerSize.inlineAdaptive]. `null` lets the SDK
  /// pick based on the current orientation.
  final double? inlineMaxHeight;

  /// `true`: reserves the height while waiting for the ad so the layout does not jump.
  final bool reserveSpace;

  @override
  State<AdsBanner> createState() => _AdsBannerState();
}

class _AdsBannerState extends State<AdsBanner> {
  final AdsManager _ads = AdsManager.I;

  BannerAd? _ad;
  AdSize? _size;
  bool _loaded = false;
  bool _busy = false;
  int _generation = 0;
  int _width = 0;
  int _attempt = 0;
  Timer? _retryTimer;

  int _computeWidth() => (widget.adaptiveWidth ?? MediaQuery.sizeOf(context).width).truncate();

  /// The ONLY place that maps [AdsBannerSize] to SDK sizes. If the SDK changes
  /// its adaptive-size API, fix it here.
  Future<AdSize> _resolveSize(int width) async {
    switch (widget.size) {
      case AdsBannerSize.banner:
        return AdSize.banner;
      case AdsBannerSize.largeBanner:
        return AdSize.largeBanner;
      case AdsBannerSize.mediumRectangle:
        return AdSize.mediumRectangle;
      case AdsBannerSize.fullBanner:
        return AdSize.fullBanner;
      case AdsBannerSize.leaderboard:
        return AdSize.leaderboard;
      case AdsBannerSize.anchoredAdaptive:
        final AdSize? size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
        return size ?? AdSize.banner;
      case AdsBannerSize.inlineAdaptive:
        final maxHeight = widget.inlineMaxHeight;
        return Future<AdSize>.value(
          maxHeight == null
              ? AdSize.getCurrentOrientationInlineAdaptiveBannerAdSize(width)
              : AdSize.getInlineAdaptiveBannerAdSize(width, maxHeight.truncate()),
        );
    }
  }

  @override
  void initState() {
    super.initState();
    assert(widget.placement.format == AdFormat.banner, '${widget.placement.name} is not a banner placement');
    _ads.addListener(_onGateChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final width = _computeWidth();
    if (width != _width) {
      _width = width;
      if (widget.size.isAdaptive) _reset(); // fixed sizes do not depend on the width
      _load();
    }
  }

  @override
  void didUpdateWidget(AdsBanner old) {
    super.didUpdateWidget(old);
    if (old.placement != widget.placement ||
        old.size != widget.size ||
        old.adaptiveWidth != widget.adaptiveWidth ||
        old.inlineMaxHeight != widget.inlineMaxHeight) {
      _width = _computeWidth();
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
    _generation++;
    _retryTimer?.cancel();
    _ad?.dispose();
    _ad = null;
    _loaded = false;
    _attempt = 0;
    _setStatus(AdStatus.idle);
  }

  void _setStatus(AdStatus status) {
    final notifier = _ads.statusNotifier(widget.placement);
    // Avoid notifying while the framework is building/unmounting.
    scheduleMicrotask(() => notifier.value = status);
  }

  Future<void> _load() async {
    final placement = widget.placement;
    if (_ad != null || _busy || _width == 0 || !_ads.canShowPassive(placement)) return;
    final unitId = _ads.unitIdOf(placement);
    if (unitId == null) return;

    _busy = true;
    final generation = _generation;
    final size = await _resolveSize(_width);
    _busy = false;
    if (!mounted) return;
    if (generation != _generation) return _load(); // was reset while waiting
    if (!_ads.canShowPassive(placement)) return;

    final events = _ads.events;
    late final BannerAd ad;
    ad = BannerAd(
      adUnitId: unitId,
      size: size,
      request: _ads.adRequest,
      listener: BannerAdListener(
        onAdLoaded: (_) async {
          if (!mounted || !identical(_ad, ad)) {
            ad.dispose();
            return;
          }
          if (widget.size == AdsBannerSize.inlineAdaptive) {
            // The real height of an inline adaptive banner is only known after loading.
            final real = await ad.getPlatformAdSize();
            if (!mounted || !identical(_ad, ad)) return;
            if (real != null) _size = real;
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
    _size = size;
    _setStatus(AdStatus.loading);
    await ad.load();
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
      final shown = _size ?? ad.size;
      return SizedBox(
        width: shown.width.toDouble(),
        height: shown.height.toDouble(),
        child: AdWidget(ad: ad),
      );
    }
    final size = _size;
    if (widget.reserveSpace && size != null) return SizedBox(height: size.height.toDouble());
    return const SizedBox.shrink();
  }
}
