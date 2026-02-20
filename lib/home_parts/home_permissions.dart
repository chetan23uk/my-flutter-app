part of '../home_screen.dart';


extension _HomePermissionsExt on _HomeScreenState {
  // ---------------- RUNTIME PERMISSION HELPER ----------------
  Future<bool> ensureAudioPermission() async {
    if (await Permission.audio.isGranted || await Permission.storage.isGranted) {
      return true;
    }

    final results = await [
      Permission.audio, // API 33+
      Permission.storage, // API <=32
    ].request();

    final granted =
        results[Permission.audio]?.isGranted == true ||
            results[Permission.storage]?.isGranted == true;

    if (granted) return true;

    if ((await Permission.audio.isPermanentlyDenied) ||
        (await Permission.storage.isPermanentlyDenied)) {
      await openAppSettings();
    }
    return false;
  }

  Future<void> _initPermissionsAndLoad() async {
    final ok = await ensureAudioPermission();
    if (!mounted) return;

    setState(() {
      _hasPermission = ok;

      if (ok) {
        _foldersFuture = _lib.fetchFolders();

        _allSongsFuture = _audioQuery.querySongs(
          sortType: SongSortType.TITLE,
          orderType: OrderType.ASC_OR_SMALLER,
          uriType: UriType.EXTERNAL,
        );

        _albumsFuture = _audioQuery.queryAlbums(
          sortType: AlbumSortType.ALBUM,
          orderType: OrderType.ASC_OR_SMALLER,
        );

        _artistsFuture = _audioQuery.queryArtists(
          sortType: ArtistSortType.ARTIST,
          orderType: OrderType.ASC_OR_SMALLER,
        );

        _genresFuture = _audioQuery.queryGenres(
          sortType: GenreSortType.GENRE,
          orderType: OrderType.ASC_OR_SMALLER,
        );
      } else {
        _foldersFuture = null;
        _allSongsFuture = null;
        _albumsFuture = null;
        _artistsFuture = null;
        _genresFuture = null;
      }
    });
  }

  // Permission gate UI
  Widget _buildPermissionGate() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.library_music_outlined,
                size: 56, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              'perm_audio_needed'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _initPermissionsAndLoad,
              icon: const Icon(Icons.lock_open),
              label: Text('perm_allow_audio'.tr()),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async => openAppSettings(),
              child: Text('perm_open_settings'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
