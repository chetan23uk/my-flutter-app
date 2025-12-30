// lib/home_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:youplay_music/services/media_delete.dart';
import 'ads/banner_ad_widget.dart';
import 'ads/ad_ids.dart';

import 'ads/interstitial_helper.dart';
import 'folder_detail_screen.dart';
import 'folder_tite.dart';
import 'services/local_playlists.dart';
import 'services/media_library.dart';
import 'now_playing_screen.dart';
import 'playing_manager.dart';
import 'settings_screen.dart';

enum _SearchMode { folders, songs, albums, artists, playlists, others }

// ✅ Home mini-player show / hide ke liye notifier
final ValueNotifier<bool> homeMiniVisible = ValueNotifier<bool>(true);

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Tabs ke liye localization keys
  final tabs = const [
    'tab_for_you',
    'tab_songs',
    'tab_playlist',
    'tab_folders',
    'tab_albums',
    'tab_artists',
    'tab_genres',
  ];

  int selectedTab = 3; // default to "Folders"

  // audio query + permission state
  final OnAudioQuery _audioQuery = OnAudioQuery();
  bool _hasPermission = false;

  // service & folders future
  final _lib = MediaLibraryService();
  Future<Map<String, List<SongModel>>>? _foldersFuture;

  // library futures (songs/albums/artists/genres/playlists)
  Future<List<SongModel>>? _allSongsFuture;
  Future<List<AlbumModel>>? _albumsFuture;
  Future<List<ArtistModel>>? _artistsFuture;
  Future<List<GenreModel>>? _genresFuture;

  // =========================
  // ✅ ADS SETTINGS
  // =========================
  static const int _kInlineAdEvery = 7; // every 7 items

  Widget _inlineBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Center(
        child: BannerAdWidget(
          adUnitId: AdIds.banner,
          size: AdSize.banner,
        ),
      ),
    );
  }


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


  // Hidden folders (by path)
  final Set<String> _hiddenFolders = <String>{};

  // =========================
  // ✅ MULTI SELECT STATE
  // =========================
  bool _selectMode = false;

  // selection sets
  final Set<int> _selectedSongIds = {};
  final Set<String> _selectedPlaylistNames = {};
  final Set<String> _selectedFolderPaths = {};
  final Set<int> _selectedAlbumIds = {};
  final Set<int> _selectedArtistIds = {};
  final Set<int> _selectedGenreIds = {};

  // caches (for all-select)
  List<SongModel> _cacheAllSongs = [];
  List<SongModel> _cacheForYouSongs = [];
  List<AlbumModel> _cacheAlbums = [];
  List<ArtistModel> _cacheArtists = [];
  List<GenreModel> _cacheGenres = [];
  Map<String, List<SongModel>> _cacheFoldersMap = {};
  List<MapEntry<String, List<int>>> _cachePlaylistsEntries = [];

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

  void _enterSelectMode() {
    setState(() {
      _selectMode = true;
      // keep current selections as-is (generally empty)
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
        final base = _cacheAllSongs.isNotEmpty ? _cacheAllSongs : await _getAllSongsSafe();
        final selectedSongs = base.where((s) => _selectedSongIds.contains(s.id)).toList();
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
        for (final ar in _cacheArtists.where((a) => _selectedArtistIds.contains(a.id))) {
          final songs = await _audioQuery.queryAudiosFrom(AudiosFromType.ARTIST_ID, ar.id);
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
          final songs = await _audioQuery.queryAudiosFrom(AudiosFromType.GENRE_ID, g.id);
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

  // ---------------- RUNTIME PERMISSION HELPER ----------------
  Future<bool> ensureAudioPermission() async {
    if (await Permission.audio.isGranted || await Permission.storage.isGranted) {
      return true;
    }
    final results = await [
      Permission.audio, // API 33+
      Permission.storage, // API <=32
    ].request();

    final granted = results[Permission.audio]?.isGranted == true ||
        results[Permission.storage]?.isGranted == true;

    if (granted) return true;

    if ((await Permission.audio.isPermanentlyDenied) ||
        (await Permission.storage.isPermanentlyDenied)) {
      await openAppSettings();
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _initPermissionsAndLoad();
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

  // ---------------- Open Search (context-aware) ----------------
  void _openSearch() async {
    if (_foldersFuture == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('home_library_not_loaded'.tr()),
        ),
      );
      return;
    }

    // Await the foldersFuture if not ready
    final Map<String, List<SongModel>> folders;
    try {
      folders = await _foldersFuture!;
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('home_library_failed'.tr())),
      );
      return;
    }

    // Determine mode based on selectedTab
    final tab = tabs[selectedTab];
    _SearchMode mode;
    if (tab == 'tab_folders') {
      mode = _SearchMode.folders;
    } else if (tab == 'tab_songs') {
      mode = _SearchMode.songs;
    } else if (tab == 'tab_albums') {
      mode = _SearchMode.albums;
    } else if (tab == 'tab_artists') {
      mode = _SearchMode.artists;
    } else if (tab == 'tab_playlist') {
      mode = _SearchMode.playlists;
    } else {
      mode = _SearchMode.others;
    }

    // Flatten songs
    final List<SongModel> allSongs = folders.values.expand((e) => e).toList();

    // Build album map and artist map
    final Map<String, List<SongModel>> albums = {};
    final Map<String, List<SongModel>> artists = {};
    for (final s in allSongs) {
      final album = (s.album ?? '').isEmpty ? '<unknown album>' : s.album!;
      albums.putIfAbsent(album, () => []).add(s);

      final artist = (s.artist ?? '').isEmpty ? '<unknown artist>' : s.artist!;
      artists.putIfAbsent(artist, () => []).add(s);
    }

    // Build folders entries list
    final List<_FolderEntry> folderEntries = folders.entries
        .map((e) => _FolderEntry(name: p.basename(e.key), path: e.key, songs: e.value))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // Push search screen with proper data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SearchScreen(
          mode: mode,
          allSongs: allSongs,
          folderEntries: folderEntries,
          albumsMap: albums,
          artistsMap: artists,
        ),
      ),
    );
  }

  // ✅ UI bar under tabs: Select / All Select + Delete
  Widget _buildAllSelectBar() {
    final selectedCount = _selectedCountForCurrentTab();
    final allSelected = _isAllSelectedForCurrentTab();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          if (!_selectMode) ...[
            TextButton.icon(
              onPressed: _enterSelectMode,
              icon: const Icon(Icons.checklist, size: 18),
              label: const Text('Select'),
            ),
            const Spacer(),
            Text(
              '0 selected',
              style: const TextStyle(color: Colors.white60),
            ),
          ] else ...[
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
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabKey = tabs[selectedTab];

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Top app name + actions row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      RichText(
                        text: TextSpan(
                          text: 'MUSIC ',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                          children: [
                            const TextSpan(
                              text: 'PLAYER',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _openSearch,
                      ),
                      IconButton(
                        icon: const Icon(Icons.play_circle_outline),
                        onPressed: () {
                          final pl = PlayerManager.I.currentPlaylist();
                          final currentIndex = PlayerManager.I.player.currentIndex ?? 0;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NowPlayingScreen(
                                playlist: pl.isEmpty ? null : pl,
                                startIndex: pl.isEmpty ? 0 : currentIndex,
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Horizontal tabs
                SizedBox(
                  height: 46,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final isSelected = index == selectedTab;
                      return ChoiceChip(
                        selected: isSelected,
                        label: Text(tabs[index].tr()),
                        onSelected: (_) {
                          setState(() => selectedTab = index);
                          // tab switch → select mode off (safe UX)
                          _exitSelectMode();
                        },
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white24,
                          ),
                        ),
                        selectedColor: Colors.white12,
                        labelStyle: TextStyle(
                          color: Colors.white.withValues(
                            alpha: isSelected ? 1.0 : 0.9,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: Colors.white10,
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemCount: tabs.length,
                  ),
                ),

                const SizedBox(height: 8),

                // ✅ All Select bar (green line wali jagah)
                _buildAllSelectBar(),

                // Content + MiniPlayer
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: !_hasPermission ? _buildPermissionGate() : _buildTabContent(tabKey),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: homeMiniVisible,
                        builder: (context, visible, _) {
                          if (!visible) return const SizedBox.shrink();
                          return const HomeMiniPlayer();
                        },
                      ),
                    ],
                  ),
                ),
              ],

            ),

          ),
        ],
      ),
    );
  }

  // ---------------- TAB CONTENT BUILDERS ----------------

  Widget _buildTabContent(String tabKey) {
    switch (tabKey) {
      case 'tab_for_you':
        return _buildForYou();
      case 'tab_songs':
        return _buildSongsTab();
      case 'tab_playlist':
        return _buildPlaylistsTab();
      case 'tab_folders':
        return _buildFolders();
      case 'tab_albums':
        return _buildAlbumsTab();
      case 'tab_artists':
        return _buildArtistsTab();
      case 'tab_genres':
        return _buildGenresTab();
      default:
        return const SizedBox.shrink();
    }
  }

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
    const int k = 7; // Har 7 items ke baad ad

    // 1 se 6 gaane hone par end mein 1 ad dikhane ke liye
    final bool showSingleAd = len > 0 && len < k;
    final int adCount = (len >= k) ? (len ~/ k) : (showSingleAd ? 1 : 0);
    final int totalCount = len + adCount;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 92),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        // ✅ AD LOGIC: Har 7 ke baad YA 1-6 songs hone par last item
        final bool isAd = (len >= k)
            ? ((index + 1) % (k + 1) == 0)
            : (showSingleAd && index == totalCount - 1);

        if (isAd) {
          return _inlineBanner(); // Aapka banner widget
        }

        // ✅ REAL INDEX CALCULATION
        final int adsBefore = (len >= k) ? ((index + 1) ~/ (k + 1)) : 0;
        final int realIdx = index - adsBefore;

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
                      child: const Icon(
                          Icons.music_note, color: Colors.white70),
                    ),
                  ),
                ),
              ),
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                  artist, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                    builder: (_) =>
                        NowPlayingScreen(
                          playlist: list,
                          startIndex: realIndex,
                        ),
                  ),
                );
              },
            ),
            // Divider sirf tab dikhao jab ye aakhri gaana na ho
            if (realIdx != len - 1)
              const Divider(height: 1, color: Colors.white12, indent: 72),
          ],
        );
      },
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

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 92),
          itemCount: songs.length + (songs.length ~/ _kInlineAdEvery),
          itemBuilder: (context, index) {
            final isAd = (index + 1) % (_kInlineAdEvery + 1) == 0;
            if (isAd) {
              return _inlineBanner();
            }

            final adsBefore = (index + 1) ~/ (_kInlineAdEvery + 1);
            final i = index - adsBefore;

            final s = songs[i];
            final title = _cleanTitle(s);
            final artist = _artistOf(s);
            final dur = _fmtDur(s.duration);

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
                          child: const Icon(Icons.music_note, color: Colors.white70),
                        ),
                      ),
                    ),
                  ),
                  title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis),

                  // 🔹 duration + 3-dot menu ek hi row me
                  trailing: _selectMode
                      ? Text(
                    dur,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
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
                            _addSongToPlaylist(s);
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

                  onTap: () {
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
                    homeMiniVisible.value = true;
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
                  },
                ),
                if (i != songs.length - 1) const Divider(height: 1, color: Colors.white12, indent: 72),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPlaylistsTab() {
    return FutureBuilder<_PlaylistsBundle>(
      future: _loadAllPlaylistsBundle(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final bundle = snap.data ??
            _PlaylistsBundle(idPlaylists: {}, filePlaylists: {});

        final idEntries = bundle.idPlaylists.entries.toList()
          ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

        final fileEntries = bundle.filePlaylists.entries.toList()
          ..sort((a, b) => b.key.toLowerCase().compareTo(a.key.toLowerCase())); // latest first

        // ✅ cache for all-select (ONLY normal playlists)
        _cachePlaylistsEntries = idEntries;

        if (idEntries.isEmpty && fileEntries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'home_no_playlists'.tr(),
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  'no_playlists_subtitle'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showCreatePlaylistDialog,
                  icon: const Icon(Icons.playlist_add),
                  label: Text('create_new_playlist'.tr()),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${idEntries.length + fileEntries.length} ${'home_playlists_label'.tr()}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.playlist_add),
                    onPressed: _showCreatePlaylistDialog,
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 92),
                children: [
                  // ---------------- Normal playlists ----------------
                  if (idEntries.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
                      child: Text(
                        'Your Playlists',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ...idEntries.map((entry) {
                      final name = entry.key;
                      final songIds = entry.value;
                      final count = songIds.length;
                      final selected = _selectedPlaylistNames.contains(name);

                      return Column(
                        children: [
                          ListTile(
                            leading: _selectMode
                                ? Checkbox(
                              value: selected,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedPlaylistNames.add(name);
                                  } else {
                                    _selectedPlaylistNames.remove(name);
                                  }
                                });
                              },
                            )
                                : const Icon(Icons.queue_music_rounded),
                            title: Text(name,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('$count songs',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () async {
                              if (_selectMode) {
                                setState(() {
                                  if (selected) {
                                    _selectedPlaylistNames.remove(name);
                                  } else {
                                    _selectedPlaylistNames.add(name);
                                  }
                                });
                                return;
                              }

                              if (_allSongsFuture == null) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('home_library_not_loaded'.tr())),
                                );
                                return;
                              }

                              final allSongs = await _allSongsFuture!;
                              final songs = allSongs
                                  .where((s) => songIds.contains(s.id))
                                  .toList();

                              if (songs.isEmpty) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'home_playlist_empty'.tr(args: [name]))),
                                );
                                return;
                              }

                              homeMiniVisible.value = true;
                              PlayerManager.I.playPlaylist(songs, 0);

                              if (!mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _SongListScreen(
                                    title: name,
                                    songs: songs,
                                  ),
                                ),
                              );
                            },
                            trailing: _selectMode
                                ? null
                                : PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'rename') {
                                  _renameLocalPlaylist(name);
                                } else if (value == 'delete') {
                                  _deleteLocalPlaylist(name);
                                }
                              },
                              itemBuilder: (ctx) => const [
                                PopupMenuItem(
                                    value: 'rename', child: Text('Rename')),
                                PopupMenuItem(
                                    value: 'delete', child: Text('Delete')),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Colors.white12),
                        ],
                      );
                    }).toList(),
                  ],

                  // ---------------- Transferred / Received playlists ----------------
                  if (fileEntries.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: Text(
                        'Transferred / Received',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ...fileEntries.map((entry) {
                      final name = entry.key;
                      final paths = entry.value;
                      final count = paths.length;

                      // NOTE: transferred playlists ko select-mode delete me allow karna ho
                      // to yahan checkbox add kar sakte ho. Abhi simple read-only list.
                      return Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.wifi, color: Colors.white70),
                            title: Text(name,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('$count songs',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () async {
                              // ✅ clean only existing files
                              // ✅ clean only existing files
                              final existing = <String>[];
                              for (final p in paths) {
                                try {
                                  final f = File(p);
                                  if (await f.exists()) existing.add(p);
                                } catch (_) {}
                              }

                              if (existing.isEmpty) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Received songs not found on storage.'),
                                  ),
                                );
                                return;
                              }

// ✅ ONLY open list screen (auto-play nahi)
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _FilePlaylistScreen(
                                    title: name,
                                    paths: paths,
                                  ),
                                ),
                              );
                            },
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'delete') {
                                  // delete transferred playlist only (not files)
                                  await LocalPlaylists.instance.deleteFilePlaylist(name);
                                  if (!mounted) return;
                                  setState(() {});
                                }
                              },
                              itemBuilder: (ctx) => const [
                                PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Colors.white12),
                        ],
                      );
                    }).toList(),
                  ],
                ],
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
      final idData = await LocalPlaylists.instance.getAll(); // old playlists
      final fileNames = await LocalPlaylists.instance.getFilePlaylistNames();

