import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'audio_utils.dart';

typedef SongMenuAction = void Function(String actionKey, SongModel song);

class SongTile extends StatelessWidget {
  final SongModel song;
  final VoidCallback onTap;
  final SongMenuAction? onMenu;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final title = cleanTitle(song);
    final artist = artistOf(song);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 52,
                height: 52,
                child: QueryArtworkWidget(
                  id: song.id,
                  type: ArtworkType.AUDIO,
                  keepOldArtwork: true,
                  nullArtworkWidget: Container(
                    color: Colors.white10,
                    child: const Icon(Icons.music_note, color: Colors.white70),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fmtDur(song.duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (v) => onMenu?.call(v, song),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'play_next', child: Text('Play next')),
                    PopupMenuItem(value: 'add_queue', child: Text('Add to queue')),
                    PopupMenuItem(value: 'details', child: Text('Details')),
                    PopupMenuItem(value: 'share', child: Text('Share')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}