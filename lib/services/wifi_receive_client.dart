import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class WifiReceiverClient {
  final String baseUrl; // e.g. http://192.168.1.8:8080
  final String token;

  WifiReceiverClient({required this.baseUrl, required this.token});

  Future<Map<String, dynamic>> fetchManifest() async {
    final uri = Uri.parse('$baseUrl/manifest');
    final req = await HttpClient().getUrl(uri);
    req.headers.set('x-token', token);

    final res = await req.close();
    if (res.statusCode != 200) {
      throw Exception('Manifest failed: ${res.statusCode}');
    }
    final body = await res.transform(utf8.decoder).join();
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<File> downloadSong(int index, String saveName) async {
    final dir = await getApplicationDocumentsDirectory();
    final songsDir = Directory('${dir.path}/received_songs');
    if (!await songsDir.exists()) await songsDir.create(recursive: true);

    final safeName = saveName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final outFile = File('${songsDir.path}/$safeName');

    final uri = Uri.parse('$baseUrl/file?i=$index');
    final req = await HttpClient().getUrl(uri);
    req.headers.set('x-token', token);

    final res = await req.close();
    if (res.statusCode != 200) {
      throw Exception('Download failed i=$index: ${res.statusCode}');
    }

    final sink = outFile.openWrite();
    await res.pipe(sink);
    await sink.flush();
    await sink.close();

    return outFile;
  }
}
