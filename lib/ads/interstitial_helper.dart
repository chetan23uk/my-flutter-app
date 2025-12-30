import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';

class InterstitialHelper {
  InterstitialHelper._();
  static final InterstitialHelper instance = InterstitialHelper._();

  static const Duration _cooldown = Duration(seconds: 80);

  InterstitialAd? _ad;
  DateTime? _lastShownTime;
  bool _isLoading = false;

  /// Call this once (optional) – app start ya first screen pe
  void preload() {
    if (_isLoading || _ad != null) return;
    _load();
  }

  /// Try to show interstitial (safe)
  Future<void> tryShow() async {
    // 🔒 Cooldown check
    if (_lastShownTime != null) {
      final diff = DateTime.now().difference(_lastShownTime!);
      if (diff < _cooldown) {
        return;
      }
    }

    // Ad ready nahi hai
    if (_ad == null) {
      _load();
      return;
    }

    _ad!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _lastShownTime = DateTime.now();
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        _load(); // 🔁 preload next
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _ad = null;
        _load();
      },
    );

    _ad!.show();
    _ad = null;
  }

  void _load() {
    if (_isLoading) return;
    _isLoading = true;

    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoading = false;
          _ad = ad;
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          _ad = null;
          // ignore: avoid_print
          print(
            'INTERSTITIAL failed: code=${error.code}, message=${error.message}',
          );
        },
      ),
    );
  }
}
