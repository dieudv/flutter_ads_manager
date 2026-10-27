import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_format.dart';
import '../config/ad_placement.dart';
import '../core/ad_status.dart';
import '../core/ads_manager.dart';

/// Anchored adaptive banner. Hides itself when premium / disabled / conditions are not met
/// and shows again when the conditions are satisfied.
class AdsBanner extends StatefulWidget {
  const AdsBanner({super.key, required this.placement, this.reserveSpace = false});

  final AdPlacement placement;

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

  /// The ONLY place that calls the adaptive-size API. If the SDK changes it, fix it here.
  Future<AdSize> _adaptiveSize(int width) async {
    final AdSize? size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    return size ?? AdSize.banner;
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
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (width != _width) {
      _width = width;
      _reset();
      _load();
    }
  }

  @override
  void didUpdateWidget(AdsBanner old) {
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
    final size = await _adaptiveSize(_width);
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
      return SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      );
    }
    final size = _size;
    if (widget.reserveSpace && size != null) return SizedBox(height: size.height.toDouble());
    return const SizedBox.shrink();
  }
}
