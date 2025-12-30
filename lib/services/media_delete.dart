import 'package:flutter/services.dart';

class MediaDeleteService {
  static const MethodChannel _channel = MethodChannel('youplay/media_delete');

  static Future<bool> deleteUris(List<String> uriStrings) async {
    if (uriStrings.isEmpty) return true;

    try {
      final bool? result = await _channel.invokeMethod<bool>(
        'deleteUris',
        {'uris': uriStrings},
      );
      // ignore: avoid_print
      print('MediaDelete result=$result firstUri=${uriStrings.first}');
      return result ?? false;
    } on MissingPluginException catch (e) {
      // ignore: avoid_print
      print('MediaDelete MissingPluginException: $e');
      return false;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('MediaDelete PlatformException: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      // ignore: avoid_print
      print('MediaDelete error: $e');
      return false;
    }
  }
}
