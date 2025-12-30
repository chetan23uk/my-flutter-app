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

  /// Single queue used everywhere in the app.
  final ConcatenatingAudioSource _playlistSource =
  ConcatenatingAudioSource(children: []);

  /// Copy of the songs in [_playlistSource] in the same order.
  final List<SongModel> _currentSongs = [];

  bool _initialized = false;

  // ❤️ FAVORITES (ADDED – nothing else changed)
  final Set<int> _favoriteSongIds = {};

  AudioPlayer get player => _player;

  /// Expose a defensive copy of current playlist for UI.
  List<SongModel> currentPlaylist() => List<SongModel>.from(_currentSongs);

  // ------------------- init -------------------

  Future<void> _ensureInit() async {
    if (_initialized) return;

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Bind player to our queue source.
    await _player.setAudioSource(_playlistSource);
    _initialized = true;
  }

  // ------------------- helpers -------------------

  Uri _uriFromSong(SongModel song) {
    final data = song.data;

    if (data.startsWith('content://') || data.startsWith('file://')) {
      return Uri.parse(data);
    }

    return Uri.file(data);
  }

  /// Convert song -> audio source with BOTH:
  /// - MediaItem tag (notification/lockscreen)
  /// - our own MediaItemTag for UI (via _currentSongs list)
  AudioSource _toSource(SongModel song) {
    final uri = _uriFromSong(song);

    return AudioSource.uri(
      uri,
      tag: MediaItem(
        id: song.id.toString(),
        title: song.title,
        artist: song.artist ?? "Unknown Artist",
        album: song.album ?? "",
        artUri: Uri.file(song.data),
      ),
    );
  }

  // ------------------- public controls -------------------

  /// Replace the whole queue with [songs] and start playing at [startIndex].
  Future<void> playPlaylist(List<SongModel> songs, int startIndex) async {
    await _ensureInit();
    if (songs.isEmpty) return;

    final idx =
    (startIndex < 0 || startIndex >= songs.length) ? 0 : startIndex;

    await _player.stop();
    await _playlistSource.clear();

    _currentSongs
      ..clear()
      ..addAll(songs);

    final sources =
    _currentSongs.map<AudioSource>((s) => _toSource(s)).toList();

    await _player.setAudioSource(
      ConcatenatingAudioSource(children: sources),
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
      // ✅ Prefer URI delete (Android 10/11+ safe)
      final uri = song.uri;
      if (uri != null && uri.isNotEmpty) {
        final ok = await MediaDeleteService.deleteUris([uri]);
        if (ok) return true;
        // if user cancelled on 11+ -> ok=false; don't force delete
        // But Android 9 fallback needs File.delete:
      }

      // ✅ Fallback (Android 9 or when URI method not supported)
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


  // ------------------- ❤️ FAVORITES (ADDED ONLY) -------------------

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

    // ✅ Transferred / file playlist (MediaItem tag from just_audio_background)
    try {
      final seq = _player.sequence;
      if (seq!.isEmpty) return null;
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
  Future<void> playFilePlaylist(List<String> paths, {int startIndex = 0}) async {
    if (paths.isEmpty) return;
    await _ensureInit();

    final children = <AudioSource>[];
    for (final path in paths) {
      final uri = Uri.file(path);
      children.add(AudioSource.uri(
        uri,
        tag: MediaItem(
          id: uri.toString(),
          title: path.split('/').last,
          artist: 'Received',
        ),
      ));
    }

    final src = ConcatenatingAudioSource(children: children);

    await _player.setAudioSource(src, initialIndex: startIndex);
    await _player.play();
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
