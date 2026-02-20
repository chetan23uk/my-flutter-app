part of '../home_screen.dart';

extension _HomeTabGenresExt on _HomeScreenState {
  Widget _buildGenresTab() {
    return FutureBuilder<List<GenreModel>>(
      future: _genresFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final genres = snap.data ?? [];
        _cacheGenres = genres;

        if (genres.isEmpty) {
          return const Center(
            child: Text('No genres found', style: TextStyle(color: Colors.white60)),
          );
        }

        final int len = genres.length;
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
                placement: 'home_genres',
                slot: plan.slotForListIndex(i),
              );
            }

            final int realIdx = plan.dataIndexFromListIndex(i);

            if (realIdx < 0 || realIdx >= genres.length) {
              return const SizedBox.shrink();
            }

            final g = genres[realIdx];
            final name = g.genre;

            final selected = _selectedGenreIds.contains(g.id);

            return ListTile(
              leading: _selectMode
                  ? Checkbox(
                value: selected,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedGenreIds.add(g.id);
                    } else {
                      _selectedGenreIds.remove(g.id);
                    }
                  });
                },
              )
                  : const Icon(Icons.local_offer),
              title: Text(
                g.genre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${g.numOfSongs} songs',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onLongPress: () {
                setState(() {
                  _selectMode = true;
                  _selectedGenreIds.add(g.id);
                });
              },
              onTap: () async {
                if (_selectMode) {
                  setState(() {
                    if (selected) {
                      _selectedGenreIds.remove(g.id);
                      if (_selectedGenreIds.isEmpty) {
                        _exitSelectMode();
                      }
                    } else {
                      _selectedGenreIds.add(g.id);
                    }
                  });
                  return;
                }

                final songs = await _songsForGenre(g);
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
                await InterstitialHelper.instance.tryShow(placement: 'open_genre');
                if (!mounted) return;

                Navigator.push(
                  (context),
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
                      AudiosFromType.GENRE_ID,
                      g.id,
                    );
                    if (!context.mounted) return;

                    if (songs.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('No songs found for "${g.genre}".'),
                        ),
                      );
                      return;
                    }

                    _addFolderToPlaylist(g.genre, songs);
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
