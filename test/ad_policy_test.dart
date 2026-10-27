import 'package:ads_manager/ads_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake clock so tests do not have to wait in real time.
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
  group('active days', () {
    test('first open is day 1, same day does not increment', () async {
      final (policy, clock, _) = await _make();
      expect(policy.activeDays, 1);
      clock.advance(const Duration(hours: 5));
      expect(await policy.registerAppOpen(), isFalse);
      expect(policy.activeDays, 1);
    });

    test('increments on a new day, even a few minutes past midnight', () async {
      final (policy, clock, _) = await _make(start: DateTime(2026, 1, 1, 23, 59));
      clock.advance(const Duration(minutes: 2));
      expect(await policy.registerAppOpen(), isTrue);
      expect(policy.activeDays, 2);
    });

    test('minActiveDays blocks until enough days have passed', () async {
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

    test('data persists across launches', () async {
      final (_, clock, store) = await _make();
      clock.advance(const Duration(days: 1));
      final again = AdPolicy(storage: store, now: clock.call);
      await again.init();
      expect(again.activeDays, 2);
    });
  });

  group('full-screen cooldown', () {
    test('the reference timestamp is shared between interstitial and app open', () async {
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

    test('banner/native are not subject to cooldown', () async {
      final (policy, _, _) = await _make();
      policy.markFullscreenDismissed();
      expect(policy.canShow(AdFormat.banner).allowed, isTrue);
      expect(policy.canShow(AdFormat.nativeAdvanced).allowed, isTrue);
    });

    test('per-format cooldown', () async {
      final (policy, clock, _) = await _make(
        rules: const AdRules(cooldownOverrides: {AdFormat.appOpen: Duration(seconds: 10)}),
      );
      policy.markFullscreenDismissed();
      clock.advance(const Duration(seconds: 10));
      expect(policy.canShow(AdFormat.appOpen).allowed, isTrue);
      expect(policy.canShow(AdFormat.interstitial).allowed, isFalse);
    });
  });

  group('timed disable', () {
    test('no accumulation: resets from now', () async {
      final (policy, clock, _) = await _make();
      await policy.disableFor(const Duration(hours: 24));
      clock.advance(const Duration(hours: 10));
      await policy.disableFor(const Duration(hours: 24));
      expect(policy.disabledRemaining, const Duration(hours: 24));
    });

    test('accumulation: adds to the remaining time', () async {
      final (policy, clock, _) = await _make();
      await policy.disableFor(const Duration(hours: 24), accumulate: true);
      clock.advance(const Duration(hours: 10));
      await policy.disableFor(const Duration(hours: 24), accumulate: true);
      expect(policy.disabledRemaining, const Duration(hours: 38));
    });

    test('accumulating after expiry counts from now', () async {
      final (policy, clock, _) = await _make();
      await policy.disableFor(const Duration(hours: 1), accumulate: true);
      clock.advance(const Duration(hours: 5));
      await policy.disableFor(const Duration(hours: 2), accumulate: true);
      expect(policy.disabledRemaining, const Duration(hours: 2));
    });

    test('ads come back after expiry, and the correct reason is reported while disabled', () async {
      final (policy, clock, _) = await _make();
      await policy.disableFor(const Duration(hours: 1));
      expect(policy.canShow(AdFormat.banner).reason, AdBlockReason.temporarilyDisabled);
      expect(policy.canLoad(AdFormat.interstitial).allowed, isFalse);
      clock.advance(const Duration(hours: 1, seconds: 1));
      expect(policy.canShow(AdFormat.banner).allowed, isTrue);
      expect(policy.disabledRemaining, isNull);
    });

    test('disableBlocksPassiveAds=false only blocks full-screen', () async {
      final (policy, _, _) = await _make(rules: const AdRules(disableBlocksPassiveAds: false));
      await policy.disableFor(const Duration(hours: 1));
      expect(policy.canShow(AdFormat.banner).allowed, isTrue);
      expect(policy.canShow(AdFormat.interstitial).allowed, isFalse);
    });

    test('persists across launches', () async {
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

  group('minimum session time', () {
    test('blocks show but still allows load (preload); app open is exempt', () async {
      final (policy, clock, _) = await _make(rules: const AdRules(minSessionTime: Duration(seconds: 30)));
      expect(policy.canLoad(AdFormat.interstitial).allowed, isTrue);
      expect(policy.canShow(AdFormat.interstitial).reason, AdBlockReason.sessionTooShort);
      expect(policy.canShow(AdFormat.banner).reason, AdBlockReason.sessionTooShort);
      expect(policy.canShow(AdFormat.appOpen).allowed, isTrue);

      clock.advance(const Duration(seconds: 30));
      expect(policy.canShow(AdFormat.interstitial).allowed, isTrue);
      expect(policy.sessionUnlockIn, isNull);
    });

    test('startSession resets the counter', () async {
      final (policy, clock, _) = await _make(rules: const AdRules(minSessionTime: Duration(seconds: 30)));
      clock.advance(const Duration(minutes: 1));
      policy.startSession();
      expect(policy.canShow(AdFormat.interstitial).allowed, isFalse);
    });
  });

  group('premium and rewarded', () {
    test('premium blocks everything including rewarded, and prevents loading', () async {
      final (policy, _, _) = await _make();
      policy.setPremium(true);
      for (final f in AdFormat.values) {
        expect(policy.canLoad(f).reason, AdBlockReason.premium, reason: f.name);
        expect(policy.canShow(f).allowed, isFalse, reason: f.name);
      }
    });

    test('rewarded skips days, session, cooldown and disable', () async {
      final (policy, _, _) = await _make(
        rules: const AdRules(minActiveDays: 10, minSessionTime: Duration(minutes: 5)),
      );
      await policy.disableFor(const Duration(hours: 24));
      policy.markFullscreenDismissed();
      expect(policy.canShow(AdFormat.rewarded).allowed, isTrue);
      expect(policy.canShow(AdFormat.rewardedInterstitial).allowed, isFalse);
    });

    test('with rewardedBypassRules=false rewarded follows the rules', () async {
      final (policy, _, _) = await _make(rules: const AdRules(rewardedBypassRules: false));
      policy.markFullscreenDismissed();
      expect(policy.canShow(AdFormat.rewarded).reason, AdBlockReason.cooldown);
    });
  });
}
