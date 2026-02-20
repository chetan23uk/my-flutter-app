part of '../home_screen.dart';

// ---------------- Open Search (context-aware) ----------------
extension _HomeSearchExt on _HomeScreenState {
  void _openSearch() async {
    if (_foldersFuture == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('home_library_not_loaded'.tr())),
      );
      return;
    }

    // Await the foldersFuture if not ready
    final Map<String, List<SongModel>> folders;
    try {
      folders = await _foldersFuture!;
      if (!mounted) return;
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
        .map(
          (e) => _FolderEntry(
        name: p.basename(e.key),
        path: e.key,
        songs: e.value,
      ),
    )
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
}

/// ---------------- Helper types ----------------
class _FolderEntry {
  final String name;
  final String path;
  final List<SongModel> songs;

  _FolderEntry({required this.name, required this.path, required this.songs});
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
          onPressed: () => Navigator.pop(context),
        ),
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
                style: const TextStyle(color: Colors.white60)))
            : ListView.separated(
          padding: const EdgeInsets.only(bottom: 92),
          itemCount: _folderResults.length,
          separatorBuilder: (_, __) =>
          const Divider(color: Colors.white12, height: 1),
          itemBuilder: (context, i) {
            final f = _folderResults[i];
            return ListTile(
              title:
              Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                style: const TextStyle(color: Colors.white60)))
            : ListView.separated(
          padding: const EdgeInsets.only(bottom: 92),
          itemCount: _songResults.length,
          separatorBuilder: (_, __) =>
          const Divider(color: Colors.white12, height: 1),
          itemBuilder: (context, i) {
            final s = _songResults[i];
            final playIndex =
            widget.allSongs.indexWhere((x) => x.data == s.data);

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
                  style: const TextStyle(color: Colors.white70)),
              onTap: () {
                homeMiniVisible.value = true;
                PlayerManager.I.playPlaylist(widget.allSongs, playIndex);
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
                style: const TextStyle(color: Colors.white60)))
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
                      playlist: songs,
                      startIndex: 0,
                    ),
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
                style: const TextStyle(color: Colors.white60)))
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
                      playlist: songs,
                      startIndex: 0,
                    ),
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
              style: const TextStyle(color: Colors.white60)),
        );
    }
  }
}
