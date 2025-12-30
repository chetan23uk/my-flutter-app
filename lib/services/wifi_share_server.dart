import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

class WifiShareServer {
  HttpServer? _server;
  final String token;

  /// Each item must contain: filePath, fileName
  final List<Map<String, dynamic>> manifest;

  WifiShareServer({
    required this.token,
    required this.manifest,
  });

  int? get port => _server?.port;

  /// NOTE: to show correct IP to user, we’ll compute LAN IP separately
  Future<void> start({int port = 0}) async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.listen(_handle);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  bool _authOk(HttpRequest req) {
    final t = req.headers.value('x-token');
    return t == token;
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      if (!_authOk(req)) {
        req.response.statusCode = HttpStatus.unauthorized;
        req.response.write('Unauthorized');
        await req.response.close();
        return;
      }

      if (req.uri.path == '/manifest') {
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({
          'count': manifest.length,
          'files': manifest.map((e) => {
            'fileName': e['fileName'],
          }).toList(),
        }));
        await req.response.close();
        return;
      }

      if (req.uri.path == '/file') {
        final idxStr = req.uri.queryParameters['i'];
        final i = int.tryParse(idxStr ?? '');
        if (i == null || i < 0 || i >= manifest.length) {
          req.response.statusCode = HttpStatus.badRequest;
          req.response.write('Invalid index');
          await req.response.close();
          return;
        }

        final filePath = manifest[i]['filePath'] as String?;
        if (filePath == null || filePath.isEmpty) {
          req.response.statusCode = HttpStatus.notFound;
          req.response.write('Missing filePath');
          await req.response.close();
          return;
        }

        final f = File(filePath);
        if (!await f.exists()) {
          req.response.statusCode = HttpStatus.notFound;
          req.response.write('File not found');
          await req.response.close();
          return;
        }

        req.response.headers.set('Content-Type', 'application/octet-stream');
        req.response.headers.set('Content-Length', (await f.length()).toString());
        await req.response.addStream(f.openRead());
        await req.response.close();
        return;
      }

      req.response.statusCode = HttpStatus.notFound;
      req.response.write('Not found');
      await req.response.close();
    } catch (e) {
      try {
        req.response.statusCode = 500;
        req.response.write('Error: $e');
        await req.response.close();
      } catch (_) {}
    }
  }

  static String genToken() {
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    return sha256.convert(utf8.encode(now)).toString().substring(0, 16);
  }

  /// Get device LAN IP (common Wi-Fi IP like 192.168.x.x)
  static Future<String?> getLanIp() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    for (final i in interfaces) {
      for (final a in i.addresses) {
        final ip = a.address;
        if (ip.startsWith('192.') || ip.startsWith('10.') || ip.startsWith('172.')) {
          return ip;
        }
      }
    }
    return null;
  }
}
