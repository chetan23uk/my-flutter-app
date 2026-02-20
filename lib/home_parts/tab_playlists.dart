part of '../home_screen.dart';

extension _HomeTabPlaylistsExt on _HomeScreenState {
  // ✅ Main Playlist Tab UI
  Widget _buildPlaylistsTab() {
    final future = _playlistsFuture;

    if (future == null) {
      return Center(child: Text('home_loading'.tr()));
    }

    return FutureBuilder<List<PlaylistModel>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'home_library_failed'.tr(),
              textAlign: TextAlign.center,
            ),
          );
        }

        final list = snapshot.data ?? <PlaylistModel>[];
        // ✅ Fix: Home Screen ke cache ko update karna taaki "Select All" chale
        _cachePlaylistModels = list;

        final int len = list.length;
        final int bannerCount = BannerPlan.bannerCountForItems(len);
        final plan = BannerPlan.build(items: len, banners: bannerCount);

        return ListView.builder(
          itemCount: plan.totalCount + 1, // +1 for "Create New" button
          itemBuilder: (context, i) {
            // 1. Pehla item hamesha "Create New Playlist" button hoga
            if (i == 0) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.2),
                  child: Icon(Icons.add,
                      color: Theme.of(context).colorScheme.primary),
                ),
                title: Text('create_playlist'.tr()),
                onTap: _showCreatePlaylistDialog,
              );
            }

            // Ads Logic (Adjusted index because of Create button)
            final int listIndex = i - 1;

            if (plan.isAdIndex(listIndex)) {
              return _inlineBanner(
                placement: 'home_playlists',
                slot: plan.slotForListIndex(listIndex),
              );
            }

            int index = plan.dataIndexFromListIndex(listIndex);
            if (index < 0 || index >= list.length) {
              return const SizedBox.shrink();
            }

            final pl = list[index];
            final name = pl.playlist;
            final selected = _selectedPlaylistNames.contains(name);

            return ListTile(
              leading: Icon(
                Icons.queue_music,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white70,
              ),
              title: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${pl.numOfSongs} ${'songs'.tr()}',
              ),
              onLongPress: () {
                setState(() {
                  _selectMode = true;
                  _selectedPlaylistNames.add(name);
                });
              },
              onTap: () async {
                if (_selectMode) {
                  _togglePlaylistSelection(name, !selected);
                  return;
                }

                homeMiniVisible.value = true;
                await InterstitialHelper.instance.tryShow(placement: 'open_playlist');
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlaylistDetailScreen(playlist: pl),
                  ),
                );
              },
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'delete') {
                    final ok = await _showDeleteConfirm();
                    if (!ok) return;
                    await _audioQuery.removePlaylist(pl.id);
                    _initPermissionsAndLoad();
                  } else if (v == 'rename') {
                    _showRenameDialog(pl);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'rename', child: Text('common_rename'.tr())),
                  PopupMenuItem(value: 'delete', child: Text('common_delete'.tr())),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // =========================
  // ✅ PLAYLIST FUNCTIONS
  // =========================

  // ✅ Helper: selection toggle (same behavior, bas reusable bana diya)
  void _togglePlaylistSelection(String name, bool shouldSelect) {
    setState(() {
      if (shouldSelect) {
        _selectedPlaylistNames.add(name);
        _selectMode = true;
      } else {
        _selectedPlaylistNames.remove(name);
        if (_selectedPlaylistNames.isEmpty) {
          _exitSelectMode();
        }
      }
    });
  }

  Future<bool> _showDeleteConfirm() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('common_delete'.tr()),
        content: Text('playlist_delete_confirm'.tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common_cancel'.tr())),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('common_delete'.tr())),
        ],
      ),
    );
    return res == true;
  }

  // 1. Create Playlist Dialog
  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('common_cancel'.tr())),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              await _audioQuery.createPlaylist(name);
              Navigator.pop(ctx);
              _initPermissionsAndLoad(); // refresh
            },
            child: Text('common_create'.tr()),
          ),
        ],
      ),
    );
  }

  // 2. Rename Playlist Dialog
  void _showRenameDialog(PlaylistModel pl) {
    final controller = TextEditingController(text: pl.playlist);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Playlist'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('common_cancel'.tr())),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                // on_audio_query me rename functionality direct nahi hai toh hum use plugin update ya local logic se handle karte hain
                // Example using ID if supported:
                // await _audioQuery.renamePlaylist(pl.id, controller.text.trim());
                Navigator.pop(ctx);
                _initPermissionsAndLoad();
              }
            },
            child: Text('common_rename'.tr()),
          ),
        ],
      ),
    );
  }
}
