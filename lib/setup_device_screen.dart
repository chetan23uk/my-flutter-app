// lib/setup_device_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

import 'services/local_playlists.dart';
import 'services/media_library.dart';

class SetupDeviceScreen extends StatelessWidget {
  const SetupDeviceScreen({super.key});

  // ✅ keep server alive while app open (minimal change)
  static WifiShareServer? _server;
  static String? _serverToken;
  static String? _serverIp;
  static int? _serverPort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'setup_device'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // 🎯 Hero graphic (circle + 2 phones + sync icon)
            Center(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary
                      .withAlpha((0.12 * 255).round()),
                ),
                child: const Icon(
                  Icons.sync_rounded,
                  size: 72,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'setup_device_title'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'setup_device_subtitle'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),

            const SizedBox(height: 22),

            _RoleTile(
              label: 'Sender (Old device)',
              icon: Icons.upload_rounded,
              onTap: () => _showRoleSheet(context, isSender: true),
            ),
            const SizedBox(height: 14),
            _RoleTile(
              label: 'Receiver (New device)',
              icon: Icons.download_rounded,
              onTap: () => _showRoleSheet(context, isSender: false),
            ),

            const Spacer(),

            Text(
              'setup_device_note'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Sender / Receiver press hone ke baad bottom sheet
  void _showRoleSheet(BuildContext context, {required bool isSender}) {
    final theme = Theme.of(context);
    final title = isSender ? 'Sender (Old device)' : 'Receiver (New device)';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // ✅ overflow fix
      useSafeArea: true, // ✅ notch/navbar safe
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final controller = TextEditingController();

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: 16 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  Row(
                    children: [
                      Icon(
                        isSender ? Icons.upload_rounded : Icons.download_rounded,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Text(
                    isSender
                        ? 'Is OLD device par hum Wi-Fi transfer start karenge.\nNEW device QR scan karke songs download karega.'
                        : 'Is NEW device par aap OLD device ka QR scan karoge.\nPhir songs yahan download ho jayenge.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (isSender) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await _exportPlaylistsAsQr(sheetContext);
                        },
                        icon: const Icon(Icons.qr_code_2),
                        label: const Text('Show QR (transfer code)'),
                      ),
                    ),
                    if (_server != null && _serverIp != null && _serverPort != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Sender Running:\nIP: $_serverIp\nPort: $_serverPort\nToken: $_serverToken',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ),
                  ] else ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final scanned = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ScanTransferCodeScreen(),
                            ),
                          );
                          if (scanned != null && scanned.isNotEmpty) {
                            await _importPlaylists(context, scanned);

                            if (!sheetContext.mounted) return;
                            if (Navigator.canPop(sheetContext)) {
                              Navigator.pop(sheetContext);
                            }
                          }
                        },
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan QR code'),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: controller,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Paste transfer code yahan…',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await _importPlaylists(
                            context,
                            controller.text.trim(),
                          );

