part of '../home_screen.dart';

extension _HomeTabArtistsExt on _HomeScreenState {
  Widget _buildArtistsTab() {
    return FutureBuilder<List<ArtistModel>>(
      future: _artistsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final artists = snap.data ?? [];
        _cacheArtists = artists;

        if (artists.isEmpty) {
          return const Center(
            child: Text('No artists found', style: TextStyle(color: Colors.white60)),
          );
        }

        final int len = artists.length;
        final int bannerCount = BannerPlan.bannerCountForItems(len);
        final plan = BannerPlan.build(items: len, banners: bannerCount);

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 92),
          itemCount: plan.totalCount,
          separatorBuilder: (_, i) {
            final bool isCurrentAd = plan.isAdIndex(i);
            final bool isNextAd = plan.isAdIndex(i + 1);

            if (isCurrentAd || isNextAd) {
              return const SizedBox.shrink();
            }

            return const Divider(height: 1, color: Colors.white12);
          },
          itemBuilder: (context, i) {
            final bool isAd = plan.isAdIndex(i);

            if (isAd) {
              return _inlineBanner(
                placement: 'home_artists',
                slot: plan.slotForListIndex(i),
              );
            }

            final int realIdx = plan.dataIndexFromListIndex(i);

            if (realIdx < 0 || realIdx >= artists.length) {
              return const SizedBox.shrink();
            }

            final ar = artists[realIdx];
            final name = ar.artist;

            final selected = _selectedArtistIds.contains(ar.id);

            return ListTile(
              leading: _selectMode
                  ? Checkbox(
                value: selected,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedArtistIds.add(ar.id);
                    } else {
                      _selectedArtistIds.remove(ar.id);
                    } });
                },
              )
                  : const Icon(Icons.person),
              title: Text(ar.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${ar.numberOfTracks ?? 0} songs',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              onTap: () async {
                if (_selectMode) {
                  setState(() {
                    if (selected) {
                      _selectedArtistIds.remove(ar.id);
                    } else {
                      _selectedArtistIds.add(ar.id);
                    }
                  });
                  return;
                }

                final songs = await _songsForArtist(ar);
                if (!context.mounted) return;
                if (songs.isEmpty){
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No songs found in "$name"')),
                  );
                  return;
                }

                homeMiniVisible.value = true;
                await PlayerManager.I.playPlaylist(songs, 0);
                if (!context.mounted) return;
                await InterstitialHelper.instance.tryShow(placement: 'open_artist');
                if (!mounted) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        NowPlayingScreen(playlist: songs, startIndex: 0),
                  ),
                );
              },

              trailing: _selectMode
                  ? null
                  : PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  if (value == 'add_to_playlist') {
                    final songs = await _audioQuery.queryAudiosFrom(
                      AudiosFromType.ARTIST_ID,
                      ar.id,
                    );
                    if (!context.mounted) return;

                    if (songs.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('No songs found for "${ar.artist}".'),
                        ),
                      );
                      return;
                    }

                    _addFolderToPlaylist(ar.artist, songs);
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(
                    value: 'add_to_playlist',
                    child: Text('Add to playlist'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
