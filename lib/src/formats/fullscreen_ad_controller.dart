import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_placement.dart';
import '../core/ad_status.dart';
import '../core/ads_host.dart';
import '../policy/ad_gate.dart';

/// Callback doanh thu. Tự khai báo để không phụ thuộc tên typedef của SDK
/// (hiện là `OnPaidEventCallback`); Dart so khớp kiểu hàm theo cấu trúc.
typedef AdPaidCallback = void Function(
  Ad ad,
  double valueMicros,
  PrecisionType precision,
  String currencyCode,
);

/// Vòng đời chung của quảng cáo toàn màn hình: preload, retry backoff,
/// kiểm tra hết hạn, show một lần rồi tự load lại.
/// Subclass chỉ cần cài [requestAd] và [present] (phần gọi SDK).
abstract class FullscreenAdController<T extends AdWithoutView> {
  FullscreenAdController(this.host, this.placement) : status = host.statusNotifier(placement);

  final AdsHost host;
  final AdPlacement placement;
  final ValueNotifier<AdStatus> status;

  T? _ad;
  DateTime? _loadedAt;
  int _attempt = 0;
  Timer? _retryTimer;

  /// Thời gian sống tối đa của ad đã load (App Open hết hạn sau ~4 giờ).
  Duration? get maxAge => null;

  bool get _expired {
    final max = maxAge;
    final at = _loadedAt;
    return max != null && at != null && host.now().difference(at) > max;
  }

  bool get isReady => _ad != null && !_expired;

  // ------------------------------------------------------------ cho subclass

  @protected
  void requestAd(String unitId, AdRequest request, void Function(T ad) onLoaded, void Function(LoadAdError error) onFailed);

  @protected
  void present(
    T ad,
    FullScreenContentCallback<T> callback,
    AdPaidCallback onPaid,
    void Function(RewardItem reward) onReward,
  );

  // ------------------------------------------------------------ load

  void load() {
    final s = status.value;
    if (s == AdStatus.loading || s == AdStatus.showing) return;
    if (isReady) {
      status.value = AdStatus.loaded;
      return;
    }
    if (!host.gateLoad(placement).allowed) return;
    final id = host.unitIdOf(placement);
    if (id == null) return;

    _retryTimer?.cancel();
    _disposeAd();
    status.value = AdStatus.loading;

    requestAd(id, host.adRequest, (ad) {
      if (!host.gateLoad(placement).allowed) {
        // Trạng thái đã đổi trong lúc đang load (premium, disable...).
        ad.dispose();
        status.value = AdStatus.idle;
        return;
      }
      _ad = ad;
      _loadedAt = host.now();
      _attempt = 0;
      status.value = AdStatus.loaded;
      host.events.onAdLoaded(placement);
    }, (error) {
      status.value = AdStatus.failed;
      host.events.onAdLoadFailed(placement, error);
      _scheduleRetry();
    });
  }

  void _scheduleRetry() {
    if (_attempt >= host.rules.maxLoadRetries) return;
    final seconds = math.min(60, 2 << _attempt);
    _attempt++;
    _retryTimer = Timer(Duration(seconds: seconds), load);
  }

  /// Bỏ ad đang giữ (khi premium / bị disable). Không đụng vào ad đang show.
  void discard() {
    if (status.value == AdStatus.showing) return;
    _retryTimer?.cancel();
    _disposeAd();
    _attempt = 0;
    status.value = AdStatus.idle;
  }

  void _disposeAd() {
    _ad?.dispose();
    _ad = null;
    _loadedAt = null;
  }

  /// Chờ ad sẵn sàng tối đa [timeout] (dùng cho App Open lúc khởi động).
  Future<bool> waitUntilReady(Duration timeout) {
    if (isReady) return Future.value(true);
    final done = Completer<bool>();
    Timer? timer;
    late VoidCallback listener;
    void finish(bool value) {
      if (done.isCompleted) return;
      status.removeListener(listener);
      timer?.cancel();
      done.complete(value);
    }

    listener = () {
      if (status.value == AdStatus.loaded) finish(true);
      if (status.value == AdStatus.failed) finish(false);
    };
    status.addListener(listener);
    timer = Timer(timeout, () => finish(isReady));
    load();
    return done.future;
  }

  // ------------------------------------------------------------ show

  /// Hiển thị nếu luật cho phép. Future hoàn tất sau khi ad đóng.
  Future<AdShowResult> show() async {
    if (host.isFullscreenShowing || status.value == AdStatus.showing) {
      const gate = AdGateResult.blocked(AdBlockReason.fullscreenShowing);
      host.events.onAdBlocked(placement, gate);
      return const AdShowResult.blocked(gate);
    }
    final gate = host.gateShow(placement);
    if (!gate.allowed) {
      host.events.onAdBlocked(placement, gate);
      return AdShowResult.blocked(gate);
    }
    final ad = _ad;
    if (ad == null || _expired) {
      _disposeAd();
      load();
      return const AdShowResult.notReady();
    }

    _ad = null; // ad chỉ dùng được một lần
    final completer = Completer<AdShowResult>();
    var earned = false;
    status.value = AdStatus.showing;
    host.onFullscreenStarted(placement);

    void finish({required bool shown, required AdShowResult result}) {
      host.onFullscreenEnded(placement, shown: shown);
      status.value = AdStatus.idle;
      if (!completer.isCompleted) completer.complete(result);
      load(); // chuẩn bị ad cho lần sau
    }

    final callback = FullScreenContentCallback<T>(
      onAdShowedFullScreenContent: (_) => host.events.onAdShown(placement),
      onAdImpression: (_) => host.events.onAdImpression(placement),
      onAdClicked: (_) => host.events.onAdClicked(placement),
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        host.events.onAdDismissed(placement);
        finish(shown: true, result: AdShowResult.shown(rewardEarned: earned));
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        host.events.onAdShowFailed(placement, error);
        finish(shown: false, result: const AdShowResult.failed());
      },
    );

    try {
      present(
        ad,
        callback,
        (_, valueMicros, precision, currency) => host.events.onAdPaid(placement, valueMicros, precision, currency),
        (reward) {
          earned = true;
          host.events.onAdRewardEarned(placement, reward);
        },
      );
    } catch (e) {
      debugPrint('[Ads] show exception on $placement: $e');
      ad.dispose();
      finish(shown: false, result: const AdShowResult.failed());
    }
    return completer.future;
  }

  void dispose() {
    _retryTimer?.cancel();
    _disposeAd();
  }
}
