// lib/ads/banner_plan.dart
class BannerPlan {
  final int itemCount;
  final int bannerCount;
  final List<int> adPositions; // sorted list-index positions where ads appear
  final int totalCount;

  BannerPlan._({
    required this.itemCount,
    required this.bannerCount,
    required this.adPositions,
    required this.totalCount,
  });

  // Your rule:
  // items < 7  => 1 banner
  // 7..13      => 1 banner
  // items ==14 => 2 banners
  // 15..25     => 3 banners
  // >25        => 3 + floor((items-25)/10)
  //
  // maxBanners safety cap (optional) to avoid too many banners on huge lists.
  static int bannerCountForItems(int items, {int maxBanners = 10}) {
    if (items <= 0) return 0;

    int c;
    if (items < 14) {
      c = 1;
    } else if (items == 14) {
      c = 2;
    } else if (items <= 25) {
      c = 3;
    } else {
      c = 3 + ((items - 25) ~/ 10);
    }

    if (c > maxBanners) c = maxBanners;
    return c;
  }

  /// Distribute ad positions evenly in list-space.
  /// We avoid very first and very last positions for better UX.
  static BannerPlan build({required int items, required int banners}) {
    if (items <= 0 || banners <= 0) {
      return BannerPlan._(
        itemCount: items,
        bannerCount: 0,
        adPositions: const [],
        totalCount: items,
      );
    }

    final total = items + banners;

    final positions = <int>[];
    final step = total / (banners + 1);

    for (int i = 1; i <= banners; i++) {
      int pos = (step * i).round();
      if (pos < 1) pos = 1;
      if (pos > total - 2) pos = total - 2;
      positions.add(pos);
    }

    positions.sort();

    // Fix collisions by nudging forward
    for (int i = 1; i < positions.length; i++) {
      if (positions[i] <= positions[i - 1]) {
        positions[i] = positions[i - 1] + 1;
      }
    }

    // Clamp again after nudges
    for (int i = 0; i < positions.length; i++) {
      if (positions[i] < 1) positions[i] = 1;
      if (positions[i] > total - 2) positions[i] = total - 2;
    }

    // Ensure unique
    final unique = <int>[];
    for (final p in positions) {
      if (!unique.contains(p)) unique.add(p);
    }

    return BannerPlan._(
      itemCount: items,
      bannerCount: unique.length,
      adPositions: unique,
      totalCount: items + unique.length,
    );
  }

  bool isAdIndex(int listIndex) => adPositions.contains(listIndex);

  /// slot = 0..bannerCount-1 (stable)
  int slotForListIndex(int listIndex) => adPositions.indexOf(listIndex);

  /// Convert list index -> data index (subtract ads before it)
  int dataIndexFromListIndex(int listIndex) {
    int adsBefore = 0;
    for (final p in adPositions) {
      if (p < listIndex) {
        adsBefore++;
      } else {
        break;
      }
    }
    return listIndex - adsBefore;
  }
}
