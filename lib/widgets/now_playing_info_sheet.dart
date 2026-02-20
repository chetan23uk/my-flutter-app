import 'dart:io';

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path/path.dart' as p;

import '../audio_utils.dart';

class NowPlayingInfoSheet {
  /// Show info sheet for current playing item.
  /// - If [song] provided -> shows SongModel details.
  /// - Else if [mediaItem] provided -> shows MediaItem details (received/open-with).
  static Future<void> show(
      BuildContext context, {
        SongModel? song,
        MediaItem? mediaItem,
      }) async {
    if (song == null && mediaItem == null) return;

    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1B1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          builder: (context, scrollCtrl) {
            return _SheetBody(
              song: song,
              mediaItem: mediaItem,
              scrollCtrl: scrollCtrl,
            );
          },
        );
      },
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.song,
    required this.mediaItem,
    required this.scrollCtrl,
  });

  final SongModel? song;
  final MediaItem? mediaItem;
  final ScrollController scrollCtrl;

  String _fmtBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double b = bytes.toDouble();
    int i = 0;
    while (b >= 1024 && i < units.length - 1) {
      b /= 1024;
      i++;
    }
    final v = (i == 0) ? b.toStringAsFixed(0) : b.toStringAsFixed(2);
    return '$v ${units[i]}';
  }

  bool _isContentUri(String s) => s.startsWith('content://');

  Future<_FileMeta?> _fileMetaForSong(SongModel s) async {
    final path = s.data;
    if (_isContentUri(path)) return null;
    try {
      final f = File(path);
      if (!await f.exists()) return null;
      final stat = await f.stat();
      return _FileMeta(sizeBytes: stat.size);
    } catch (_) {
      return null;
    }
  }

  Future<_FileMeta?> _fileMetaForMedia(MediaItem m) async {
    // MediaItem.id often contains a uri string
    final id = m.id;
    if (id.startsWith('content://')) return null;

    try {
      Uri u;
      if (id.startsWith('file://') || id.startsWith('content://')) {
        u = Uri.parse(id);
      } else {
        // best effort: treat as file path
        u = Uri.file(id);
      }

      if (u.scheme != 'file') return null;
      final f = File(u.toFilePath());
      if (!await f.exists()) return null;
      final stat = await f.stat();
      return _FileMeta(sizeBytes: stat.size);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final headerTitle = song != null
        ? cleanTitle(song!)
        : (mediaItem?.title.isNotEmpty == true ? mediaItem!.title : 'Unknown');

    final headerArtist = song != null
        ? artistOf(song!)
        : ((mediaItem?.artist?.isNotEmpty ?? false) ? mediaItem!.artist! : 'Received');

    final bg = Colors.white.withValues(alpha: 0.06);
    final border = Colors.white.withValues(alpha: 0.10);

    return Column(
      children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white70),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Song details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // Header card (artwork + name)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: song != null
                        ? QueryArtworkWidget(
                      id: song!.id,
                      type: ArtworkType.AUDIO,
                      nullArtworkWidget: Container(
                        color: Colors.white.withValues(alpha: 0.10),
                        child: const Icon(Icons.music_note, color: Colors.white70),
                      ),
                    )
                        : Container(
                      color: Colors.white.withValues(alpha: 0.10),
                      child: const Icon(Icons.music_note, color: Colors.white70),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headerTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        headerArtist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        Expanded(
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            children: [
              if (song != null) ..._buildSongDetails(context, song!, bg, border),
              if (song == null && mediaItem != null)
                ..._buildMediaDetails(context, mediaItem!, bg, border),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSongDetails(
      BuildContext context,
      SongModel s,
      Color bg,
      Color border,
      ) {
    final path = s.data;
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    final type = ext.isEmpty ? 'unknown' : ext;
    final uri = (s.uri ?? '').trim();

    return [
      _kvCard(bg, border, children: [
        _kvRow('Title', cleanTitle(s)),
        _kvRow('Artist', artistOf(s)),
        _kvRow('Album', albumOf(s)),
        _kvRow('Duration', fmtDur(s.duration)),
      ]),
      const SizedBox(height: 10),

      _kvCard(bg, border, children: [
        _kvRow('Location', path),
        if (uri.isNotEmpty) _kvRow('URI', uri),
        _kvRow('Type', type),
        _kvRow('Song ID', s.id.toString()),
      ]),
      const SizedBox(height: 10),

      FutureBuilder<_FileMeta?>(
        future: _fileMetaForSong(s),
        builder: (context, snap) {
          final meta = snap.data;
          return _kvCard(bg, border, children: [
            _kvRow('Size', meta == null ? 'Unknown' : _fmtBytes(meta.sizeBytes)),
            _kvRow('Content URI', _isContentUri(path) ? 'Yes' : 'No'),
          ]);
        },
      ),
    ];
  }

  List<Widget> _buildMediaDetails(
      BuildContext context,
      MediaItem m,
      Color bg,
      Color border,
      ) {
    final id = m.id;
    String type = 'unknown';
    try {
      final maybePath = id.startsWith('file://') ? Uri.parse(id).toFilePath() : id;
      final ext = p.extension(maybePath).replaceFirst('.', '').toLowerCase();
      if (ext.isNotEmpty) type = ext;
    } catch (_) {}

    return [
      _kvCard(bg, border, children: [
        _kvRow('Title', (m.title.isNotEmpty ? m.title : 'Unknown')),
        _kvRow('Artist', (m.artist?.isNotEmpty ?? false) ? m.artist! : 'Received'),
        _kvRow('Album', (m.album?.isNotEmpty ?? false) ? m.album! : 'Unknown'),
      ]),
      const SizedBox(height: 10),

      _kvCard(bg, border, children: [
        _kvRow('ID / URI', id),
        _kvRow('Type', type),
      ]),
      const SizedBox(height: 10),

      FutureBuilder<_FileMeta?>(
        future: _fileMetaForMedia(m),
        builder: (context, snap) {
          final meta = snap.data;
          return _kvCard(bg, border, children: [
            _kvRow('Size', meta == null ? 'Unknown' : _fmtBytes(meta.sizeBytes)),
            _kvRow('Content URI', id.startsWith('content://') ? 'Yes' : 'No'),
          ]);
        },
      ),
    ];
  }

  Widget _kvCard(Color bg, Color border, {required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(children: children),
    );
  }

  Widget _kvRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              k,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileMeta {
  final int sizeBytes;
  _FileMeta({required this.sizeBytes});
}
