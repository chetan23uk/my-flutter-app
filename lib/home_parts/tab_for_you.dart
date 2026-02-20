part of '../home_screen.dart';

extension _HomeTabForYouExt on _HomeScreenState {
  // For You: current playlist ke base pe “recently played”
  Widget _buildForYou() {
    final list = PlayerManager.I.currentPlaylist();
    final currentIndex = PlayerManager.I.player.currentIndex ?? -1;

    if (list.isEmpty || currentIndex < 0) {
      return Center(
        child: Text(
          'for_you_empty'.tr(),
          style: const TextStyle(color: Colors.white60),
        ),
      );
    }

    // current se peeche ki taraf max 20 gaane
    final recent = <SongModel>[];
    for (int i = currentIndex; i >= 0 && recent.length < 20; i--) {
      recent.add(list[i]);
    }

    // cache for all-select
    _cacheForYouSongs = recent;

    final int len = recent.length;

    final int bannerCount = BannerPlan.bannerCountForItems(len);
    final plan = BannerPlan.build(items: len, banners: bannerCount);
    final int totalCount = plan.totalCount;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 92),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        // ✅ AD LOGIC: BannerPlan ke according ads
        final bool isAd = plan.isAdIndex(index);

        if (isAd) {
          return _inlineBanner(
            placement: 'home_for_you',
            slot: plan.slotForListIndex(index),
          );
        }

        // ✅ REAL INDEX CALCULATION
        final int realIdx = plan.dataIndexFromListIndex(index);

        // Guard: out of range safety
        if (realIdx < 0 || realIdx >= len) {
          return const SizedBox.shrink();
        }

        final s = recent[realIdx];
        final realIndex = list.indexWhere((e) => e.id == s.id);

        final title = _cleanTitle(s);
        final artist = _artistOf(s);

        final selected = _selectedSongIds.contains(s.id);

        return Column(
          children: [
            ListTile(
              leading: _selectMode
                  ? Checkbox(
                value: selected,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedSongIds.add(s.id);
                    } else {
                      _selectedSongIds.remove(s.id);
                    }
                  });
                },
              )
                  : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: QueryArtworkWidget(
                    id: s.id,
                    type: ArtworkType.AUDIO,
                    nullArtworkWidget: Container(
                      color: Colors.white10,
                      child: const Icon(Icons.music_note,
                          color: Colors.white70),
                    ),
                  ),
                ),
              ),
              title:
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle:
              Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis),

              // ✅ Added onLongPress for Selection Mode
              onLongPress: () {
                setState(() {
                  _selectMode = true;
                  _selectedSongIds.add(s.id); // Current song auto-select
                });
              },

              onTap: () async {
                if (_selectMode) {
                  setState(() {
                    if (selected) {
                      _selectedSongIds.remove(s.id);
                    } else {
                      _selectedSongIds.add(s.id);
                    }
                  });
                  return;
                }

                if (realIndex < 0) return;

                // ✅ Show interstitial ad
                await InterstitialHelper.instance.tryShow();
                if (!context.mounted) return;

                // ✅ Mini player visible & Play song
                homeMiniVisible.value = true;
                PlayerManager.I.playPlaylist(list, realIndex);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NowPlayingScreen(
                      playlist: list,
                      startIndex: realIndex,
                    ),
                  ),
                );
              },
            ),

            // Divider sirf tab dikhao jab ye aakhri gaana na ho
            if (realIdx != len - 1)
              const Divider(
                height: 1,
                color: Colors.white12,
                indent: 72,
              ),
          ],
        );
      },
    );
  }
}