// combined map sirf UI ke liye
      final Map<String, dynamic> data = {
        ...idData,                     // Map<String, List<int>>
        for (final name in fileNames)  // Map<String, List<String>>
          name: await LocalPlaylists.instance.getFilePlaylistPaths(name),
      };
      if (!mounted) return;

      if (data.isEmpty) {
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
            child: FutureBuilder(
              future: () async {
                final idNames = await LocalPlaylists.instance.getNames();
                final fileNames = await LocalPlaylists.instance.getFilePlaylistNames();
                return [...idNames, ...fileNames];
              }(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final names = snapshot.data as List<String>;

                return ListView(
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
                );
              },
            ),
          );

        },
      );

      if (selectedName == null) return;

// 🔒 check: transferred playlist?
      final filePaths =
      await LocalPlaylists.instance.getFilePlaylistPaths(selectedName);

      if (filePaths.isNotEmpty) {
        // ❌ transferred playlist me song add nahi kar sakte
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Transferred playlist me naye songs add nahi ho sakte.',
            ),
          ),
        );
        return;
      }

// ✅ normal (ID-based) playlist
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

  Future<void> _showCreatePlaylistDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('home_new_playlist_title'.tr()),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'home_playlist_name_hint'.tr()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common_cancel'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('common_create'.tr()),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    final ok = await LocalPlaylists.instance.createPlaylist(name);
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('home_playlist_create_failed'.tr())),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('home_playlist_created'.tr(args: [name]))),
      );
      setState(() {});
    }
  }

  Future<void> _renameLocalPlaylist(String oldName) async {
    final controller = TextEditingController(text: oldName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename playlist'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'New playlist name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common_cancel'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('common_save'.tr()),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;

    final ok = await LocalPlaylists.instance.renamePlaylist(oldName, newName);
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not rename playlist (name already exists?).')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Playlist renamed to "$newName".')),
      );
      setState(() {});
    }
  }

  Future<void> _deleteLocalPlaylist(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete playlist'),
        content: Text(
          'Are you sure you want to delete "$name"?\nSongs file se delete nahi honge, sirf playlist se hatenge.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common_cancel'.tr())),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('common_delete'.tr())),
        ],
      ),
    );

    if (confirm != true) return;

    await LocalPlaylists.instance.deletePlaylist(name);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Playlist "$name" deleted.')),
    );
    setState(() {});
  }

  Widget _buildFolders() {
    return FutureBuilder<Map<String, List<SongModel>>>(
      future: _foldersFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data ?? {};
        _cacheFoldersMap = data;

        if (data.isEmpty) {
          return Center(
            child: Text('home_no_folders'.tr(), style: const TextStyle(color: Colors.white60)),
          );
        }

        final entries = data.entries
            .where((e) => !_hiddenFolders.contains(e.key))
            .toList()
          ..sort((a, b) => p.basename(a.key).toLowerCase().compareTo(p.basename(b.key).toLowerCase()));

        if (entries.isEmpty && _hiddenFolders.isEmpty) {
          return const Center(child: Text('No folders found'));
        }

        return Column(
          children: [
            if (_hiddenFolders.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _showHiddenFoldersSheet(data),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: Text('Hidden folders (${_hiddenFolders.length})'),
                  ),
                ),
              ),
            Expanded(
              child: entries.isEmpty
                  ? const Center(child: Text('All folders are hidden'))
                  : Builder(
                builder: (context) {
                  // ✅ Naya Ad Logic calculation
                  final int len = entries.length;
                  const int k = 7;

                  final bool showSingleAd = len > 0 && len < k; // 1..6 folders
                  final int adCount = (len >= k) ? (len ~/ k) : (showSingleAd ? 1 : 0);
                  final int totalCount = len + adCount;

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 92), // Mini player space
                    itemCount: totalCount,
                    itemBuilder: (context, index) {
                      // ✅ Ad check
                      final bool isAd = (len >= k)
                          ? ((index + 1) % (k + 1) == 0)              // 7+ folders par har 7th position ad
                          : (showSingleAd && index == totalCount - 1); // 1-6 folders par last position ad

                      if (isAd) {
                        return _inlineBanner(); // Aapka banner ad widget
                      }

                      // ✅ Real index calculation (ads minus karke)
                      final int adsBefore = (len >= k) ? ((index + 1) ~/ (k + 1)) : 0;
                      final int realIdx = index - adsBefore;

                      if (realIdx < 0 || realIdx >= len) return const SizedBox.shrink();

                      final entry = entries[realIdx];
                      final folderPath = entry.key;
                      final songs = entry.value;
                      final name = p.basename(folderPath);
                      final selected = _selectedFolderPaths.contains(folderPath);

                      // --- Folder Display Logic ---
                      if (_selectMode) {
                        return ListTile(
                          leading: Checkbox(
                            value: selected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedFolderPaths.add(folderPath);
                                } else {
                                  _selectedFolderPaths.remove(folderPath);
                                }
                              });
                            },
                          ),
                          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${songs.length} songs', maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () {
                            setState(() {
                              if (selected) {
                                _selectedFolderPaths.remove(folderPath);
                              } else {
                                _selectedFolderPaths.add(folderPath);
                              }
                            });
                          },
                        );
                      }

                      return FolderTile(
                        name: name,
                        path: folderPath,
                        songCount: songs.length,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FolderDetailScreen(
                                folderName: name,
                                folderPath: folderPath,
                                songs: songs,
                              ),
                            ),
                          ).then((_) {
                            // NowPlaying se back aane par mini player visibility restore
                            homeMiniVisible.value = true;
                          });
                        },
                        onMenuAction: (action) {
                          _onFolderMenuAction(name, folderPath, songs, action);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This folder has no songs.')));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This folder has no songs.')));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This folder has no songs.')));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This folder has no songs.')));
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
        SnackBar(content: Text('Added $added song(s) from "$folderName" to "$selectedName".')),
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

  void _showHiddenFoldersSheet(Map<String, List<SongModel>> data) {
    if (_hiddenFolders.isEmpty) return;

    final hiddenEntries = <Map<String, dynamic>>[];
    for (final path in _hiddenFolders) {
      final songs = data[path];
      if (songs == null) continue;

      hiddenEntries.add({'name': p.basename(path), 'path': path, 'songs': songs});
    }

    if (hiddenEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hidden folders available.')),
      );
      return;
    }

    hiddenEntries.sort(
          (a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()),
    );

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1B1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollCtrl) {
            return Column(
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_off_outlined, color: Colors.white70),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Hidden folders',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    itemCount: hiddenEntries.length,
                    itemBuilder: (context, index) {
                      final item = hiddenEntries[index];
                      final name = item['name'] as String;
                      final path = item['path'] as String;
                      final songs = item['songs'] as List<SongModel>;

                      return ListTile(
                        leading: const Icon(Icons.folder, color: Colors.white70),
                        title: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          '${songs.length} songs\n$path',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        trailing: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _unhideFolder(name, path);
                          },
                          child: const Text('Unhide', style: TextStyle(color: Colors.white)),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _unhideFolder(name, path);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 🔹 Delete from device – file system se delete karne ki try
  void _deleteFolderFromDevice(String folderName, String folderPath, List<SongModel> songs)
  async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text(
          'All audio files in "$folderName" will be deleted from your device. This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // ✅ collect content:// uris
    final uris = songs
        .map((s) => s.uri)
        .whereType<String>()
        .toList();

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

    if (!mounted) return;

    await _initPermissionsAndLoad();

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
            child: Text('No albums found', style: TextStyle(color: Colors.white60)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 92),
          itemCount: albums.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
          itemBuilder: (context, i) {
            final al = albums[i];
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
                      child: const Icon(Icons.album, color: Colors.white70),
                    ),
                  ),
                ),
              ),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('$artist • $count songs', maxLines: 1, overflow: TextOverflow.ellipsis),

              onTap: () async {
                if (_selectMode) {
                  setState(() {
                    if (selected) {
                      _selectedAlbumIds.remove(al.id);
                    } else {
                      _selectedAlbumIds.add(al.id);
                    }
                  });
                  return;
                }

                final songs = await _songsForAlbum(al);
                if (!mounted) return;

                if (songs.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No songs found in "$name"')),
                  );
                  return;
                }

                homeMiniVisible.value = true;
                await PlayerManager.I.playPlaylist(songs, 0);

                Navigator.push( context,
                  MaterialPageRoute(
                    builder: (_) => NowPlayingScreen(playlist: songs, startIndex: 0),
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

                    if (!mounted) return;
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
                  PopupMenuItem(value: 'add_to_playlist', child: Text('Add to playlist')),
                ],
              ),
            );
          },
        );
      },
    );
  }

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

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 92),
          itemCount: artists.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
          itemBuilder: (context, i) {
            final ar = artists[i];
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
                    }
                  });
                },
              )
                  : const Icon(Icons.person),
              title: Text(ar.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${ar.numberOfTracks ?? 0} songs', maxLines: 1, overflow: TextOverflow.ellipsis),
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
                if (!mounted) return;

                if (songs.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No songs found in "$name"')),
                  );
                  return;
                }

                homeMiniVisible.value = true;
                await PlayerManager.I.playPlaylist(songs, 0);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NowPlayingScreen(playlist: songs, startIndex: 0),
                  ),
                );
              },
              trailing: _selectMode
                  ? null
                  : PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  if (value == 'add_to_playlist') {
                    final songs = await _audioQuery.queryAudiosFrom(AudiosFromType.ARTIST_ID, ar.id);
                    if (!mounted) return;

                    if (songs.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'No songs found for "${ar.artist}".',
                          ),
                        ),
                      );
                      return;
                    }

                    _addFolderToPlaylist(ar.artist, songs);
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'add_to_playlist', child: Text('Add to playlist')),
                ],
              ),
            );
          },
        );
      },
    );
  }

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

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 92),
          itemCount: genres.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
          itemBuilder: (context, i) {
            final g = genres[i];
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
                  : const Icon(Icons.tag),
              title: Text(g.genre, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${g.numOfSongs} songs', maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () async {
                if (_selectMode) {
                  setState(() {
                    if (selected) {
                      _selectedGenreIds.remove(g.id);
                    } else {
                      _selectedGenreIds.add(g.id);
                    }
                  });
                  return;
                }

                final songs = await _songsForGenre(g);
                if (!mounted) return;

                if (songs.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No songs found in "$name"')),
                  );
                  return;
                }

                homeMiniVisible.value = true;
                await PlayerManager.I.playPlaylist(songs, 0);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NowPlayingScreen(playlist: songs, startIndex: 0),
                  ),
                );
              },
              trailing: _selectMode
                  ? null
                  : PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  if (value == 'add_to_playlist') {
                    final songs = await _audioQuery.queryAudiosFrom(AudiosFromType.GENRE_ID, g.id);
                    if (!mounted) return;

                    if (songs.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('No songs found in "${g.genre}".'),
                        ),
                      );
                      return;
                    }

                    _addFolderToPlaylist(g.genre, songs);
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'add_to_playlist', child: Text('Add to playlist')),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Permission gate UI
  Widget _buildPermissionGate() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.library_music_outlined, size: 56, color: Colors.white70),
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

  // ------------- Album / Artist / Genre helper methods -------------

  Future<List<SongModel>> _getAllSongsSafe() async {
    final songs = await (_allSongsFuture ??
        _audioQuery.querySongs(
          sortType: SongSortType.TITLE,
          orderType: OrderType.ASC_OR_SMALLER,
          uriType: UriType.EXTERNAL,
        ));
    return songs;
  }

  Future<List<SongModel>> _songsForAlbum(AlbumModel al) async {
    final all = await _getAllSongsSafe();
    final albumName = al.album;
    return all.where((s) => (s.album ?? '') == albumName).toList();
  }

  Future<List<SongModel>> _songsForArtist(ArtistModel ar) async {
    final all = await _getAllSongsSafe();
    final artistName = ar.artist;
    return all.where((s) => (s.artist ?? '') == artistName).toList();
  }

  Future<List<SongModel>> _songsForGenre(GenreModel g) async {
    final all = await _getAllSongsSafe();
    final genreName = g.genre;
    return all.where((s) => (s.genre ?? '') == genreName).toList();
  }

  // ------------- small helper methods used above -------------

  String _cleanTitle(SongModel s) {
    final t = (s.title.isNotEmpty && s.title.toLowerCase() != '<unknown>')
        ? s.title
        : p.basenameWithoutExtension(s.data);
    return t.replaceAll('_', ' ').trim();
  }

  String _artistOf(SongModel s) {
    final a = s.artist ?? '';
    if (a.isEmpty || a.toLowerCase() == '<unknown>') return 'Unknown artist';
    return a;
  }

  String _fmtDur(int? ms) {
    final d = Duration(milliseconds: ms ?? 0);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
class _FilePlaylistScreen extends StatelessWidget {
  final String title;
  final List<String> paths;

  const _FilePlaylistScreen({
    required this.title,
    required this.paths,
  });

  String _fileName(String path) => p.basename(path);

  @override
  Widget build(BuildContext context) {
    final cleaned = paths.where((e) => e.trim().isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: cleaned.isEmpty
          ? const Center(child: Text('No songs found'))
          : ListView.separated(
        padding: const EdgeInsets.only(bottom: 92),
        itemCount: cleaned.length,
        separatorBuilder: (_, __) =>
        const Divider(height: 1, color: Colors.white12),
        itemBuilder: (context, i) {
          final path = cleaned[i];
          return ListTile(
            leading: const Icon(Icons.music_note, color: Colors.white70),
            title: Text(
              _fileName(path),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            onTap: () async {
              // ✅ play selected
              homeMiniVisible.value = true;
              await PlayerManager.I.playFilePlaylist(cleaned, startIndex: i);

              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NowPlayingScreen(
                    playlist: null,
                    startIndex: i,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
Future<_PlaylistsBundle> _loadAllPlaylistsBundle() async {
  final idMap = await LocalPlaylists.instance.getAll();

  final fileNames = await LocalPlaylists.instance.getFilePlaylistNames();
  final fileMap = <String, List<String>>{};
  for (final n in fileNames) {
    fileMap[n] = await LocalPlaylists.instance.getFilePlaylistPaths(n);
  }

  return _PlaylistsBundle(idPlaylists: idMap, filePlaylists: fileMap);
}

class _PlaylistsBundle {
  final Map<String, List<int>> idPlaylists;
  final Map<String, List<String>> filePlaylists;

  _PlaylistsBundle({
    required this.idPlaylists,
    required this.filePlaylists,
  });
}


/// ---------------- Helper types ----------------
class _FolderEntry {
  final String name;
  final String path;
  final List<SongModel> songs;
  _FolderEntry({required this.name, required this.path, required this.songs});
}

/// ---------------- Simple Song List Screen (albums / artists / genres / playlists) ----------------
class _SongListScreen extends StatelessWidget {
  final String title;
  final List<SongModel> songs;

  const _SongListScreen({required this.title, required this.songs});

  String _cleanTitle(SongModel s) {
    final t = (s.title.isNotEmpty && s.title.toLowerCase() != '<unknown>')
        ? s.title
        : p.basenameWithoutExtension(s.data);
    return t.replaceAll('_', ' ').trim();
  }

  String _artistOf(SongModel s) {
    final a = s.artist ?? '';
    if (a.isEmpty || a.toLowerCase() == '<unknown>') return 'Unknown artist';
    return a;
  }

  String _fmtDur(int? ms) {
    final d = Duration(milliseconds: ms ?? 0);
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        padding: const EdgeInsets.only(bottom: 92),
        itemCount: songs.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12, indent: 72),
        itemBuilder: (context, i) {
          final s = songs[i];
          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),

              child: SizedBox(
                width: 48,
                height: 48,
                child: QueryArtworkWidget(
                  id: s.id,
                  type: ArtworkType.AUDIO,
                  nullArtworkWidget: const Icon(Icons.music_note),
                ),
              ),
            ),
            title: Text(_cleanTitle(s),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              _artistOf(s),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              _fmtDur(s.duration),
              style: const TextStyle(color: Colors.white70),
            ),
            onTap: () {
              homeMiniVisible.value = true;
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
            },
          );
        },
      ),
    );
  }
}

/// ---------------- Search Screen (context-aware) ----------------
class _SearchScreen extends StatefulWidget {
  final _SearchMode mode;
  final List<SongModel> allSongs;
  final List<_FolderEntry> folderEntries;
  final Map<String, List<SongModel>> albumsMap;
  final Map<String, List<SongModel>> artistsMap;

  const _SearchScreen({
    required this.mode,
    required this.allSongs,
    required this.folderEntries,
    required this.albumsMap,
    required this.artistsMap,
  });

  @override
  State<_SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<_SearchScreen> {
  String _query = '';
  late List<SongModel> _songResults;
  late List<_FolderEntry> _folderResults;
  late List<String> _albumResults;
  late List<String> _artistResults;

  @override
  void initState() {
    super.initState();
    InterstitialHelper.instance.preload();
    _songResults = widget.allSongs;
    _folderResults = widget.folderEntries;
    _albumResults = widget.albumsMap.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _artistResults = widget.artistsMap.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  void _onQueryChanged(String q) {
    setState(() {
      _query = q.trim().toLowerCase();
      if (_query.isEmpty) {
        _songResults = widget.allSongs;
        _folderResults = widget.folderEntries;
        _albumResults = widget.albumsMap.keys.toList();
        _artistResults = widget.artistsMap.keys.toList();
      } else {
        _songResults = widget.allSongs.where((s) {
          final title = (s.title).toLowerCase();
          final artist = (s.artist ?? '').toLowerCase();
          return title.contains(_query) || artist.contains(_query);
        }).toList();

        _folderResults = widget.folderEntries.where((f) {
          return f.name.toLowerCase().contains(_query) ||
              f.path.toLowerCase().contains(_query);
        }).toList();

        _albumResults = widget.albumsMap.keys
            .where((a) => a.toLowerCase().contains(_query))
            .toList();
        _artistResults = widget.artistsMap.keys
            .where((a) => a.toLowerCase().contains(_query))
            .toList();
      }
    });
  }

  String _cleanTitle(SongModel s) {
    final t = (s.title.isNotEmpty && s.title.toLowerCase() != '<unknown>')
        ? s.title
        : p.basenameWithoutExtension(s.data);
    return t.replaceAll('_', ' ').trim();
  }

  String _artistOf(SongModel s) {
    final a = s.artist ?? '';
    if (a.isEmpty || a.toLowerCase() == '<unknown>') return 'Unknown artist';
    return a;
  }

  String _fmtDur(int? ms) {
    final d = Duration(milliseconds: ms ?? 0);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: InputDecoration.collapsed(
            hintText: 'search_hint'.tr(),
          ),
          onChanged: _onQueryChanged,
        ),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _buildBodyForMode(mode),
    );
  }

  Widget _buildBodyForMode(_SearchMode mode) {
    switch (mode) {
      case _SearchMode.folders:
        return _folderResults.isEmpty

            ? Center(

            child: Text('search_no_folders'.tr(),
                style: TextStyle(color: Colors.white60)))
            : ListView.separated(
          padding: const EdgeInsets.only(bottom: 92),
          itemCount: _folderResults.length,
          separatorBuilder: (_, __) =>
          const Divider(color: Colors.white12, height: 1),
          itemBuilder: (context, i) {
            final f = _folderResults[i];
            return ListTile(
              title: Text(f.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${f.songs.length} songs',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FolderDetailScreen(
                      folderName: f.name,
                      folderPath: f.path,
                      songs: f.songs,
                    ),
                  ),
                );
              },
            );
          },
        );

      case _SearchMode.songs:
        return _songResults.isEmpty
            ? Center(
            child: Text('search_no_songs'.tr(),
                style: TextStyle(color: Colors.white60)))
            : ListView.separated(
          padding: const EdgeInsets.only(bottom: 92),
          itemCount: _songResults.length,
          separatorBuilder: (_, __) =>
          const Divider(color: Colors.white12, height: 1),
          itemBuilder: (context, i) {
            final s = _songResults[i];
            final playIndex = widget.allSongs
                .indexWhere((x) => x.data == s.data);
            return ListTile(
              leading: ClipRRect(
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
              title: Text(_cleanTitle(s),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(_artistOf(s),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text(_fmtDur(s.duration),
                  style:
                  const TextStyle(color: Colors.white70)),
              onTap: () {
                homeMiniVisible.value = true;
                PlayerManager.I.playPlaylist(
                    widget.allSongs, playIndex);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NowPlayingScreen(
                      playlist: widget.allSongs,
                      startIndex: playIndex,
                    ),
                  ),
                );
              },
            );
          },
        );

      case _SearchMode.albums:
        return _albumResults.isEmpty
            ? Center(
            child: Text('search_no_albums'.tr(),
                style: TextStyle(color: Colors.white60)))
            : ListView.separated(
          padding: const EdgeInsets.only(bottom: 92),
          itemCount: _albumResults.length,
          separatorBuilder: (_, __) =>
          const Divider(color: Colors.white12, height: 1),
          itemBuilder: (context, i) {
            final album = _albumResults[i];
            final songs = widget.albumsMap[album] ?? [];
            return ListTile(
              title: Text(album,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${songs.length} songs',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                homeMiniVisible.value = true;
                PlayerManager.I.playPlaylist(songs, 0);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NowPlayingScreen(
                        playlist: songs, startIndex: 0),
                  ),
                );
              },
            );
          },
        );

      case _SearchMode.artists:
        return _artistResults.isEmpty
            ? Center(
            child: Text('search_no_artists'.tr(),
                style: TextStyle(color: Colors.white60)))
            : ListView.separated(
          padding: const EdgeInsets.only(bottom: 92),
          itemCount: _artistResults.length,
          separatorBuilder: (_, __) =>
          const Divider(color: Colors.white12, height: 1),
          itemBuilder: (context, i) {
            final artist = _artistResults[i];
            final songs = widget.artistsMap[artist] ?? [];
            return ListTile(
              title: Text(artist,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${songs.length} songs',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                homeMiniVisible.value = true;
                PlayerManager.I.playPlaylist(songs, 0);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NowPlayingScreen(
                        playlist: songs, startIndex: 0),
                  ),
                );
              },
            );
          },
        );

      case _SearchMode.playlists:
      case _SearchMode.others:
        return Center(
          child: Text('search_not_available'.tr(),
              style: TextStyle(color: Colors.white60)),
        );
    }
  }
}

