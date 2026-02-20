part of '../home_screen.dart';

mixin _HomeAdsMixin on _HomeScreenState {
  static const int _kInlineAdEvery = 7; // every 7 items

  @override
  Widget _inlineBanner({
    required String placement,
    AdSize size = AdSize.banner,
    required int slot,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Center(
        child: BannerAdWidget(
          adUnitId: AdIds.banner, // ✅ FIX: required param
          placement: placement,
          size: size,
          slot: slot,
        ),
      ),
    );
  }
}
