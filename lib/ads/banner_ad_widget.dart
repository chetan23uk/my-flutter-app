import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class BannerAdWidget extends StatefulWidget {
  final String adUnitId;

  /// ✅ OPTIONAL: agar aap kisi jagah fixed size chahte ho to pass kar sakte ho.
  /// agar null hua to random size choose hoga.
  final AdSize? size;

  const BannerAdWidget({
    super.key,
    required this.adUnitId,
    this.size, // ✅ optional (no more required error)
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  late final AdSize _adSize;

  @override
  void initState() {
    super.initState();

    // ✅ If size provided -> use it, else random (aayat/chakor)
    _adSize = widget.size ?? (Random().nextBool() ? AdSize.banner : AdSize.mediumRectangle);

    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      size: _adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          // ignore: avoid_print
          print('BANNER failed: code=${err.code}, message=${err.message}');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Center(
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
