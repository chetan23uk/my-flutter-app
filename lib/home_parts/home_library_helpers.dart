part of '../home_screen.dart';

extension _HomeLibraryHelpersExt on _HomeScreenState {
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
