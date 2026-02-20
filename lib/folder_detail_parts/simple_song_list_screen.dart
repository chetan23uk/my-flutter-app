part of '../folder_detail_screen.dart';

/// Minimal list screen so that "Go to album / artist" works out of the box.
class _SimpleSongListScreen extends StatelessWidget {
  final String title;
  final List<SongModel> songs;
  const _SimpleSongListScreen({required this.title, required this.songs});

  String _fmtDur(int? ms) {
    final d = Duration(milliseconds: ms ?? 0);
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        itemCount: songs.length,
        separatorBuilder: (_, __) =>
        const Divider(height: 1, color: Colors.white12, indent: 72),
        itemBuilder: (context, i) {
          final s = songs[i];
          return ListTile(
            leading: QueryArtworkWidget(
              id: s.id,
              type: ArtworkType.AUDIO,
              nullArtworkWidget: const Icon(Icons.music_note),
            ),
            title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              s.artist ?? '<unknown>',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              _fmtDur(s.duration),
              style: const TextStyle(color: Colors.white70),
            ),
            onTap: () async {
              await PlayerManager.I.playPlaylist(songs, i);
              homeMiniVisible.value = true;
            },
          );
        },
      ),
    );
  }
}