/// ---------------- HOME MINI PLAYER (swipe + cut) ----------------
class HomeMiniPlayer extends StatelessWidget {
  const HomeMiniPlayer({super.key});

  static const AdSize _fixedAayatSize = AdSize(width: 320, height: 50);

  @override
  Widget build(BuildContext context) {
    final player = PlayerManager.I.player;

    return SafeArea(
      top: false,
      child: StreamBuilder<SequenceState?>(
        stream: player.sequenceStateStream,
        builder: (context, snap) {
          final seqState = snap.data;
          final idx = player.currentIndex ?? -1;

          // ✅ Agar koi gaana nahi hai, to pura Column (Player + Ad) shrink ho jayega
          if (seqState == null || idx < 0 || idx >= seqState.sequence.length) {
            return const SizedBox.shrink();
          }

          final list = PlayerManager.I.currentPlaylist();
          final hasSongModel = list.isNotEmpty && idx < list.length;

          MediaItem? media;
          if (!hasSongModel) {
            final tag = seqState.sequence[idx].tag;
            if (tag is MediaItem) media = tag;
          }

          if (!hasSongModel && media == null) {
            return const SizedBox.shrink();
          }

          final title = hasSongModel
              ? (list[idx].title.isNotEmpty ? list[idx].title : p.basename(list[idx].data))
              : (media!.title.isNotEmpty ? media.title : 'Unknown');

          final artist = hasSongModel
              ? ((list[idx].artist == null || list[idx].artist!.toLowerCase() == '<unknown>')
              ? 'Unknown artist'
              : list[idx].artist!)
              : ((media!.artist?.isNotEmpty ?? false) ? media.artist! : 'Received');

          // ✅ MAIN CHANGE: Pura content Column mein hai taaki Ad player ka hissa rahe
          return Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min, // Zaroori hai
              children: [
                // 🎵 Mini Player Card
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NowPlayingScreen(startPlayback: false),
                      ),
                    ).then((value) {
                      // ✅ Jab NowPlayingScreen se wapas aayenge, toh mini player wapas dikhega
                      homeMiniVisible.value = true;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 0), // Bottom margin hataya
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        // Artwork
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 46, height: 46,
                            child: hasSongModel
                                ? QueryArtworkWidget(
                              id: list[idx].id,
                              type: ArtworkType.AUDIO,
                              nullArtworkWidget: Container(
                                color: Colors.white10,
                                child: const Icon(Icons.music_note, color: Colors.white70, size: 28),
                              ),
                            )
                                : Container(color: Colors.white10, child: const Icon(Icons.wifi, color: Colors.white70)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        // Controls
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded),
                          onPressed: player.hasPrevious ? () async {
                            await player.seekToPrevious();
                            await player.play();
                          } : null,
                        ),
                        StreamBuilder<bool>(
                          stream: player.playingStream,
                          builder: (context, playSnap) {
                            final playing = playSnap.data ?? false;
                            return IconButton(
                              icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
                              iconSize: 34,
                              onPressed: () => PlayerManager.I.togglePlayPause(),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded),
                          onPressed: player.hasNext ? () async {
                            await player.seekToNext();
                            await player.play();
                          } : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 22),
                          onPressed: () async {
                            // Sirf visibility false karein, player stop karne se stream band ho jati hai
                            homeMiniVisible.value = false;
                            // Agar aap chahte hain gaana bajta rahe par player hide ho jaye to stop mat karein
                            // await player.stop(); // Is line ko hata sakte hain agar background me bajne dena hai
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // 📐 Gap & Banner (Ye ab Mini Player ka part hai)
                const SizedBox(height: 2),

                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Center(
                    child: BannerAdWidget(
                      adUnitId: AdIds.banner,
                      size: _fixedAayatSize,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}