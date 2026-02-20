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
import 'package:youplay_music/playlist_parts/playlist_detail_screen.dart';
import 'package:youplay_music/services/media_delete.dart';
import 'ads/banner_plan.dart';

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
import 'dart:async';
import 'package:receive_intent/receive_intent.dart' as ri;


// =========================
// ✅ PARTS (SYSTEMATIC SPLIT)
// =========================
part 'home_parts/home_library_helpers.dart';
part 'home_parts/home_selection.dart';
part 'home_parts/home_permissions.dart';
part 'home_parts/home_ads.dart';
part 'home_parts/tab_for_you.dart';
part 'home_parts/tab_songs.dart';
part 'home_parts/tab_playlists.dart';
part 'home_parts/tab_folders.dart';
part 'home_parts/home_folder_actions.dart';
part 'home_parts/tab_albums.dart';
part 'home_parts/tab_artists.dart';
part 'home_parts/tab_genres.dart';
part 'home_parts/home_search.dart';
part 'home_parts/home_mini_player.dart';
part 'home_parts/home_intents_mixin.dart';

enum _SearchMode { folders, songs, albums, artists, playlists, others }

final ValueNotifier<bool> homeMiniVisible = ValueNotifier<bool>(true);

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with
        HomeIntentsMixin
{

  void refreshPlaylists() {
    if (!mounted) return;
    setState(() {
      // Naya future assign karne se FutureBuilder dubara trigger hoga
      _playlistsFuture = _audioQuery.queryPlaylists();
    });
  }
  final tabs = const [
    'tab_for_you',
    'tab_songs',
    'tab_playlist',
    'tab_folders',
    'tab_albums',
    'tab_artists',
    'tab_genres',
  ];

  int selectedTab = 3;

  final OnAudioQuery _audioQuery = OnAudioQuery();
  bool _hasPermission = false;

  final _lib = MediaLibraryService();
  Future<Map<String, List<SongModel>>>? _foldersFuture;
  Future<List<SongModel>>? _allSongsFuture;
  Future<List<AlbumModel>>? _albumsFuture;
  Future<List<ArtistModel>>? _artistsFuture;
  Future<List<GenreModel>>? _genresFuture;
  Future<List<PlaylistModel>>? _playlistsFuture;


  // ✅ updated for new BannerAdWidget (placement + slot required)
  Widget _inlineBanner({
    required String placement,
    required int slot,
    AdSize size = AdSize.banner,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Center(
        child: BannerAdWidget(
          adUnitId: AdIds.banner,
          placement: placement,
          slot: slot,
          size: size,
        ),
      ),
    );
  }


  final Set<String> _hiddenFolders = <String>{};
  bool _selectMode = false;

  final Set<int> _selectedSongIds = {};
  final Set<String> _selectedPlaylistNames = {};
  final Set<String> _selectedFolderPaths = {};
  final Set<int> _selectedAlbumIds = {};
  final Set<int> _selectedArtistIds = {};
  final Set<int> _selectedGenreIds = {};

  List<SongModel> _cacheAllSongs = [];
  List<SongModel> _cacheForYouSongs = [];
  List<AlbumModel> _cacheAlbums = [];
  List<ArtistModel> _cacheArtists = [];
  List<GenreModel> _cacheGenres = [];
  final Map<String, List<SongModel>> _cacheFoldersMap = {};

  // ✅ FIX: Getter ko real variable banaya taaki Playlist logic work kare
  List<PlaylistModel> _cachePlaylistModels = [];

  final List<MapEntry<String, List<int>>> _cachePlaylistsEntries = [];


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
      // ✅ FIX: Cache list use ki
      if (_cachePlaylistModels.isEmpty) return false;
      return _selectedPlaylistNames.length == _cachePlaylistModels.length;
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
      if (tab == 'tab_songs') {
        _selectedSongIds..clear()..addAll(selectAll ? _cacheAllSongs.map((e) => e.id) : []);
      } else if (tab == 'tab_for_you') {
        _selectedSongIds..clear()..addAll(selectAll ? _cacheForYouSongs.map((e) => e.id) : []);
      } else if (tab == 'tab_playlist') {
        // ✅ FIX: PlaylistModel cache se selection toggle kiya
        _selectedPlaylistNames..clear()..addAll(selectAll ? _cachePlaylistModels.map((e) => e.playlist) : []);
      } else if (tab == 'tab_folders') {
        final visible = _cacheFoldersMap.keys.where((path) => !_hiddenFolders.contains(path)).toList();
        _selectedFolderPaths..clear()..addAll(selectAll ? visible : []);
      } else if (tab == 'tab_albums') {
        _selectedAlbumIds..clear()..addAll(selectAll ? _cacheAlbums.map((e) => e.id) : []);
      } else if (tab == 'tab_artists') {
        _selectedArtistIds..clear()..addAll(selectAll ? _cacheArtists.map((e) => e.id) : []);
      } else if (tab == 'tab_genres') {
        _selectedGenreIds..clear()..addAll(selectAll ? _cacheGenres.map((e) => e.id) : []);
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

  @override
  void initState() {
    super.initState();
    _initPermissionsAndLoad();
    initAudioOpenWithIntents();
  }

  @override
  void dispose() {
    disposeAudioOpenWithIntents(); // ✅ ADD THIS
    super.dispose();
  }

  Future<void> _initPermissionsAndLoad() async {
    final ok = await ensureAudioPermission();
    if (!mounted) return;

    setState(() {
      _hasPermission = ok;
      if (ok) {
        // ✅ FIX: Playlist future initialize kiya
        _playlistsFuture = _audioQuery.queryPlaylists();
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
        _playlistsFuture = null;
      }
    });
  }

  Widget _buildAllSelectBar() {
    if (!_selectMode) return const SizedBox.shrink();

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
          Text('$selectedCount selected', style: const TextStyle(color: Colors.white70)),
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

  @override
  Widget build(BuildContext context) {
    final tabKey = tabs[selectedTab];

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            text: 'MUSIC ',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                            children: const [
                              TextSpan(text: 'PLAYER', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),

                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.search),
                        onPressed: () async {
                          await InterstitialHelper.instance.tryShow();
                          if (!mounted) return;
                          _openSearch();
                        },
                      ),
                      const SizedBox(width: 12),

                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.settings),
                        onPressed: () async {
                          await InterstitialHelper.instance.tryShow(placement: 'open_settings');
                          if (!mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          );
                        },
                      ),
                      const SizedBox(width: 12),

                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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
                    ],
                  ),
                ),
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
                        onSelected: (_) async {
                          if (isSelected) return;

                          // ✅ tab change => interstitial allowed (cooldown inside helper)
                          await InterstitialHelper.instance.tryShow();

                          if (!mounted) return;
                          setState(() => selectedTab = index);
                          _exitSelectMode();
                        },
                        shape: const StadiumBorder(),
                        selectedColor: Colors.white12,
                        labelStyle: TextStyle(
                          color: Colors.white.withValues(alpha: isSelected ? 1.0 : 0.9),
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
                _buildAllSelectBar(),
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

  Widget _buildTabContent(String tabKey) {
    switch (tabKey) {
      case 'tab_for_you': return _buildForYou();
      case 'tab_songs': return _buildSongsTab();
      case 'tab_playlist': return _buildPlaylistsTab();
      case 'tab_folders': return _buildFolders();
      case 'tab_albums': return _buildAlbumsTab();
      case 'tab_artists': return _buildArtistsTab();
      case 'tab_genres': return _buildGenresTab();
      default: return const SizedBox.shrink();
    }
  }
}
