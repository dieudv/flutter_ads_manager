import 'dart:math' as math;

import '../config/ad_format.dart';
import '../config/ad_rules.dart';
import '../storage/ad_storage.dart';
import 'ad_gate.dart';

/// Toàn bộ logic "có được load / được show ad hay không".
///
/// Thuần Dart (không import SDK), nhận giờ và storage từ bên ngoài
/// nên unit test được dễ dàng.
class AdPolicy {
  AdPolicy({
    required AdStorage storage,
    AdRules rules = const AdRules(),
    DateTime Function()? now,
  })  : _storage = storage,
        _rules = rules,
        _now = now ?? DateTime.now;

  static const _kActiveDays = 'active_days';
  static const _kLastOpenDate = 'last_open_date';
  static const _kDisabledUntil = 'disabled_until';

  final AdStorage _storage;
  final DateTime Function() _now;
  AdRules _rules;

  int _activeDays = 0;
  String? _lastOpenDate;
  int? _disabledUntilMs;
  bool _isPremium = false;
  DateTime? _sessionStart;
  DateTime? _lastFullscreenDismissedAt;

  AdRules get rules => _rules;
  set rules(AdRules value) => _rules = value;

  int get activeDays => _activeDays;
  bool get isPremium => _isPremium;

  /// Nạp dữ liệu đã lưu, ghi nhận lần mở app hiện tại và bắt đầu phiên mới.
  Future<void> init() async {
    _activeDays = await _storage.getInt(_kActiveDays) ?? 0;
    _lastOpenDate = await _storage.getString(_kLastOpenDate);
    _disabledUntilMs = await _storage.getInt(_kDisabledUntil);
    _sessionStart = _now();
    await registerAppOpen();
  }

  // ---------------------------------------------------------------- ngày hoạt động

  /// Nếu hôm nay khác ngày mở app gần nhất thì tăng số ngày hoạt động.
  /// Gọi an toàn nhiều lần trong ngày. Trả về `true` nếu có tăng.
  Future<bool> registerAppOpen() async {
    final today = _dateKey(_now());
    if (_lastOpenDate == today) return false;
    _lastOpenDate = today;
    _activeDays += 1;
    await _storage.setString(_kLastOpenDate, today);
    await _storage.setInt(_kActiveDays, _activeDays);
    return true;
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------- phiên

  void startSession() => _sessionStart = _now();

  /// Còn bao lâu nữa thì đủ [AdRules.minSessionTime]. `null` nếu đã đủ.
  Duration? get sessionUnlockIn {
    final min = _rules.minSessionTime;
    if (min <= Duration.zero) return null;
    final start = _sessionStart;
    if (start == null) return min;
    final left = min - _now().difference(start);
    return left > Duration.zero ? left : null;
  }

  // ---------------------------------------------------------------- premium

  void setPremium(bool value) => _isPremium = value;

  // ---------------------------------------------------------------- disable theo giờ

  Duration? get disabledRemaining {
    final until = _disabledUntilMs;
    if (until == null) return null;
    final left = until - _now().millisecondsSinceEpoch;
    return left > 0 ? Duration(milliseconds: left) : null;
  }

  bool get isTemporarilyDisabled => disabledRemaining != null;

  /// Tắt quảng cáo trong [duration].
  /// - [accumulate] = true: cộng dồn vào thời gian còn lại (max(now, until) + duration).
  /// - [accumulate] = false: đặt lại thành now + duration.
  Future<void> disableFor(Duration duration, {bool accumulate = false}) async {
    final nowMs = _now().millisecondsSinceEpoch;
    final base = accumulate ? math.max(nowMs, _disabledUntilMs ?? 0) : nowMs;
    _disabledUntilMs = base + duration.inMilliseconds;
    await _storage.setInt(_kDisabledUntil, _disabledUntilMs!);
  }

  Future<void> clearDisabled() async {
    _disabledUntilMs = null;
    await _storage.remove(_kDisabledUntil);
  }

  // ---------------------------------------------------------------- cooldown full-screen

  /// Gọi khi BẤT KỲ quảng cáo toàn màn hình nào được đóng.
  void markFullscreenDismissed() => _lastFullscreenDismissedAt = _now();

  Duration? cooldownRemaining(AdFormat f) {
    final last = _lastFullscreenDismissedAt;
    if (last == null) return null;
    final left = _rules.cooldownFor(f) - _now().difference(last);
    return left > Duration.zero ? left : null;
  }

  // ---------------------------------------------------------------- cổng quyết định

  bool _bypasses(AdFormat f) => f == AdFormat.rewarded && _rules.rewardedBypassRules;

  /// Có được phép load (tốn request) hay không.
  AdGateResult canLoad(AdFormat f) {
    if (_isPremium) return const AdGateResult.blocked(AdBlockReason.premium);
    if (_bypasses(f)) return const AdGateResult.ok();
    if (_activeDays < _rules.minActiveDays) {
      return const AdGateResult.blocked(AdBlockReason.notEnoughActiveDays);
    }
    final disabled = disabledRemaining;
    if (disabled != null && (f.isFullscreen || _rules.disableBlocksPassiveAds)) {
      return AdGateResult.blocked(AdBlockReason.temporarilyDisabled, retryAfter: disabled);
    }
    return const AdGateResult.ok();
  }

  /// Có được phép hiển thị ngay lúc này hay không.
  AdGateResult canShow(AdFormat f) {
    final load = canLoad(f);
    if (!load.allowed) return load;
    if (_bypasses(f)) return const AdGateResult.ok();

    if (f != AdFormat.appOpen) {
      final wait = sessionUnlockIn;
      if (wait != null) return AdGateResult.blocked(AdBlockReason.sessionTooShort, retryAfter: wait);
    }
    if (f.isFullscreen) {
      final wait = cooldownRemaining(f);
      if (wait != null) return AdGateResult.blocked(AdBlockReason.cooldown, retryAfter: wait);
    }
    return const AdGateResult.ok();
  }

  String debugSummary() => 'activeDays=$_activeDays (min ${_rules.minActiveDays}), '
      'premium=$_isPremium, disabledRemaining=$disabledRemaining, '
      'sessionUnlockIn=$sessionUnlockIn, '
      'cooldown(interstitial)=${cooldownRemaining(AdFormat.interstitial)}';
}
