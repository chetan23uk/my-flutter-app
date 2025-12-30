import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'media_library.dart';

/// Simple local playlist storage:
/// - idPlaylists: Map<String, List<int>>
///    "My Favs" -> [songId1, songId2, ...]
/// - filePlaylists: Map<String, List<String>>
///    "Transferred ..." -> ["/app/documents/received_songs/a.mp3", ...]
class LocalPlaylists {
  LocalPlaylists._();
  static final LocalPlaylists instance = LocalPlaylists._();

  // ✅ bump version because we now store both kinds
  static const String _storageKey = 'local_playlists_v2';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<_StoreModel> _loadStore() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return _StoreModel(
        idPlaylists: <String, List<int>>{},
        filePlaylists: <String, List<String>>{},
      );
    }

    try {
      final Map<String, dynamic> decoded = jsonDecode(raw);

      final Map<String, List<int>> idPlaylists = {};
      final Map<String, List<String>> filePlaylists = {};

      final ids = decoded['ids'];
      if (ids is Map<String, dynamic>) {
        ids.forEach((k, v) {
          final list = (v as List).map((e) => e as int).toList();
          idPlaylists[k] = list;
        });
      }

      final files = decoded['files'];
      if (files is Map<String, dynamic>) {
        files.forEach((k, v) {
          final list = (v as List).map((e) => e as String).toList();
          filePlaylists[k] = list;
        });
      }

      return _StoreModel(idPlaylists: idPlaylists, filePlaylists: filePlaylists);
    } catch (_) {
      return _StoreModel(
        idPlaylists: <String, List<int>>{},
        filePlaylists: <String, List<String>>{},
      );
    }
  }

  Future<void> _saveStore(_StoreModel store) async {
    final prefs = await _prefs;
    final json = jsonEncode({
      'ids': store.idPlaylists.map((k, v) => MapEntry(k, v.toList())),
      'files': store.filePlaylists.map((k, v) => MapEntry(k, v.toList())),
    });
    await prefs.setString(_storageKey, json);
  }

  // -------------------- IDs based playlists (existing behavior) --------------------

  /// Saare playlists ka full map (IDs)
  Future<Map<String, List<int>>> getAll() async {
    final store = await _loadStore();
    return store.idPlaylists;
  }

  /// Sirf names (sorted) for ID playlists
  Future<List<String>> getNames() async {
    final store = await _loadStore();
    final names = store.idPlaylists.keys.toList();
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  /// Specific playlist ke song IDs
  Future<List<int>> getSongIds(String name) async {
    final store = await _loadStore();
    return store.idPlaylists[name]?.toList() ?? <int>[];
  }

  /// Naya playlist banao – success: true, agar pehle se hai to false
  Future<bool> createPlaylist(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;

    final store = await _loadStore();
    if (store.idPlaylists.containsKey(trimmed)) return false;

    store.idPlaylists[trimmed] = <int>[];
    await _saveStore(store);
    return true;
  }

  /// Playlist delete
  Future<void> deletePlaylist(String name) async {
    final store = await _loadStore();
    store.idPlaylists.remove(name);
    await _saveStore(store);
  }

  /// Single song add – agar pehle se hai to duplicate nahi add karega
  Future<bool> addSong(String playlistName, int songId) async {
    final store = await _loadStore();
    final list = store.idPlaylists[playlistName] ?? <int>[];
    if (!list.contains(songId)) {
      list.add(songId);
      store.idPlaylists[playlistName] = list;
      await _saveStore(store);
    }
    return true;
  }

  /// Rename playlist
  /// return: true = success, false = fail (jaise newName already exist)
  Future<bool> renamePlaylist(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return false;

    final store = await _loadStore();

    if (!store.idPlaylists.containsKey(oldName)) return false;
    if (store.idPlaylists.containsKey(trimmed) && trimmed != oldName) return false;

    final list = store.idPlaylists[oldName] ?? <int>[];
    store.idPlaylists.remove(oldName);
    store.idPlaylists[trimmed] = list;
    await _saveStore(store);
    return true;
  }

  /// Multiple songs add – return: kitne naye songs add hue
  Future<int> addSongs(String playlistName, List<int> songIds) async {
    final store = await _loadStore();
    final list = store.idPlaylists[playlistName] ?? <int>[];
    int added = 0;

    for (final id in songIds) {
      if (!list.contains(id)) {
        list.add(id);
        added++;
      }
    }

    store.idPlaylists[playlistName] = list;
    await _saveStore(store);
    return added;
  }

  // -------------------- NEW: Wi-Fi transfer helper --------------------

  /// IDs playlist -> REAL file paths (sender uses this)
  Future<List<String>> getSongPathsForPlaylist(
      String playlistName,
      MediaLibraryService library,
      ) async {
    final store = await _loadStore();
    final ids = store.idPlaylists[playlistName] ?? <int>[];
    if (ids.isEmpty) return <String>[];

    final songs = await library.fetchSongs(); // ✅ correct method
    final idSet = ids.toSet();

    return songs
        .where((s) => idSet.contains(s.id))
        .map((s) => s.data)
        .where((p) => p.isNotEmpty)
        .toList();
  }

  // -------------------- NEW: file-based playlists (receiver uses this) --------------------

  /// Get transferred playlists names
  Future<List<String>> getFilePlaylistNames() async {
    final store = await _loadStore();
    final names = store.filePlaylists.keys.toList();

    // ✅ improvement: Transferred playlists usually have ISO timestamp in name,
    // so "latest first" is better UX.
    names.sort((a, b) => b.toLowerCase().compareTo(a.toLowerCase()));
    return names;
  }

  /// Get transferred playlist file paths
  Future<List<String>> getFilePlaylistPaths(String name) async {
    final store = await _loadStore();
    return store.filePlaylists[name]?.toList() ?? <String>[];
  }

  /// Save received files as a portable playlist (receiver uses this)
  Future<void> saveReceivedFiles(String name, List<String> paths) async {
    final store = await _loadStore();

    // ✅ improvement: remove empty + duplicates (helps playback)
    final clean = <String>[];
    final seen = <String>{};
    for (final p in paths) {
      final t = p.trim();
      if (t.isEmpty) continue;
      if (seen.add(t)) clean.add(t);
    }

    store.filePlaylists[name] = clean;
    await _saveStore(store);
  }

  /// Optional helper: delete transferred playlist
  Future<void> deleteFilePlaylist(String name) async {
    final store = await _loadStore();
    store.filePlaylists.remove(name);
    await _saveStore(store);
  }
}

class _StoreModel {
  final Map<String, List<int>> idPlaylists;
  final Map<String, List<String>> filePlaylists;

  _StoreModel({
    required this.idPlaylists,
    required this.filePlaylists,
  });
}
