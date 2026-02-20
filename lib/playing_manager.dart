import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';

// 🔔 Notification / lockscreen metadata
import 'package:just_audio_background/just_audio_background.dart';
import 'package:youplay_music/services/media_delete.dart';

/// Global audio controller used across screens.
/// Access: PlayerManager.I
class PlayerManager {
  PlayerManager._internal();
  static final PlayerManager I = PlayerManager._internal();

  final AudioPlayer _player = AudioPlayer();

  /// ✅ NOTE:
  /// We DO NOT keep a single fixed queue object anymore.
  /// We keep a reference to the CURRENT queue source, so all queue ops use it.
  ConcatenatingAudioSource _playlistSource =
  ConcatenatingAudioSource(children: []);

  /// Copy of the songs in [_playlistSource] in the same order.
  final List<SongModel> _currentSongs = [];

  bool _initialized = false;

  // ❤️ FAVORITES
  final Set<int> _favoriteSongIds = {};

  AudioPlayer get player => _player;

  /// Expose a defensive copy of current playlist for UI.
  List<SongModel> currentPlaylist() => List<SongModel>.from(_currentSongs);

  // ------------------- init -------------------

  Future<void> _ensureInit() async {
    if (_initialized) return;

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // ✅ Always start with shuffle OFF to prevent background crash
    await _player.setShuffleModeEnabled(false);

    _initialized = true;
  }

  // ------------------- helpers -------------------

  Uri _uriFromSong(SongModel song) {
    final data = (song.data).trim();

    // ✅ 1) If data is a real file path and exists, prefer it.
    if (data.startsWith('/')) {
      final f = File(data);
      if (f.existsSync()) return Uri.file(data);
    }

    // ✅ 2) Otherwise use song.uri (content://...)
    final u = song.uri;
    if (u != null && u.isNotEmpty) {
      return Uri.parse(u);
    }

    // ✅ 3) Fallback: if data already a uri, use it
    if (data.startsWith('content://') || data.startsWith('file://')) {
      return Uri.parse(data);
    }

    // ✅ 4) Final fallback
    return Uri.file(data);
  }


  String _safeTitle(SongModel song) {
    final t = song.title.trim();
    if (t.isNotEmpty && t.toLowerCase() != '<unknown>') return t;
    try {
      return Uri.file(song.data).pathSegments.isNotEmpty
          ? Uri.file(song.data).pathSegments.last
          : song.data.split('/').last;
    } catch (_) {
      return song.data.split('/').last;
    }
  }

  /// Convert song -> audio source with notification metadata.
  AudioSource _toSource(SongModel song) {
    final uri = _uriFromSong(song);

    return AudioSource.uri(
      uri,
      tag: MediaItem(
        id: song.id.toString(),
        title: _safeTitle(song),
        artist: (song.artist?.isNotEmpty ?? false) ? song.artist! : "Unknown Artist",
        album: song.album ?? "",
        // ✅ Keep artUri null (audio file path is NOT an image)
        artUri: null,
      ),
    );
  }

  Uri _parseAnyUri(String input) {
    final s = input.trim();
    if (s.startsWith('content://') || s.startsWith('file://')) {
      return Uri.parse(s);
    }
    if (s.startsWith('/')) return Uri.file(s);
    return Uri.parse(s);
  }

  // ------------------- public controls -------------------

  /// Replace the whole queue with [songs] and start playing at [startIndex].
  Future<void> playPlaylist(List<SongModel> songs, int startIndex) async {
    await _ensureInit();
    if (songs.isEmpty) return;

    // ✅ Critical: shuffle OFF before changing source (prevents RangeError)
    if (_player.shuffleModeEnabled) {
      await _player.setShuffleModeEnabled(false);
    }

    final idx =
    (startIndex < 0 || startIndex >= songs.length) ? 0 : startIndex;

    _currentSongs
      ..clear()
      ..addAll(songs);

    final sources = _currentSongs.map<AudioSource>(_toSource).toList();

    // ✅ Build NEW queue source (no empty-window clear/addAll)
    _playlistSource = ConcatenatingAudioSource(children: sources);

    await _player.setAudioSource(
      _playlistSource,
      initialIndex: idx,
      initialPosition: Duration.zero,
    );

    await _player.play();
  }

  /// Open-with / external single file play
  Future<void> playExternalUri(String uriOrPath) async {
    await _ensureInit();

    if (_player.shuffleModeEnabled) {
      await _player.setShuffleModeEnabled(false);
    }

    _currentSongs.clear();

    final uri = _parseAnyUri(uriOrPath);
    final title = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'Audio';

    final src = AudioSource.uri(
      uri,
      tag: MediaItem(
        id: uri.toString(),
        title: title,
        artist: 'Received',
        album: '',
        artUri: null,
      ),
    );

    _playlistSource = ConcatenatingAudioSource(children: [src]);

    await _player.setAudioSource(
      _playlistSource,
      initialIndex: 0,
      initialPosition: Duration.zero,
    );

    await _player.play();
  }

