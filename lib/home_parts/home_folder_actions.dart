part of '../home_screen.dart';

extension _HomeFolderActionsExt on _HomeScreenState {
  // ---------------- FOLDER MENU ACTIONS ----------------
  void _onFolderMenuAction(
      String name,
      String folderPath,
      List<SongModel> songs,
      FolderMenu action,
      ) {
    switch (action) {
      case FolderMenu.play:
        _playFolderNow(name, songs);
        break;
      case FolderMenu.playNext:
        _playFolderNext(name, songs);
        break;
      case FolderMenu.addToQueue:
        _addFolderToQueue(name, songs);
        break;
      case FolderMenu.addToPlaylist:
        _addFolderToPlaylist(name, songs);
        break;
      case FolderMenu.hide:
        _hideFolder(name, folderPath);
        break;
      case FolderMenu.deleteFromDevice:
        _deleteFolderFromDevice(name, folderPath, songs);
        break;
    }
  }

  // 🔹 Play – folder turant se play hoga
  void _playFolderNow(String folderName, List<SongModel> songs) async {
    if (songs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This folder has no songs.')),
      );
      return;
    }

    homeMiniVisible.value = true;
    PlayerManager.I.playPlaylist(songs, 0);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NowPlayingScreen(playlist: songs, startIndex: 0),
      ),
    );
  }

  // 🔹 Play next – current song ke turant baad ye folder ke songs
  void _playFolderNext(String folderName, List<SongModel> songs) async {
    if (songs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This folder has no songs.')),
      );
      return;
    }

    final currentList = PlayerManager.I.currentPlaylist();
    if (currentList.isEmpty) {
      _playFolderNow(folderName, songs);
      return;
    }

    final player = PlayerManager.I.player;
    final currentIndex = player.currentIndex ?? -1;

    final list = List<SongModel>.from(currentList);
    final insertIndex =
    (currentIndex < 0 || currentIndex >= list.length) ? list.length : currentIndex + 1;

    list.insertAll(insertIndex, songs);

    homeMiniVisible.value = true;
    PlayerManager.I.playPlaylist(list, currentIndex < 0 ? 0 : currentIndex);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Folder "$folderName" will play next.')),
    );
  }

  // 🔹 Add to queue – current queue ke end me pura folder
  void _addFolderToQueue(String folderName, List<SongModel> songs) async {
    if (songs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This folder has no songs.')),
      );
      return;
    }

    final currentList = PlayerManager.I.currentPlaylist();
    if (currentList.isEmpty) {
      _playFolderNow(folderName, songs);
      return;
    }

    final player = PlayerManager.I.player;
    final currentIndex = player.currentIndex ?? -1;

    final list = List<SongModel>.from(currentList)..addAll(songs);

    homeMiniVisible.value = true;
    PlayerManager.I.playPlaylist(list, currentIndex < 0 ? 0 : currentIndex);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Folder "$folderName" added to queue.')),
    );
  }

  // ---------------- ADD FOLDER TO LOCAL PLAYLIST ----------------
  Future<void> _addFolderToPlaylist(String folderName, List<SongModel> songs) async {
    if (songs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This folder has no songs.')),
      );
      return;
    }

    try {
      final data = await LocalPlaylists.instance.getAll();

      if (!mounted) return;

      if (data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('home_no_playlists'.tr())),
        );
        return;
      }

      final names = data.keys.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

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
                  title: Text('Select playlist', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const Divider(height: 1),
                for (final name in names)
                  ListTile(
                    title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.pop(ctx, name),
                  ),
              ],
            ),
          );
        },
      );

      if (selectedName == null) return;

      final ids = songs.map((s) => s.id).toList();
      final added = await LocalPlaylists.instance.addSongs(selectedName, ids);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $added song(s) from "$folderName" to "$selectedName".'),
        ),
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding folder to playlist: $e')),
      );
    }
  }

  // 🔹 Hide – sirf UI se hata dete hain (app restart tak)
  void _hideFolder(String folderName, String folderPath) {
    setState(() {
      _hiddenFolders.add(folderPath);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Folder "$folderName" hidden.')),
    );
  }

  // 🔹 Unhide – hidden list se wapas lao
  void _unhideFolder(String folderName, String folderPath) {
    setState(() {
      _hiddenFolders.remove(folderPath);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Folder "$folderName" unhidden.')),
    );
  }

  // 🔹 Delete from device – file system se delete karne ki try
  void _deleteFolderFromDevice(
      String folderName,
      String folderPath,
      List<SongModel> songs,
      ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text(
          'All audio files in "$folderName" will be deleted from your device. This action cannot be undone.',
        ),
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

    // ✅ collect content:// uris
    final uris = songs.map((s) => s.uri).whereType<String>().toList();

    final ok = await MediaDeleteService.deleteUris(uris);

    // Android 9 fallback: native returns false, so try File.delete (best effort)
    bool anyFailed = false;

    if (!ok) {
      for (final song in songs) {
        try {
          final file = File(song.data);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {
          anyFailed = true;
        }
      }
    } else {
      anyFailed = false;
    }

    await _initPermissionsAndLoad();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok && !anyFailed
              ? 'Deleted "$folderName"'
              : (ok ? 'Some files could not be deleted' : 'Delete cancelled or failed'),
        ),
      ),
    );
  }
}
