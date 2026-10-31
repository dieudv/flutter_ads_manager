import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_format.dart';
import '../config/ad_placement.dart';
import '../config/ads_config.dart';
import '../consent/consent_helper.dart';
import '../formats/fullscreen_ad_controller.dart';
import '../formats/fullscreen_controllers.dart';
import '../policy/ad_gate.dart';
import '../policy/ad_policy.dart';
import '../storage/ad_storage.dart';
import '../storage/shared_prefs_ad_storage.dart';
import '../config/ad_rules.dart';
import 'ad_events.dart';
import 'ad_status.dart';
import 'ads_host.dart';

/// The single entry point of the package: `AdsManager.I`.
///
/// It is a [ChangeNotifier]: it notifies whenever the display conditions change
/// (premium, disable, enough days/session time, consent, placement toggled).
class AdsManager extends ChangeNotifier with WidgetsBindingObserver implements AdsHost {
  AdsManager._();

  static final AdsManager I = AdsManager._();

  // ------------------------------------------------------------------ state

  AdsConfig _config = const AdsConfig();
  AdPolicy _policy = AdPolicy(storage: MemoryAdStorage());
  DateTime Function() _clock = DateTime.now;

  bool _initialized = false;
  bool _sdkStarted = false;
  bool _canRequestAds = false;
  bool _useTestIds = true;
  Set<String> _disabledPlacements = {};

  int _lastSignature = -1;
  int _appOpenSuppressed = 0;
  DateTime? _pausedAt;
  DateTime? _lastFullscreenEndAt;
  Timer? _ticker;
  Timer? _unlockTimer;

  final Map<String, FullscreenAdController<AdWithoutView>> _controllers = {};
  final Map<String, ValueNotifier<AdStatus>> _statuses = {};
  final _EventDispatcher _events = _EventDispatcher();

  final ValueNotifier<bool> _adsEnabled = ValueNotifier(false);
  final ValueNotifier<bool> _isPremium = ValueNotifier(false);
  final ValueNotifier<bool> _isAdFree = ValueNotifier(false);
  final ValueNotifier<Duration?> _disabledRemaining = ValueNotifier(null);
  final ValueNotifier<bool> _fullscreenShowing = ValueNotifier(false);

  static bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  // ------------------------------------------------------------------ public state

  /// Whether banner/native ads may be shown yet (enough days, enough session time, not
  /// premium, not disabled, consent obtained). Use it to show/hide shared UI.
  ValueListenable<bool> get adsEnabled => _adsEnabled;

  ValueListenable<bool> get isPremium => _isPremium;

  /// `true` when the user is premium or inside the timed "disable ads" period.
  ValueListenable<bool> get isAdFree => _isAdFree;

  /// Time remaining on the timed "disable ads" period, `null` if ads are not disabled.
  /// Updated every second while counting down, so it can drive a countdown UI.
  ValueListenable<Duration?> get disabledRemaining => _disabledRemaining;

  ValueListenable<bool> get isFullscreenAdShowing => _fullscreenShowing;

  int get activeDays => _policy.activeDays;

  bool get isInitialized => _initialized;

  /// Load status of a placement.
  ValueListenable<AdStatus> statusOf(AdPlacement placement) => statusNotifier(placement);

  /// The ad has loaded AND the rules allow loading (premium/disable...). Cooldown is not
  /// counted (it is temporary, so it should not be used to hide a button).
  bool isReady(AdPlacement placement) =>
      statusNotifier(placement).value == AdStatus.loaded && _gate(placement, show: false).allowed;

  /// Whether a banner/native ad may be shown right now.
  bool canShowPassive(AdPlacement placement) => _gate(placement, show: true).allowed;

  /// Explains why a placement is blocked (or `allowed`). Useful for debugging.
  AdGateResult explain(AdPlacement placement) => _gate(placement, show: true);

  String debugSummary() => _policy.debugSummary();

  // ------------------------------------------------------------------ init

