// lib/ads/banner_ad_cache.dart
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// ✅ Rebuild-safe banner cache
/// - Same placement+slot+size key -> same BannerAd reuse (when only 1 consumer)
/// - If same key is mounted multiple times simultaneously:
///   -> creates a safe clone-key so each AdWidget gets its own BannerAd
class BannerAdCache {
  BannerAdCache._();
  static final BannerAdCache I = BannerAdCache._();

  final Map<String, ValueNotifier<BannerAd?>> _ads = {};
  final Map<String, bool> _loading = {};

  // ✅ Track how many widgets are currently using the *base* key
  final Map<String, int> _baseRefCount = {};

  // ✅ When we create clone keys, we remember which base they belong to
  final Map<String, String> _cloneToBase = {};

  ValueListenable<BannerAd?> listenable(String key) {
    return _ads.putIfAbsent(key, () => ValueNotifier<BannerAd?>(null));
  }

  BannerAd? get(String key) => _ads[key]?.value;

  bool isLoading(String key) => _loading[key] == true;

  /// ✅ Acquire a safe cache key for this widget mount.
  /// If baseKey is already mounted, returns a clone key: "$baseKey@1", "$baseKey@2"...
  String acquireKey(String baseKey) {
    final current = _baseRefCount[baseKey] ?? 0;
    _baseRefCount[baseKey] = current + 1;

    // First consumer uses baseKey directly (best caching)
    if (current == 0) return baseKey;

    // Additional consumers use clone keys to avoid "AdWidget already in tree"
    int i = current; // start from current (1,2,3...)
    String cloneKey = '$baseKey@$i';
    while (_ads.containsKey(cloneKey) || _cloneToBase.containsKey(cloneKey)) {
      i++;
      cloneKey = '$baseKey@$i';
    }
    _cloneToBase[cloneKey] = baseKey;
    return cloneKey;
  }

  /// ✅ Release a key acquired by acquireKey().
  /// Clone keys are disposed immediately; base key stays cached.
  void releaseKey(String acquiredKey) {
    final baseKey = _cloneToBase.remove(acquiredKey) ?? acquiredKey;

    final current = _baseRefCount[baseKey] ?? 0;
    if (current <= 1) {
      _baseRefCount.remove(baseKey);
    } else {
      _baseRefCount[baseKey] = current - 1;
    }

    // If this was a clone key, dispose it fully to avoid memory growth
    if (acquiredKey != baseKey) {
      disposeKey(acquiredKey);
    }
  }

  void preload({
    required String key,
    required String adUnitId,
    required AdSize size,
  }) {
    final notifier = _ads.putIfAbsent(key, () => ValueNotifier<BannerAd?>(null));

    // ✅ Already loaded
    if (notifier.value != null) return;

    // ✅ Already loading
    if (_loading[key] == true) return;

    _loading[key] = true;

    final ad = BannerAd(
      adUnitId: adUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _loading[key] = false;
          notifier.value = ad as BannerAd;
        },
        onAdFailedToLoad: (ad, error) {
          _loading[key] = false;
          ad.dispose();
          // notifier stays null; later preload() can retry
        },
      ),
    );

    ad.load();
  }

  /// Optional: dispose single cached banner
  void disposeKey(String key) {
    _loading.remove(key);

    final notifier = _ads.remove(key);
    final ad = notifier?.value;

    notifier?.dispose();
    ad?.dispose();
  }

  /// Optional: clear all cached banners
  void clearAll() {
    final keys = _ads.keys.toList();
    for (final k in keys) {
      disposeKey(k);
    }
    _baseRefCount.clear();
    _cloneToBase.clear();
  }
}
