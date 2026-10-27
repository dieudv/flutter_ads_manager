import 'package:ads_manager/ads_manager.dart';
import 'package:flutter/material.dart';

import 'app_ads.dart';

/// Example of forwarding ad events to analytics.
class LogAdsListener extends AdsEventListener {
  @override
  void onAdPaid(AdPlacement p, double valueMicros, PrecisionType precision, String currency) =>
      debugPrint('[paid] ${p.name} ${valueMicros / 1e6} $currency');

  @override
  void onAdBlocked(AdPlacement p, AdGateResult gate) => debugPrint('[blocked] ${p.name}: $gate');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AdsManager.I.initialize(
    const AdsConfig(
      rules: AdRules(
        minActiveDays: 1, // set to 3 to show ads only from the 3rd active day
        minSessionTime: Duration(seconds: 20),
        fullscreenCooldown: Duration(seconds: 60),
      ),
      appOpenPlacement: AppAds.appOpen,
      preload: [AppAds.afterSave, AppAds.removeAdsReward, AppAds.bonusRewardedInter],
    ),
    isPremium: false, // taken from the in-app purchase check
    gatherConsent: true,
  );
  AdsManager.I.addEventListener(LogAdsListener());

  runApp(const MaterialApp(home: HomePage()));
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ads = AdsManager.I;
    return Scaffold(
      appBar: AppBar(title: const Text('Ads manager demo')),
      bottomNavigationBar: const SafeArea(child: AdsBanner(placement: AppAds.homeBanner)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Countdown of the time ads are disabled.
          ValueListenableBuilder<Duration?>(
            valueListenable: ads.disabledRemaining,
            builder: (_, left, _) => Text(
              left == null ? 'Ads are enabled' : 'Ads disabled, time left: ${_fmt(left)}',
            ),
          ),
          const SizedBox(height: 12),

          // Only show the button when the rewarded ad is ready.
          AdReadyBuilder(
            placement: AppAds.removeAdsReward,
            builder: (context, ready) => ready
                ? FilledButton(
                    onPressed: () async {
                      final r = await ads.showRewarded(AppAds.removeAdsReward);
                      if (r.rewardEarned) {
                        await ads.disableAdsFor(const Duration(hours: 24), accumulate: true);
                      }
                    },
                    child: const Text('Watch a video to disable ads for 24h'),
                  )
                : const SizedBox.shrink(),
          ),

          FilledButton.tonal(
            onPressed: () async {
              // The Future completes after the ad closes (or immediately if blocked).
              await ads.showInterstitial(AppAds.afterSave);
              if (context.mounted) {
                Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const DetailPage()));
              }
            },
            child: const Text('Save and go to the detail screen (interstitial)'),
          ),

          FilledButton.tonal(
            onPressed: () => ads.showRewardedInterstitial(AppAds.bonusRewardedInter),
            child: const Text('Rewarded interstitial'),
          ),

          // Example of an operation that backgrounds the app: do not show App Open on return.
          FilledButton.tonal(
            onPressed: () => ads.runWithoutAppOpen(() async {
              // await ImagePicker().pickImage(...);
              await Future<void>.delayed(const Duration(seconds: 1));
            }),
            child: const Text('Open image picker (no App Open)'),
          ),

          ValueListenableBuilder<bool>(
            valueListenable: ads.isPremium,
            builder: (_, premium, _) => SwitchListTile(
              title: const Text('Premium (hides all ads)'),
              value: premium,
              onChanged: ads.setPremium,
            ),
          ),
          const SizedBox(height: 12),
          const AdsNative(placement: AppAds.listNative),
        ],
      ),
    );
  }

  static String _fmt(Duration d) => '${d.inHours}h ${d.inMinutes % 60}m ${d.inSeconds % 60}s';
}

class DetailPage extends StatelessWidget {
  const DetailPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Detail')),
        body: const Center(child: Text('Content')),
        bottomNavigationBar: const SafeArea(child: AdsBanner(placement: AppAds.detailBanner)),
      );
}
