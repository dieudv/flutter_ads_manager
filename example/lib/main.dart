import 'package:ads_manager/ads_manager.dart';
import 'package:flutter/material.dart';

import 'app_ads.dart';

/// Ví dụ đẩy sự kiện ads sang analytics.
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
        minActiveDays: 1, // đặt 3 để chỉ hiện ads từ ngày hoạt động thứ 3
        minSessionTime: Duration(seconds: 20),
        fullscreenCooldown: Duration(seconds: 60),
      ),
      appOpenPlacement: AppAds.appOpen,
      preload: [AppAds.afterSave, AppAds.removeAdsReward, AppAds.bonusRewardedInter],
    ),
    isPremium: false, // lấy từ kết quả kiểm tra in-app purchase
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
          // Đếm ngược thời gian đã tắt quảng cáo.
          ValueListenableBuilder<Duration?>(
            valueListenable: ads.disabledRemaining,
            builder: (_, left, _) => Text(
              left == null ? 'Quảng cáo đang bật' : 'Đã tắt quảng cáo, còn ${_fmt(left)}',
            ),
          ),
          const SizedBox(height: 12),

          // Chỉ hiện nút khi rewarded đã sẵn sàng.
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
                    child: const Text('Xem video để tắt quảng cáo 24h'),
                  )
                : const SizedBox.shrink(),
          ),

          FilledButton.tonal(
            onPressed: () async {
              // Future hoàn tất sau khi ad đóng (hoặc ngay lập tức nếu bị chặn).
              await ads.showInterstitial(AppAds.afterSave);
              if (context.mounted) {
                Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const DetailPage()));
              }
            },
            child: const Text('Lưu rồi sang màn chi tiết (interstitial)'),
          ),

          FilledButton.tonal(
            onPressed: () => ads.showRewardedInterstitial(AppAds.bonusRewardedInter),
            child: const Text('Rewarded interstitial'),
          ),

          // Ví dụ thao tác làm app vào nền: không để App Open bật khi quay lại.
          FilledButton.tonal(
            onPressed: () => ads.runWithoutAppOpen(() async {
              // await ImagePicker().pickImage(...);
              await Future<void>.delayed(const Duration(seconds: 1));
            }),
            child: const Text('Mở image picker (không hiện App Open)'),
          ),

          ValueListenableBuilder<bool>(
            valueListenable: ads.isPremium,
            builder: (_, premium, _) => SwitchListTile(
              title: const Text('Premium (ẩn toàn bộ quảng cáo)'),
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
        appBar: AppBar(title: const Text('Chi tiết')),
        body: const Center(child: Text('Nội dung')),
        bottomNavigationBar: const SafeArea(child: AdsBanner(placement: AppAds.detailBanner)),
      );
}
