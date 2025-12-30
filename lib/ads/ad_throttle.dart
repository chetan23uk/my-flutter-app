class AdThrottle {
  static final AdThrottle I = AdThrottle._();
  AdThrottle._();

  int _bannerLoadsInWindow = 0;
  DateTime? _bannerWindowStart;
  DateTime? _bannerCooldownUntil;

  DateTime? _lastInterstitialShownAt;

  // ---- Banner rules ----
  // After 3 banner loads -> cooldown 20s
  bool canLoadBanner() {
    final now = DateTime.now();

    if (_bannerCooldownUntil != null && now.isBefore(_bannerCooldownUntil!)) {
      return false;
    }

    _bannerWindowStart ??= now;
    final diff = now.difference(_bannerWindowStart!).inSeconds;

    // reset window if old (e.g., 60s window)
    if (diff > 60) {
      _bannerWindowStart = now;
      _bannerLoadsInWindow = 0;
    }

    return _bannerLoadsInWindow < 3;
  }

  void markBannerLoaded() {
    final now = DateTime.now();
    _bannerWindowStart ??= now;

    _bannerLoadsInWindow++;

    if (_bannerLoadsInWindow >= 3) {
      _bannerCooldownUntil = now.add(const Duration(seconds: 20));
    }
  }

  // ---- Interstitial rules ----
  bool canShowInterstitial() {
    final now = DateTime.now();
    if (_lastInterstitialShownAt == null) return true;
    return now.difference(_lastInterstitialShownAt!).inSeconds >= 40;
  }

  void markInterstitialShown() {
    _lastInterstitialShownAt = DateTime.now();
  }
}