  /// Initializes the manager. Call once in `main()` after `WidgetsFlutterBinding.ensureInitialized()`.
  ///
  /// - [isPremium]: pass the already-known premium state to avoid flashing ads.
  /// - [gatherConsent]: runs UMP before initializing the SDK (required for EEA/UK users).
  /// - [storage] and [clock]: replace them in tests.
  Future<void> initialize(
    AdsConfig config, {
    bool isPremium = false,
    bool gatherConsent = false,
    ConsentDebugSettings? consentDebugSettings,
    AdStorage? storage,
    DateTime Function()? clock,
  }) async {
    if (_initialized) return;
    WidgetsFlutterBinding.ensureInitialized();

    _config = config;
    _clock = clock ?? DateTime.now;
    _useTestIds = config.useTestIds ?? kDebugMode;
    _disabledPlacements = {...config.disabledPlacements};
    _policy = AdPolicy(storage: storage ?? SharedPrefsAdStorage(), rules: config.rules, now: _clock);
    await _policy.init();
    _policy.setPremium(isPremium);

    if (_supported) {
      if (gatherConsent) {
        await ConsentHelper.gather(debugSettings: consentDebugSettings);
        _canRequestAds = await ConsentHelper.canRequestAds();
      } else {
        _canRequestAds = true;
      }
      if (_canRequestAds) await _startSdk();
    }

    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    _recompute(force: true);
    _scheduleTimers();
    for (final p in config.preload) {
      preload(p);
    }
  }

