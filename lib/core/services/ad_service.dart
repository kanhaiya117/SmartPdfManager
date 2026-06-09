import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

abstract final class AdIds {
  static const _androidBannerTest = 'ca-app-pub-3940256099942544/6300978111';
  static const _androidInterstitialTest =
      'ca-app-pub-3940256099942544/1033173712';

  static const _androidInterstitialProduction =
      'ca-app-pub-3635529617309575/9865459290';

  // A production banner unit was not supplied, so release builds hide it.
  static String? get banner => kDebugMode ? _androidBannerTest : null;

  static String get interstitial =>
      kDebugMode ? _androidInterstitialTest : _androidInterstitialProduction;
}

class InterstitialAdService {
  static const _minimumCompletedActions = 2;
  static const _actionsBetweenAds = 3;
  static const _maximumAdsPerSession = 2;
  static const _minimumInterval = Duration(minutes: 3);

  InterstitialAd? _ad;
  var _isLoading = false;
  var _completedActions = 0;
  var _lastShownAtAction = 0;
  var _shownThisSession = 0;
  DateTime? _lastShownAt;

  void preload() {
    if (kIsWeb || _ad != null || _isLoading) return;
    _isLoading = true;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoading = false;
          _ad = ad;
        },
        onAdFailedToLoad: (_) {
          _isLoading = false;
          _ad = null;
        },
      ),
    );
  }

  Future<void> showAfterCompletedAction({
    required FutureOr<void> Function() onContinue,
  }) async {
    _completedActions++;
    final ad = _ad;
    if (ad == null || !_isEligible) {
      preload();
      await onContinue();
      return;
    }

    _ad = null;
    final completer = Completer<void>();
    var continued = false;

    Future<void> continueOnce() async {
      if (continued) return;
      continued = true;
      try {
        await onContinue();
        if (!completer.isCompleted) completer.complete();
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      }
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        _shownThisSession++;
        _lastShownAt = DateTime.now();
        _lastShownAtAction = _completedActions;
      },
      onAdDismissedFullScreenContent: (shownAd) {
        shownAd.dispose();
        preload();
        unawaited(continueOnce());
      },
      onAdFailedToShowFullScreenContent: (failedAd, _) {
        failedAd.dispose();
        preload();
        unawaited(continueOnce());
      },
    );
    try {
      ad.show();
    } catch (_) {
      ad.dispose();
      preload();
      await continueOnce();
    }
    await completer.future;
  }

  bool get _isEligible {
    if (_shownThisSession >= _maximumAdsPerSession) return false;
    if (_completedActions < _minimumCompletedActions) return false;
    if (_shownThisSession > 0 &&
        _completedActions - _lastShownAtAction < _actionsBetweenAds) {
      return false;
    }
    final lastShown = _lastShownAt;
    return lastShown == null ||
        DateTime.now().difference(lastShown) >= _minimumInterval;
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}