  /// Play transferred/file playlist (paths)
  Future<void> playFilePlaylist(List<String> paths, {int startIndex = 0}) async {
    if (paths.isEmpty) return;
    await _ensureInit();

    if (_player.shuffleModeEnabled) {
      await _player.setShuffleModeEnabled(false);
    }

    _currentSongs.clear();

    final children = <AudioSource>[];
    for (final p in paths) {
      final uri = _parseAnyUri(p);
      final title = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : p.split('/').last;

      children.add(
        AudioSource.uri(
          uri,
          tag: MediaItem(
            id: uri.toString(),
            title: title,
            artist: 'Received',
            album: '',
            artUri: null,
          ),
        ),
      );
    }

    final idx = (startIndex < 0 || startIndex >= children.length) ? 0 : startIndex;

    _playlistSource = ConcatenatingAudioSource(children: children);

    await _player.setAudioSource(
      _playlistSource,
      initialIndex: idx,
      initialPosition: Duration.zero,
    );

    await _player.play();
  }

  /// "Play next"
  Future<void> playNext(SongModel song) async {
    await _ensureInit();

    if (_currentSongs.isEmpty || _player.currentIndex == null) {
      await playPlaylist([song], 0);
      return;
    }

    final nextIndex =
    (_player.currentIndex! + 1).clamp(0, _currentSongs.length);

    _currentSongs.insert(nextIndex, song);

    // ✅ IMPORTANT: insert into CURRENT playlistSource
    await _playlistSource.insert(nextIndex, _toSource(song));
  }

  /// "Add to queue"
  Future<void> addToQueue(SongModel song) async {
    await _ensureInit();

    if (_currentSongs.isEmpty) {
      await playPlaylist([song], 0);
      return;
    }

    _currentSongs.add(song);

    // ✅ IMPORTANT: add into CURRENT playlistSource
    await _playlistSource.add(_toSource(song));
  }

  /// Add many songs
  Future<void> addPlaylist(List<SongModel> songs) async {
    await _ensureInit();
    if (songs.isEmpty) return;

    if (_currentSongs.isEmpty) {
      await playPlaylist(songs, 0);
      return;
    }

    _currentSongs.addAll(songs);

    // ✅ IMPORTANT: addAll into CURRENT playlistSource
    await _playlistSource.addAll(
      songs.map<AudioSource>(_toSource).toList(),
    );
  }

  /// Play / pause toggle
  Future<void> togglePlayPause() async {
    await _ensureInit();

    // ✅ If nothing loaded, do nothing
    if (_player.audioSource == null) return;

    final state = _player.playerState;

    if (state.playing) {
      await _player.pause();
      return;
    }

    if (state.processingState == ProcessingState.completed) {
      final idx = _player.currentIndex ?? 0;
      await _player.seek(Duration.zero, index: idx);
    }

    await _player.play();
  }

  /// Delete audio file
  Future<bool> deleteFile(SongModel song) async {
    try {
      final uri = song.uri;
      if (uri != null && uri.isNotEmpty) {
        final ok = await MediaDeleteService.deleteUris([uri]);
        if (ok) return true;
      }

      final f = File(song.data);
      if (await f.exists()) {
        await f.delete();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ------------------- ❤️ FAVORITES -------------------

  bool isFavorite(SongModel? song) {
    if (song == null) return false;
    return _favoriteSongIds.contains(song.id);
  }

  void toggleFavorite(SongModel song) {
    if (_favoriteSongIds.contains(song.id)) {
      _favoriteSongIds.remove(song.id);
    } else {
      _favoriteSongIds.add(song.id);
    }
  }

  // ------------------- MINI-PLAYER SUPPORT -------------------

  MediaItemTag? tagOfIndex(int index) {
    // ✅ Normal (SongModel) playlist
    if (_currentSongs.isNotEmpty) {
      if (index < 0 || index >= _currentSongs.length) return null;

      final s = _currentSongs[index];
      return MediaItemTag(
        id: s.id.toString(),
        title: s.title,
        artist: s.artist,
        album: s.album,
        artPath: s.data,
      );
    }

    // ✅ File / external playlist (MediaItem tag from just_audio_background)
    try {
      final seq = _player.sequence;
      if (seq == null || seq.isEmpty) return null;
      if (index < 0 || index >= seq.length) return null;

      final tag = seq[index].tag;
      if (tag is MediaItem) {
        return MediaItemTag(
          id: tag.id,
          title: tag.title,
          artist: tag.artist,
          album: tag.album,
          artPath: null,
        );
      }
    } catch (_) {}

    return null;
  }

  MediaItemTag? get currentTag {
    final idx = _player.currentIndex;
    if (idx == null) return null;
    return tagOfIndex(idx);
  }
}

/// Metadata carried with each audio source (UI ke liye).
class MediaItemTag {
  final String id;
  final String? title;
  final String? artist;
  final String? album;
  final String? artPath;

  MediaItemTag({
    required this.id,
    this.title,
    this.artist,
    this.album,
    this.artPath,
  });
}
