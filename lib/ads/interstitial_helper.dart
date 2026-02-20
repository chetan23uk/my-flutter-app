import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';
import 'ad_throttle.dart';

class InterstitialHelper {
  InterstitialHelper._();
  static final InterstitialHelper instance = InterstitialHelper._();

  // ✅ Interstitial-only rules (banners par apply nahi)
  static const int _kFirstNoAdsSeconds = 30;
  static const int _kSessionCap = 8;

  final DateTime _sessionStart = DateTime.now();
  int _shownThisSession = 0;

  InterstitialAd? _ad;
  bool _loading = false;
  bool _showing = false;

  void preload() {
    if (_ad != null || _loading) return;

    _loading = true;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
        },
        onAdFailedToLoad: (error) {
          _ad = null;
          _loading = false;
        },
      ),
    );
  }

  Future<bool> tryShow({String placement = 'unknown'}) async {
    if (_showing) return false;

    // ✅ First 30 sec: no interstitial
    final now = DateTime.now();
    final sinceStart = now.difference(_sessionStart).inSeconds;
    if (sinceStart < _kFirstNoAdsSeconds) {
      preload();
      return false;
    }

    // ✅ Session cap
    if (_shownThisSession >= _kSessionCap) {
      return false;
    }

    // ✅ 50 sec global cooldown (central control)
    if (!AdThrottle.I.canShowInterstitial()) {
      preload();
      return false;
    }

    // ✅ Ensure we have an ad
    if (_ad == null) {
      preload();
      return false;
    }

    final ad = _ad!;
    _ad = null; // one-time use
    _showing = true;

    final completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        // cooldown start when actually shown
        AdThrottle.I.markInterstitialShown();
        _shownThisSession++;
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showing = false;
        preload();
        if (!completer.isCompleted) completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _showing = false;
        preload();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    ad.show();
    return completer.future;
  }
}