  Future<void> _startSdk() async {
    if (_sdkStarted) return;
    _sdkStarted = true;
    if (_config.testDeviceIds.isNotEmpty) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: _config.testDeviceIds),
      );
    }
    await MobileAds.instance.initialize();
  }

  /// Call after the user changes their consent choice (e.g. via the Privacy options form).
  Future<void> refreshConsent() async {
    if (!_initialized || !_supported) return;
    _canRequestAds = await ConsentHelper.canRequestAds();
    if (_canRequestAds) await _startSdk();
    _recompute(force: true);
  }

  /// Applies a new configuration at runtime (e.g. from Firebase Remote Config).
  void updateConfig(AdsConfig config) {
    _config = config;
    _policy.rules = config.rules;
    _disabledPlacements = {...config.disabledPlacements};
    _recompute(force: true);
    _scheduleTimers();
  }

  // ------------------------------------------------------------------ controls

  void setPremium(bool value) {
    _policy.setPremium(value);
    _recompute();
  }

  /// Disables ads for [duration]. See [AdPolicy.disableFor].
  /// Example: watch a rewarded ad to remove ads for 24h, accumulating.
  Future<void> disableAdsFor(Duration duration, {bool accumulate = false}) async {
    await _policy.disableFor(duration, accumulate: accumulate);
    _recompute();
    _scheduleTimers();
  }

  Future<void> enableAds() async {
    await _policy.clearDisabled();
    _recompute();
    _scheduleTimers();
  }

  /// Enables/disables a placement at runtime (A/B test, remote kill switch).
  void setPlacementEnabled(String placementName, bool enabled) {
    enabled ? _disabledPlacements.remove(placementName) : _disabledPlacements.add(placementName);
    _recompute(force: true);
  }

  void addEventListener(AdsEventListener listener) => _events.listeners.add(listener);
  void removeEventListener(AdsEventListener listener) => _events.listeners.remove(listener);

  // ------------------------------------------------------------------ show / preload

  void preload(AdPlacement placement) => _controllerFor(placement).load();

  Future<AdShowResult> showInterstitial(AdPlacement p) => _show(p, AdFormat.interstitial);
  Future<AdShowResult> showRewardedInterstitial(AdPlacement p) => _show(p, AdFormat.rewardedInterstitial);
  Future<AdShowResult> showRewarded(AdPlacement p) => _show(p, AdFormat.rewarded);

  /// Shows App Open manually. Uses the placement from the config by default.
  Future<AdShowResult> showAppOpen([AdPlacement? placement]) {
    final p = placement ?? _config.appOpenPlacement;
    if (p == null) return Future.value(const AdShowResult.blocked(AdGateResult.blocked(AdBlockReason.placementDisabled)));
    return _show(p, AdFormat.appOpen);
  }

  /// Use on the splash screen: waits up to [timeout] for App Open to load, then shows it.
  Future<AdShowResult> showAppOpenOnLaunch({Duration timeout = const Duration(seconds: 4)}) async {
    final p = _config.appOpenPlacement;
    if (p == null) return const AdShowResult.blocked(AdGateResult.blocked(AdBlockReason.placementDisabled));
    final gate = _gate(p, show: true);
    if (!gate.allowed) {
      _events.onAdBlocked(p, gate);
      return AdShowResult.blocked(gate);
    }
    await _controllerFor(p).waitUntilReady(timeout);
    return _controllerFor(p).show();
  }

  Future<AdShowResult> _show(AdPlacement p, AdFormat expected) {
    assert(p.format == expected, '${p.name} is ${p.format.name}, not ${expected.name}');
    return _controllerFor(p).show();
  }

  /// Wraps operations that send the app to the background and back (permission requests, image picker,
  /// share sheet...) so App Open does not show automatically when the app resumes afterwards.
  Future<T> runWithoutAppOpen<T>(Future<T> Function() action) async {
    _appOpenSuppressed++;
    try {
      return await action();
    } finally {
      // Wait 1s because the resumed event may arrive after the action finishes.
      Timer(const Duration(seconds: 1), () => _appOpenSuppressed--);
    }
  }

  // ------------------------------------------------------------------ AdsHost

  @override
  DateTime now() => _clock();

  @override
  AdRules get rules => _policy.rules;

  @override
  AdRequest get adRequest => _config.requestBuilder?.call() ?? const AdRequest();

  @override
  AdsEventListener get events => _events;

  @override
  bool get isFullscreenShowing => _fullscreenShowing.value;

  @override
  String? unitIdOf(AdPlacement placement) => placement.resolveUnitId(useTestIds: _useTestIds);

  @override
  AdGateResult gateLoad(AdPlacement placement) => _gate(placement, show: false);

  @override
  AdGateResult gateShow(AdPlacement placement) => _gate(placement, show: true);

  @override
  ValueNotifier<AdStatus> statusNotifier(AdPlacement placement) =>
      _statuses.putIfAbsent(placement.name, () => ValueNotifier(AdStatus.idle));

  @override
  void onFullscreenStarted(AdPlacement placement) => _fullscreenShowing.value = true;

  @override
  void onFullscreenEnded(AdPlacement placement, {required bool shown}) {
    _fullscreenShowing.value = false;
    if (shown) {
      _policy.markFullscreenDismissed();
      _lastFullscreenEndAt = _clock();
    }
    _recompute();
  }

  // ------------------------------------------------------------------ internal gate

  AdGateResult _globalGate(AdFormat format, {required bool show}) {
    if (!_supported) return const AdGateResult.blocked(AdBlockReason.unsupportedPlatform);
    if (!_initialized) return const AdGateResult.blocked(AdBlockReason.notInitialized);
    if (!_canRequestAds) return const AdGateResult.blocked(AdBlockReason.consentRequired);
    return show ? _policy.canShow(format) : _policy.canLoad(format);
  }

  AdGateResult _gate(AdPlacement p, {required bool show}) {
    if (!p.enabled || _disabledPlacements.contains(p.name)) {
      return const AdGateResult.blocked(AdBlockReason.placementDisabled);
    }
    return _globalGate(p.format, show: show);
  }

  FullscreenAdController<AdWithoutView> _controllerFor(AdPlacement p) {
    return _controllers.putIfAbsent(p.name, () {
      switch (p.format) {
        case AdFormat.interstitial:
          return InterstitialController(this, p);
        case AdFormat.rewardedInterstitial:
          return RewardedInterstitialController(this, p);
        case AdFormat.rewarded:
          return RewardedController(this, p);
        case AdFormat.appOpen:
          return AppOpenController(this, p);
        case AdFormat.banner:
        case AdFormat.nativeAdvanced:
          throw ArgumentError('${p.name}: banner/native use the AdsBanner/AdsNative widgets, not show*()');
      }
    });
  }

  /// Recomputes the public values; if the load/show conditions changed,
  /// notifies and re-syncs the controllers (load, or discard the held ad).
  void _recompute({bool force = false}) {
    _isPremium.value = _policy.isPremium;
    _isAdFree.value = _policy.isAdFree;
    _disabledRemaining.value = _policy.disabledRemaining;

    var signature = 0;
    for (var i = 0; i < AdFormat.values.length; i++) {
      if (_globalGate(AdFormat.values[i], show: false).allowed) signature |= 1 << i;
    }
    final enabled = _globalGate(AdFormat.banner, show: true).allowed;
    if (enabled) signature |= 1 << 10;
    _adsEnabled.value = enabled;

    if (force || signature != _lastSignature) {
      _lastSignature = signature;
      notifyListeners();
      _syncControllers();
    }
  }

  void _syncControllers() {
    for (final c in _controllers.values) {
      if (gateLoad(c.placement).allowed) {
        c.load();
      } else {
        c.discard();
      }
    }
  }

  /// Schedules timers so the UI/controllers update when the disable period expires or the session time is reached.
  void _scheduleTimers() {
    _ticker?.cancel();
    _unlockTimer?.cancel();
    if (_policy.disabledRemaining != null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
        _recompute();
        if (_policy.disabledRemaining == null) t.cancel();
      });
    }
    final wait = _policy.sessionUnlockIn;
    if (wait != null) {
      _unlockTimer = Timer(wait + const Duration(milliseconds: 50), _recompute);
    }
  }

  // ------------------------------------------------------------------ lifecycle

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_initialized) return;
    if (state == AppLifecycleState.paused) {
      _pausedAt = _clock();
    } else if (state == AppLifecycleState.resumed) {
      _handleResume();
    }
  }

  Future<void> _handleResume() async {
    final pausedAt = _pausedAt;
    _pausedAt = null;
    final pausedFor = pausedAt == null ? Duration.zero : _clock().difference(pausedAt);

    await _policy.registerAppOpen(); // new day while the app was in the background
    if (pausedFor > _policy.rules.sessionResetAfterBackground) {
      _policy.startSession();
      _scheduleTimers();
    }
    _recompute();
    _syncControllers(); // reload failed or expired ads

    if (!_config.autoShowAppOpenOnResume) return;
    final p = _config.appOpenPlacement;
    if (p == null || _appOpenSuppressed > 0 || isFullscreenShowing) return;
    // Closing a full-screen ad also fires "resumed": skip if one just closed.
    final lastEnd = _lastFullscreenEndAt;
    if (lastEnd != null && _clock().difference(lastEnd) < const Duration(milliseconds: 1500)) return;

    await _controllerFor(p).show();
  }
}

