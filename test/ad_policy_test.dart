import 'package:ads_manager/ads_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// Đồng hồ giả để test mà không phải chờ thật.
class FakeClock {
  FakeClock(this.value);
  DateTime value;
  DateTime call() => value;
  void advance(Duration d) => value = value.add(d);
}

Future<(AdPolicy, FakeClock, MemoryAdStorage)> _make({
  AdRules rules = const AdRules(),
  MemoryAdStorage? storage,
  DateTime? start,
}) async {
  final clock = FakeClock(start ?? DateTime(2026, 1, 1, 10));
  final store = storage ?? MemoryAdStorage();
  final policy = AdPolicy(storage: store, rules: rules, now: clock.call);
  await policy.init();
  return (policy, clock, store);
}

void main() {
  group('số ngày hoạt động', () {
    test('lần mở đầu tiên là ngày 1, cùng ngày không tăng', () async {
      final (policy, clock, _) = await _make();
      expect(policy.activeDays, 1);
      clock.advance(const Duration(hours: 5));
      expect(await policy.registerAppOpen(), isFalse);
      expect(policy.activeDays, 1);
    });

    test('sang ngày khác thì tăng, kể cả khi chỉ cách vài phút qua nửa đêm', () async {
      final (policy, clock, _) = await _make(start: DateTime(2026, 1, 1, 23, 59));
      clock.advance(const Duration(minutes: 2));
      expect(await policy.registerAppOpen(), isTrue);
      expect(policy.activeDays, 2);
    });

    test('minActiveDays chặn đến khi đủ ngày', () async {
      final (policy, clock, _) = await _make(rules: const AdRules(minActiveDays: 3));
      expect(policy.canShow(AdFormat.interstitial).reason, AdBlockReason.notEnoughActiveDays);
      clock.advance(const Duration(days: 1));
      await policy.registerAppOpen();
      expect(policy.canShow(AdFormat.interstitial).allowed, isFalse);
      clock.advance(const Duration(days: 1));
      await policy.registerAppOpen();
      expect(policy.activeDays, 3);
      expect(policy.canShow(AdFormat.interstitial).allowed, isTrue);
    });

    test('dữ liệu được lưu qua các lần khởi động', () async {
      final (_, clock, store) = await _make();
      clock.advance(const Duration(days: 1));
      final again = AdPolicy(storage: store, now: clock.call);
      await again.init();
      expect(again.activeDays, 2);
    });
  });

  group('cooldown toàn màn hình', () {
    test('mốc dùng chung giữa interstitial và app open', () async {
      final (policy, clock, _) = await _make();
      expect(policy.canShow(AdFormat.appOpen).allowed, isTrue);
      policy.markFullscreenDismissed();

      expect(policy.canShow(AdFormat.interstitial).reason, AdBlockReason.cooldown);
      expect(policy.canShow(AdFormat.appOpen).reason, AdBlockReason.cooldown);

      clock.advance(const Duration(seconds: 59));
      expect(policy.canShow(AdFormat.appOpen).allowed, isFalse);
      clock.advance(const Duration(seconds: 1));
      expect(policy.canShow(AdFormat.appOpen).allowed, isTrue);
      expect(policy.canShow(AdFormat.interstitial).allowed, isTrue);
    });

    test('banner/native không bị cooldown', () async {
      final (policy, _, _) = await _make();
      policy.markFullscreenDismissed();
      expect(policy.canShow(AdFormat.banner).allowed, isTrue);
      expect(policy.canShow(AdFormat.nativeAdvanced).allowed, isTrue);
    });

    test('cooldown riêng cho từng format', () async {
      final (policy, clock, _) = await _make(
        rules: const AdRules(cooldownOverrides: {AdFormat.appOpen: Duration(seconds: 10)}),
      );
      policy.markFullscreenDismissed();
      clock.advance(const Duration(seconds: 10));
      expect(policy.canShow(AdFormat.appOpen).allowed, isTrue);
      expect(policy.canShow(AdFormat.interstitial).allowed, isFalse);
    });
  });

  group('disable theo giờ', () {
    test('không cộng dồn: đặt lại từ bây giờ', () async {
      final (policy, clock, _) = await _make();
      await policy.disableFor(const Duration(hours: 24));
      clock.advance(const Duration(hours: 10));
      await policy.disableFor(const Duration(hours: 24));
      expect(policy.disabledRemaining, const Duration(hours: 24));
    });

    test('cộng dồn: cộng vào thời gian còn lại', () async {
      final (policy, clock, _) = await _make();
      await policy.disableFor(const Duration(hours: 24), accumulate: true);
      clock.advance(const Duration(hours: 10));
      await policy.disableFor(const Duration(hours: 24), accumulate: true);
      expect(policy.disabledRemaining, const Duration(hours: 38));
    });

    test('cộng dồn khi đã hết hạn thì tính từ bây giờ', () async {
      final (policy, clock, _) = await _make();
      await policy.disableFor(const Duration(hours: 1), accumulate: true);
      clock.advance(const Duration(hours: 5));
      await policy.disableFor(const Duration(hours: 2), accumulate: true);
      expect(policy.disabledRemaining, const Duration(hours: 2));
    });

    test('hết hạn thì ads trở lại, và chặn đúng lý do khi đang disable', () async {
      final (policy, clock, _) = await _make();
      await policy.disableFor(const Duration(hours: 1));
      expect(policy.canShow(AdFormat.banner).reason, AdBlockReason.temporarilyDisabled);
      expect(policy.canLoad(AdFormat.interstitial).allowed, isFalse);
      clock.advance(const Duration(hours: 1, seconds: 1));
      expect(policy.canShow(AdFormat.banner).allowed, isTrue);
      expect(policy.disabledRemaining, isNull);
    });

    test('disableBlocksPassiveAds=false chỉ chặn full-screen', () async {
      final (policy, _, _) = await _make(rules: const AdRules(disableBlocksPassiveAds: false));
      await policy.disableFor(const Duration(hours: 1));
      expect(policy.canShow(AdFormat.banner).allowed, isTrue);
      expect(policy.canShow(AdFormat.interstitial).allowed, isFalse);
    });

    test('được lưu qua các lần khởi động', () async {
      final (policy, clock, store) = await _make();
      await policy.disableFor(const Duration(hours: 24));
      final again = AdPolicy(storage: store, now: clock.call);
      await again.init();
      expect(again.disabledRemaining, const Duration(hours: 24));
    });

    test('clearDisabled', () async {
      final (policy, _, _) = await _make();
      await policy.disableFor(const Duration(hours: 24));
      await policy.clearDisabled();
      expect(policy.canShow(AdFormat.banner).allowed, isTrue);
    });
  });

  group('thời gian phiên tối thiểu', () {
    test('chặn show nhưng vẫn cho load (preload), app open được miễn', () async {
      final (policy, clock, _) = await _make(rules: const AdRules(minSessionTime: Duration(seconds: 30)));
      expect(policy.canLoad(AdFormat.interstitial).allowed, isTrue);
      expect(policy.canShow(AdFormat.interstitial).reason, AdBlockReason.sessionTooShort);
      expect(policy.canShow(AdFormat.banner).reason, AdBlockReason.sessionTooShort);
      expect(policy.canShow(AdFormat.appOpen).allowed, isTrue);

      clock.advance(const Duration(seconds: 30));
      expect(policy.canShow(AdFormat.interstitial).allowed, isTrue);
      expect(policy.sessionUnlockIn, isNull);
    });

    test('startSession đặt lại bộ đếm', () async {
      final (policy, clock, _) = await _make(rules: const AdRules(minSessionTime: Duration(seconds: 30)));
      clock.advance(const Duration(minutes: 1));
      policy.startSession();
      expect(policy.canShow(AdFormat.interstitial).allowed, isFalse);
    });
  });

  group('premium và rewarded', () {
    test('premium chặn mọi thứ kể cả rewarded và không cho load', () async {
      final (policy, _, _) = await _make();
      policy.setPremium(true);
      for (final f in AdFormat.values) {
        expect(policy.canLoad(f).reason, AdBlockReason.premium, reason: f.name);
        expect(policy.canShow(f).allowed, isFalse, reason: f.name);
      }
    });

    test('rewarded bỏ qua ngày, phiên, cooldown và disable', () async {
      final (policy, _, _) = await _make(
        rules: const AdRules(minActiveDays: 10, minSessionTime: Duration(minutes: 5)),
      );
      await policy.disableFor(const Duration(hours: 24));
      policy.markFullscreenDismissed();
      expect(policy.canShow(AdFormat.rewarded).allowed, isTrue);
      expect(policy.canShow(AdFormat.rewardedInterstitial).allowed, isFalse);
    });

    test('rewardedBypassRules=false thì rewarded tuân theo luật', () async {
      final (policy, _, _) = await _make(rules: const AdRules(rewardedBypassRules: false));
      policy.markFullscreenDismissed();
      expect(policy.canShow(AdFormat.rewarded).reason, AdBlockReason.cooldown);
    });
  });
}
