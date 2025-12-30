import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;

class MediaLibraryService {
  MediaLibraryService._internal();
  static final MediaLibraryService instance = MediaLibraryService._internal();
  MediaLibraryService() : this._internal();

  final OnAudioQuery _query = OnAudioQuery();

  /// Permission लेता है (अगर नहीं मिली है)
  Future<bool> ensurePermission() async {
    final granted = await _query.permissionsStatus();
    if (!granted) {
      return await _query.permissionsRequest();
    }
    return true;
  }

  /// सारे songs लेकर "folder path -> songs" में group करता है
  Future<Map<String, List<SongModel>>> fetchFolders() async {
    final ok = await ensurePermission();
    if (!ok) return {};

    final songs = await _query.querySongs(
      sortType: SongSortType.DISPLAY_NAME,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    final Map<String, List<SongModel>> byFolder = {};
    for (final s in songs) {
      final dir = p.dirname(s.data);        // /storage/emulated/0/Music/...
      byFolder.putIfAbsent(dir, () => []).add(s);
    }
    return byFolder;
  }

  /// All songs (Songs tab के लिए)
  Future<List<SongModel>> fetchSongs() async {
    final ok = await ensurePermission();
    if (!ok) return [];
    return _query.querySongs(
      sortType: SongSortType.DISPLAY_NAME,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
  }
}