                          if (!sheetContext.mounted) return;
                          if (Navigator.canPop(sheetContext)) {
                            Navigator.pop(sheetContext);
                          }
                        },
                        icon: const Icon(Icons.cloud_download),
                        label: const Text('Import playlists'),
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // ✅ REPLACED: OLD QR = playlist IDs -> base64
  // ✅ NEW QR = {ip,port,token} so receiver can download real files
  // ---------------------------------------------------------------------------

  /// OLD device: start Wi-Fi server, generate QR with ip/port/token
  Future<void> _exportPlaylistsAsQr(BuildContext context) async {
    final theme = Theme.of(context);

    // 1) Read playlists (names -> IDs)
    final data = await LocalPlaylists.instance.getAll();

    if (!context.mounted) return;

    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Is device par koi local playlist nahi mili.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
        ),
      );
      return;
    }

    // 2) Build manifest (files to share)
    //    We map playlist song IDs -> SongModel.data (real file path)
    final library = MediaLibraryService.instance;
    final allSongs = await library.fetchSongs();
    final byId = <int, dynamic>{};
    for (final s in allSongs) {
      byId[s.id as int] = s;
    }

    final filesToShare = <Map<String, dynamic>>[];
    final seen = <String>{};

    data.forEach((playlistName, idSet) {
      for (final id in idSet) {
        final s = byId[id];
        if (s == null) continue;

        final path = (s.data as String?) ?? '';
        if (path.isEmpty) continue;

        // avoid duplicates
        if (seen.add(path)) {
          filesToShare.add({
            'filePath': path,
            'fileName': path.split('/').last,
          });
        }
      }
    });

    if (filesToShare.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Playlists mil gayi, lekin songs ke file paths read nahi ho rahe.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
        ),
      );
      return;
    }

    // 3) Start server (reuse if already running)
    await _server?.stop();
    _serverToken = WifiShareServer.genToken();
    _server = WifiShareServer(token: _serverToken!, manifest: filesToShare);
    await _server!.start();
    _serverPort = _server!.port;
    _serverIp = await WifiShareServer.getLanIp();

    if (_serverIp == null || _serverPort == null) {
      await _server?.stop();
      _server = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Wi-Fi IP detect nahi hua. Dono phone same Wi-Fi par rakhein.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
        ),
      );
      return;
    }

    // 4) QR payload
    final payload = jsonEncode({
      'v': 1,
      'ip': _serverIp,
      'port': _serverPort,
      'token': _serverToken,
    });
    final code = base64UrlEncode(utf8.encode(payload));

    // clipboard copy
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;

    // QR dialog (UI same)
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: const Text('Transfer QR code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: code,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 10),
              const Text(
                'NEW device se is QR ko scan karein.\n(Clipboard me code copy ho chuka hai)',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'IP: $_serverIp\nPort: $_serverPort',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Transfer ready. NEW device se QR scan karein.',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ✅ REPLACED: OLD import = decode playlists IDs -> merge
  // ✅ NEW import = decode {ip,port,token} -> download songs -> save locally
  // ---------------------------------------------------------------------------

  /// NEW device: decode code -> connect -> download songs -> save in app folder
  Future<void> _importPlaylists(BuildContext context, String code) async {
    final theme = Theme.of(context);

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please valid code paste ya scan karein.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
        ),
      );
      return;
    }

    try {
      // 1) decode payload
      final rawBytes = base64Url.decode(code);
      final rawJson = utf8.decode(rawBytes);
      final Map<String, dynamic> decoded = jsonDecode(rawJson);

      final ip = decoded['ip'] as String?;
      final port = decoded['port'];
      final token = decoded['token'] as String?;

      if (ip == null || token == null || port == null) {
        throw Exception('Invalid transfer payload');
      }

      final baseUrl = 'http://$ip:$port';
      final client = WifiReceiverClient(baseUrl: baseUrl, token: token);

      // 2) show progress dialog
      int done = 0;
      int total = 0;

      if (!context.mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dctx) {
          return StatefulBuilder(
            builder: (dctx, setDState) {
              // start download once
              Future<void>(() async {
                if (total != 0) return; // already started

                final manifest = await client.fetchManifest();
                final files = (manifest['files'] as List)
                    .cast<Map<String, dynamic>>();
                total = files.length;
                setDState(() {});

                final dir = await getApplicationDocumentsDirectory();
                final songsDir = Directory('${dir.path}/received_songs');
                if (!await songsDir.exists()) {
                  await songsDir.create(recursive: true);
                }

                final savedPaths = <String>[];

                for (int i = 0; i < files.length; i++) {
                  final name = (files[i]['fileName'] as String?) ?? 'song_$i.mp3';
                  final out = await client.downloadSong(i, name);
                  savedPaths.add(out.path);

                  done = i + 1;
                  setDState(() {});
                }

                // ✅ Save received list (so app can use it)
                // NOTE: To show these in your playlist UI, add small helper in LocalPlaylists (snippet below)
                final playlistName = 'Transferred ${DateTime.now().toIso8601String()}';
                await LocalPlaylists.instance.saveReceivedFiles(playlistName, savedPaths);

// optional: success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Received playlist added: $playlistName')),
                );

                if (Navigator.canPop(dctx)) Navigator.pop(dctx);
              });

              return AlertDialog(
                backgroundColor: theme.colorScheme.surface,
                title: const Text('Receiving songs…'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: (total == 0) ? null : (done / total),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      total == 0
                          ? 'Connecting…'
                          : 'Downloaded $done / $total',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Receive complete. Songs app storage me save ho gaye.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transfer code samajh nahi aaya ya connection fail.\n($e)',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
        ),
      );
    }
  }
}

/// Simple tile
class _RoleTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _RoleTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withAlpha((0.8 * 255).round()),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.primary.withAlpha((0.35 * 255).round()),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha((0.15 * 255).round()),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

/// 👁️ NEW device: QR scan screen
class ScanTransferCodeScreen extends StatefulWidget {
  const ScanTransferCodeScreen({super.key});

  @override
  State<ScanTransferCodeScreen> createState() => _ScanTransferCodeScreenState();
}

class _ScanTransferCodeScreenState extends State<ScanTransferCodeScreen> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan transfer QR'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'QR ko camera ke beech me rakhein. Code detect hote hi use ho jayega.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                if (_handled) return;

                final codes = capture.barcodes;
                if (codes.isEmpty) return;

                final raw = codes.first.rawValue;
                if (raw == null || raw.isEmpty) return;

                _handled = true;
                Navigator.pop(context, raw);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Internal Wi-Fi server/client (single-file approach — no extra files needed)
// ============================================================================

class WifiShareServer {
  HttpServer? _server;
  final String token;

  /// Each item: {filePath, fileName}
  final List<Map<String, dynamic>> manifest;

  WifiShareServer({required this.token, required this.manifest});

  int? get port => _server?.port;

  Future<void> start({int port = 0}) async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.listen(_handle);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  bool _authOk(HttpRequest req) => req.headers.value('x-token') == token;

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
          'files': manifest.map((e) => {'fileName': e['fileName']}).toList(),
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
        req.response.headers
            .set('Content-Length', (await f.length()).toString());
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

class WifiReceiverClient {
  final String baseUrl;
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