class _EventDispatcher extends AdsEventListener {
  final List<AdsEventListener> listeners = [];

  void _each(void Function(AdsEventListener l) fn) {
    for (final l in List.of(listeners)) {
      try {
        fn(l);
      } catch (e) {
        debugPrint('[Ads] event listener error: $e'); // an analytics error must not break ads
      }
    }
  }

  @override
  void onAdLoaded(AdPlacement p) => _each((l) => l.onAdLoaded(p));
  @override
  void onAdLoadFailed(AdPlacement p, LoadAdError e) => _each((l) => l.onAdLoadFailed(p, e));
  @override
  void onAdShown(AdPlacement p) => _each((l) => l.onAdShown(p));
  @override
  void onAdImpression(AdPlacement p) => _each((l) => l.onAdImpression(p));
  @override
  void onAdClicked(AdPlacement p) => _each((l) => l.onAdClicked(p));
  @override
  void onAdDismissed(AdPlacement p) => _each((l) => l.onAdDismissed(p));
  @override
  void onAdShowFailed(AdPlacement p, AdError e) => _each((l) => l.onAdShowFailed(p, e));
  @override
  void onAdBlocked(AdPlacement p, AdGateResult g) => _each((l) => l.onAdBlocked(p, g));
  @override
  void onAdRewardEarned(AdPlacement p, RewardItem r) => _each((l) => l.onAdRewardEarned(p, r));
  @override
  void onAdPaid(AdPlacement p, double v, PrecisionType pr, String c) => _each((l) => l.onAdPaid(p, v, pr, c));
}
