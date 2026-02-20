part of '../home_screen.dart';

extension _HomeTabAlbumsExt on _HomeScreenState {
  Widget _buildAlbumsTab() {
    return FutureBuilder<List<AlbumModel>>(
      future: _albumsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final albums = snap.data ?? [];
        _cacheAlbums = albums;

        if (albums.isEmpty) {
          return const Center(
            child: Text(
              'No albums found',
              style: TextStyle(color: Colors.white60),
            ),
          );
        }

        final int len = albums.length;
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
                placement: 'home_albums',
                slot: plan.slotForListIndex(i),
              );
            }

            final int realIdx = plan.dataIndexFromListIndex(i);

            if (realIdx < 0 || realIdx >= albums.length) {
              return const SizedBox.shrink();
            }

            final al = albums[realIdx];
            final name = al.album;
            final artist = al.artist ?? 'Unknown artist';
            final count = al.numOfSongs;

            final selected = _selectedAlbumIds.contains(al.id);

            return ListTile(
              leading: _selectMode
                  ? Checkbox(
                value: selected,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedAlbumIds.add(al.id);
                    } else {
                      _selectedAlbumIds.remove(al.id);
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
                    id: al.id,
                    type: ArtworkType.ALBUM,
                    nullArtworkWidget: Container(
                      color: Colors.white10,
                      child:
                      const Icon(Icons.album, color: Colors.white70),
                    ),
                  ),
                ),
              ),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '$artist • $count songs',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onLongPress: () {
                setState(() {
                  _selectMode = true;
                  _selectedAlbumIds.add(al.id);
                });
              },
              onTap: () async {
                if (_selectMode) {
                  setState(() {
                    if (selected) {
                      _selectedAlbumIds.remove(al.id);
                      if (_selectedAlbumIds.isEmpty) {
                        _exitSelectMode();
                      }
                    } else {
                      _selectedAlbumIds.add(al.id);
                    }
                  });
                  return;
                }

                final songs = await _songsForAlbum(al);
                if (!context.mounted) return;

                if (songs.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No songs found in "$name"')),
                  );
                  return;
                }

                homeMiniVisible.value = true;
                await PlayerManager.I.playPlaylist(songs, 0);
                if (!context.mounted) return;
                await InterstitialHelper.instance.tryShow(placement: 'open_album');
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
                    final songs = await _songsForAlbum(al);
                    if (!context.mounted) return;

                    if (songs.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('No songs found in "$name"')),
                      );
                      return;
                    }

                    _addFolderToPlaylist(name, songs);
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
