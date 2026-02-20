part of '../home_screen.dart';

extension _HomeTabSongsExt on _HomeScreenState {
  Future<void> _deleteSongFromDevice(SongModel song) async {
    final title = _cleanTitle(song);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete song?'),
        content: Text('"$title" will be deleted from your device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final uri = song.uri;
    bool ok = false;

    // ✅ Play-safe delete via URI (Android 10/11+)
    if (uri != null && uri.isNotEmpty) {
      ok = await MediaDeleteService.deleteUris([uri]);
    }

    // ✅ Android 9 fallback (or when native returns false)
    if (!ok) {
      try {
        final f = File(song.data);
        if (await f.exists()) {
          await f.delete();
          ok = true;
        }
      } catch (_) {}
    }

    if (!mounted) return;

    await _initPermissionsAndLoad(); // refresh UI

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Song deleted' : 'Delete cancelled or failed')),
    );
  }

  Widget _buildSongsTab() {
    return FutureBuilder<List<SongModel>>(
      future: _allSongsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final songs = snap.data ?? [];
        _cacheAllSongs = songs;

        if (songs.isEmpty) {
          return Center(
            child: Text(
              'home_no_songs'.tr(),
              style: const TextStyle(color: Colors.white60),
            ),
          );
        }

        final int bannerCount = BannerPlan.bannerCountForItems(songs.length);
        final plan = BannerPlan.build(items: songs.length, banners: bannerCount);

        return Stack(
          children: [
            // ✅ Gray press effect ON, ripple OFF (no circle)
            Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent, // ripple hide
                splashFactory: NoSplash.splashFactory, // no ripple animation
                // ✅ THIS is the main fix: pressed/highlight gray effect
                highlightColor: Colors.white.withValues(alpha: 0.10),
                hoverColor: Colors.white.withValues(alpha: 0.04),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 92),
                itemCount: plan.totalCount,
                itemBuilder: (context, index) {
                  final isAd = plan.isAdIndex(index);
                  if (isAd) {
                    // ✅ ADS untouched (same as your code)
                    return _inlineBanner(
                      placement: 'home_songs',
                      slot: plan.slotForListIndex(index),
                    );
                  }

                  final i = plan.dataIndexFromListIndex(index);

                  final s = songs[i];
                  final title = _cleanTitle(s);
                  final artist = _artistOf(s);
                  final dur = _fmtDur(s.duration);

                  final selected = _selectedSongIds.contains(s.id);

                  return Column(
                    children: [
                      ListTile(
                        // ✅ makes highlight look like “tile area” (around widget)
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),

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
                                child: const Icon(
                                  Icons.music_note,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // ✅ Long Press to enable selection mode
                        onLongPress: () {
                          setState(() {
                            _selectMode = true;
                            _selectedSongIds.add(s.id);
                          });
                        },

                        // 🔹 duration + 3-dot menu ek hi row me
                        trailing: _selectMode
                            ? Text(
                          dur,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        )
                            : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              dur,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) async {
                                if (value == 'add_to_playlist') {
                                  await _addSongToPlaylist(s);
                                } else if (value == 'delete_from_device') {
                                  await _deleteSongFromDevice(s);
                                }
                              },
                              itemBuilder: (ctx) => const [
                                PopupMenuItem(
                                  value: 'add_to_playlist',
                                  child: Text('Add to playlist'),
                                ),
                                PopupMenuItem(
                                  value: 'delete_from_device',
                                  child: Text('Delete from device'),
                                ),
                              ],
                            ),
                          ],
                        ),

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

                          try {
                            homeMiniVisible.value = true;

                            // ✅ actual play (may take time)
                            PlayerManager.I.playPlaylist(songs, i);

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NowPlayingScreen(
                                  playlist: songs,
                                  startIndex: i,
                                ),
                              ),
                            );

                            Future<void>.delayed(
                              const Duration(milliseconds: 260),
                            );
                          } catch (_) {}
                        },
                      ),
                      if (i != songs.length - 1)
                        const Divider(
                          height: 1,
                          color: Colors.white12,
                          indent: 72,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------- ADD SONG TO LOCAL PLAYLIST (from Songs tab) ----------------
  Future<void> _addSongToPlaylist(SongModel song) async {
    try {
      final idNames = await LocalPlaylists.instance.getNames();
      final fileNames = await LocalPlaylists.instance.getFilePlaylistNames();

      if (!mounted) return;

      final names = <String>[...idNames, ...fileNames];

      if (names.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('home_no_playlists'.tr())),
        );
        return;
      }

      final selectedName = await showModalBottomSheet<String>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(
                  title: Text(
                    'Select playlist',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Divider(height: 1),
                for (final name in names)
                  ListTile(
                    title: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.pop(ctx, name),
                  ),
              ],
            ),
          );
        },
      );

      if (selectedName == null) return;

      final filePaths =
      await LocalPlaylists.instance.getFilePlaylistPaths(selectedName);

      if (filePaths.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transferred playlist me naye songs add nahi ho sakte.'),
          ),
        );
        return;

      }

      await LocalPlaylists.instance.addSong(selectedName, song.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Song added to "$selectedName".')),
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding to playlist: $e')),
      );
    }
  }
}
