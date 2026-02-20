// lib/ads/banner_ad_widget.dart
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class BannerAdWidget extends StatefulWidget {
  final String adUnitId;

  /// ✅ Unique placement per screen/list
  final String placement;

  /// ✅ Stable slot within the same placement (0..N-1)
  final int slot;

  /// ✅ Fixed size (recommended). Default: banner
  final AdSize size;

  const BannerAdWidget({
    super.key,
    required this.adUnitId,
    required this.placement,
    required this.slot,
    this.size = AdSize.banner,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  late String _baseKey;

  String _buildBaseKey() {
    return '${widget.adUnitId}#${widget.placement}#${widget.slot}'
        '#${widget.size.width}x${widget.size.height}';
  }

  void _disposeAd() {
    try {
      _ad?.dispose();
    } catch (_) {}
    _ad = null;
    _loaded = false;
  }

  void _loadAd() {
    _baseKey = _buildBaseKey();

    _disposeAd();

    final ad = BannerAd(
      adUnitId: widget.adUnitId,
      size: widget.size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _ad = ad as BannerAd;
            _loaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _ad = null;
            _loaded = false;
          });
        },
      ),
    );

    ad.load();
  }

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  @override
  void didUpdateWidget(covariant BannerAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newBase = _buildBaseKey();
    final oldBase = _baseKey;

    // ✅ If placement/slot/size/adUnit changed, create NEW BannerAd instance
    if (newBase != oldBase) {
      _loadAd();
    }
  }

  @override
  void dispose() {
    _disposeAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;

    if (!_loaded || ad == null) {
      return const SizedBox.shrink();
    }

    return Center(
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        // ✅ Key ensures widget tree doesn't try to reuse same ad widget incorrectly
        child: AdWidget(
          key: ValueKey(ad),
          ad: ad,
        ),
      ),
    );
  }
}
