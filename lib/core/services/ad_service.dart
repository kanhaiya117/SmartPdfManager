import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

abstract final class AdIds {
  static const androidBannerTest = 'ca-app-pub-3940256099942544/6300978111';
  static const androidAppOpenTest = 'ca-app-pub-3940256099942544/9257395921';

  // Replace these test IDs with release IDs through your build configuration
  // before publishing. Test IDs prevent accidental invalid traffic in dev.
  static String get banner => androidBannerTest;
  static String get appOpen => androidAppOpenTest;
}

class AppOpenAdService {
  AppOpenAd? _ad;
  bool _shownThisSession = false;

  void loadAndShowOnce() {
    if (_shownThisSession || kIsWeb) return;
    AppOpenAd.load(
      adUnitId: AdIds.appOpen,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _ad = null;
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _ad = null;
            },
          );
          _shownThisSession = true;
          ad.show();
        },
        onAdFailedToLoad: (_) {},
      ),
    );
  }

  void dispose() {
    _ad?.dispose();
  }
}
