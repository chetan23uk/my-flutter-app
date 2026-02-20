import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';

class MediaDeleteService {
  static const MethodChannel _channel = MethodChannel('youplay/media_delete');

  static Future<bool> deleteUris(List<String> uriStrings) async {
    if (uriStrings.isEmpty) return true;

    try {
      final bool? result = await _channel.invokeMethod<bool>(
        'deleteUris',
        {'uris': uriStrings},
      );
      return result ?? false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  // ✅ ADD: deleteSongs method (DELETE KE DONO METHOD RAHENGE)
  static Future<bool> deleteSongs(dynamic context, List<SongModel> songs) async {
    final uris = songs.map((s) => s.uri ?? "").where((u) => u.isNotEmpty).toList();
    return await deleteUris(uris);
  }
}
