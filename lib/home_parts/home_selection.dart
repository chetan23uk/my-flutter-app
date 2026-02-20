part of '../home_screen.dart';



extension _HomeSelectionExt on _HomeScreenState {
  bool get _hasAnySelection =>
      _selectedSongIds.isNotEmpty ||
          _selectedPlaylistNames.isNotEmpty ||
          _selectedFolderPaths.isNotEmpty ||
          _selectedAlbumIds.isNotEmpty ||
          _selectedArtistIds.isNotEmpty ||
          _selectedGenreIds.isNotEmpty;

  void _clearAllSelections() {
    _selectedSongIds.clear();
    _selectedPlaylistNames.clear();
    _selectedFolderPaths.clear();
    _selectedAlbumIds.clear();
    _selectedArtistIds.clear();
    _selectedGenreIds.clear();
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _clearAllSelections();
    });
  }

  // current tab all-selected check
  bool _isAllSelectedForCurrentTab() {
    final tab = tabs[selectedTab];

    if (tab == 'tab_songs') {
      if (_cacheAllSongs.isEmpty) return false;
      return _selectedSongIds.length == _cacheAllSongs.length;
    }
    if (tab == 'tab_for_you') {
      if (_cacheForYouSongs.isEmpty) return false;
      return _selectedSongIds.length == _cacheForYouSongs.length;
    }
    if (tab == 'tab_playlist') {
      if (_cachePlaylistsEntries.isEmpty) return false;
      return _selectedPlaylistNames.length == _cachePlaylistsEntries.length;
    }
    if (tab == 'tab_folders') {
      final visible = _cacheFoldersMap.keys
          .where((path) => !_hiddenFolders.contains(path))
          .toList();
      if (visible.isEmpty) return false;
      return _selectedFolderPaths.length == visible.length;
    }
    if (tab == 'tab_albums') {
      if (_cacheAlbums.isEmpty) return false;
      return _selectedAlbumIds.length == _cacheAlbums.length;
    }
    if (tab == 'tab_artists') {
      if (_cacheArtists.isEmpty) return false;
      return _selectedArtistIds.length == _cacheArtists.length;
    }
    if (tab == 'tab_genres') {
      if (_cacheGenres.isEmpty) return false;
      return _selectedGenreIds.length == _cacheGenres.length;
    }
    return false;
  }

  void _toggleAllForCurrentTab(bool selectAll) {
    final tab = tabs[selectedTab];

    setState(() {
      // Clear only current tab selection set (safe)
      if (tab == 'tab_songs') {
        _selectedSongIds
          ..clear()
          ..addAll(selectAll ? _cacheAllSongs.map((e) => e.id) : []);
      } else if (tab == 'tab_for_you') {
        _selectedSongIds
          ..clear()
          ..addAll(selectAll ? _cacheForYouSongs.map((e) => e.id) : []);
      } else if (tab == 'tab_playlist') {
        _selectedPlaylistNames
          ..clear()
          ..addAll(selectAll ? _cachePlaylistsEntries.map((e) => e.key) : []);
      } else if (tab == 'tab_folders') {
        final visible = _cacheFoldersMap.keys
            .where((path) => !_hiddenFolders.contains(path))
            .toList();
        _selectedFolderPaths
          ..clear()
          ..addAll(selectAll ? visible : []);
      } else if (tab == 'tab_albums') {
        _selectedAlbumIds
          ..clear()
          ..addAll(selectAll ? _cacheAlbums.map((e) => e.id) : []);
      } else if (tab == 'tab_artists') {
        _selectedArtistIds
          ..clear()
          ..addAll(selectAll ? _cacheArtists.map((e) => e.id) : []);
      } else if (tab == 'tab_genres') {
        _selectedGenreIds
          ..clear()
          ..addAll(selectAll ? _cacheGenres.map((e) => e.id) : []);
      }
    });
  }

  int _selectedCountForCurrentTab() {
    final tab = tabs[selectedTab];
    if (tab == 'tab_songs' || tab == 'tab_for_you') return _selectedSongIds.length;
    if (tab == 'tab_playlist') return _selectedPlaylistNames.length;
    if (tab == 'tab_folders') return _selectedFolderPaths.length;
    if (tab == 'tab_albums') return _selectedAlbumIds.length;
    if (tab == 'tab_artists') return _selectedArtistIds.length;
    if (tab == 'tab_genres') return _selectedGenreIds.length;
    return 0;
  }

  Future<void> _deleteSelectedForCurrentTab() async {
    if (!_hasAnySelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing selected')),
      );
      return;
    }

    final tab = tabs[selectedTab];

    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected?'),
        content: Text(
          tab == 'tab_playlist'
              ? 'Selected playlists will be deleted. Songs device se delete nahi honge.'
              : 'Selected items ke songs device se delete ho jayenge. Ye undo nahi hoga.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common_cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common_delete'.tr()),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    bool anyFailed = false;

    try {
      // ✅ PLAYLIST: delete local playlists only
      if (tab == 'tab_playlist') {
        for (final name in _selectedPlaylistNames.toList()) {
          try {
            await LocalPlaylists.instance.deletePlaylist(name);
          } catch (_) {
            anyFailed = true;
          }
        }
      }

      // ✅ FOLDERS: delete songs in folder paths
      else if (tab == 'tab_folders') {
        for (final path in _selectedFolderPaths.toList()) {
          final songs = _cacheFoldersMap[path] ?? const <SongModel>[];
          for (final s in songs) {
            try {
              final f = File(s.data);
              if (await f.exists()) await f.delete();
            } catch (_) {
              anyFailed = true;
            }
          }
        }
      }

      // ✅ SONGS / FOR YOU: delete selected songs
      else if (tab == 'tab_songs' || tab == 'tab_for_you') {
        // pick from cache (allSongs is safer)
        final base =
        _cacheAllSongs.isNotEmpty ? _cacheAllSongs : await _getAllSongsSafe();
        final selectedSongs =
        base.where((s) => _selectedSongIds.contains(s.id)).toList();

        for (final s in selectedSongs) {
          try {
            final f = File(s.data);
            if (await f.exists()) await f.delete();
          } catch (_) {
            anyFailed = true;
          }
        }
      }

      // ✅ ALBUMS: delete all songs for selected albums
      else if (tab == 'tab_albums') {
        for (final al in _cacheAlbums.where((a) => _selectedAlbumIds.contains(a.id))) {
          final songs = await _songsForAlbum(al);
          for (final s in songs) {
            try {
              final f = File(s.data);
              if (await f.exists()) await f.delete();
            } catch (_) {
              anyFailed = true;
            }
          }
        }
      }

      // ✅ ARTISTS: delete all songs for selected artists
      else if (tab == 'tab_artists') {
        for (final ar
        in _cacheArtists.where((a) => _selectedArtistIds.contains(a.id))) {
          final songs =
          await _audioQuery.queryAudiosFrom(AudiosFromType.ARTIST_ID, ar.id);
          for (final s in songs) {
            try {
              final f = File(s.data);
              if (await f.exists()) await f.delete();
            } catch (_) {
              anyFailed = true;
            }
          }
        }
      }

      // ✅ GENRES: delete all songs for selected genres
      else if (tab == 'tab_genres') {
        for (final g in _cacheGenres.where((x) => _selectedGenreIds.contains(x.id))) {
          final songs =
          await _audioQuery.queryAudiosFrom(AudiosFromType.GENRE_ID, g.id);
          for (final s in songs) {
            try {
              final f = File(s.data);
              if (await f.exists()) await f.delete();
            } catch (_) {
              anyFailed = true;
            }
          }
        }
      }
    } catch (_) {
      anyFailed = true;
    }

    if (!mounted) return;

    // reload library after delete
    await _initPermissionsAndLoad();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          anyFailed ? 'Some files could not be deleted.' : 'Deleted successfully.',
        ),
      ),
    );

    _exitSelectMode();
  }

  // ✅ UI bar under tabs: Select / All Select + Delete
  Widget _buildAllSelectBar() {
    if (!_selectMode) return const SizedBox.shrink(); // ✅ long press ke baad hi show hoga

    final selectedCount = _selectedCountForCurrentTab();
    final allSelected = _isAllSelectedForCurrentTab();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Checkbox(
            value: allSelected,
            onChanged: (v) => _toggleAllForCurrentTab(v == true),
          ),
          const Text('All Select'),
          const SizedBox(width: 10),
          Text(
            '$selectedCount selected',
            style: const TextStyle(color: Colors.white70),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Delete selected',
            onPressed: selectedCount == 0 ? null : _deleteSelectedForCurrentTab,
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            tooltip: 'Cancel',
            onPressed: _exitSelectMode,
            icon: const Icon(Icons.close),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
