part of '../folder_detail_screen.dart';

/// -------------------- MINI PLAYER (with swipe + cut) --------------------
class _MiniPlayer extends StatefulWidget {
  const _MiniPlayer();

  @override
  State<_MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<_MiniPlayer> {
  @override
  Widget build(BuildContext context) {
    final player = PlayerManager.I.player;

    return ValueListenableBuilder<bool>(
      valueListenable: homeMiniVisible,
      builder: (context, isVisible, _) {
        if (!isVisible) return const SizedBox.shrink();

        return SafeArea(
          top: false,
          child: StreamBuilder<SequenceState?>(
            stream: player.sequenceStateStream,
            builder: (context, snap) {
              final seqState = snap.data;
              final idx = player.currentIndex ?? -1;
              final list = PlayerManager.I.currentPlaylist();

              if (seqState == null || list.isEmpty || idx < 0 || idx >= list.length) {
                return const SizedBox.shrink();
              }

              final song = list[idx];
              final title =
              song.title.isNotEmpty ? song.title : p.basename(song.data);
              final artist = (song.artist == null ||
                  song.artist!.toLowerCase() == '<unknown>')
                  ? 'Unknown artist'
                  : song.artist!;

              return Container(
                margin: EdgeInsets.fromLTRB(8, _kMiniOuterV, 8, _kMiniOuterV),
                height: _kMiniPlayerHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFF3b2d20).withAlpha((0.95 * 255).round()),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: GestureDetector(
                  onHorizontalDragEnd: (details) async {
                    final v = details.primaryVelocity ?? 0;
                    if (v < -50) {
                      await player.seekToNext();
                      await player.play();
                    } else if (v > 50) {
                      await player.seekToPrevious();
                      await player.play();
                    }
                  },
                  onTap: () {
                    final pl = PlayerManager.I.currentPlaylist();
                    final current = PlayerManager.I.player.currentIndex ?? 0;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NowPlayingScreen(
                          playlist: pl,
                          startIndex: current,
                          startPlayback: false,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 46,
                          height: 46,
                          child: QueryArtworkWidget(
                            id: song.id,
                            type: ArtworkType.AUDIO,
                            nullArtworkWidget: Container(
                              color: Colors.white10,
                              child: const Icon(Icons.music_note,
                                  color: Colors.white70),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: StreamBuilder<bool>(
                          stream: player.playingStream,
                          builder: (_, s) => Icon(
                            (s.data ?? false)
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 28,
                          ),
                        ),
                        onPressed: () => PlayerManager.I.togglePlayPause(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded, size: 26),
                        onPressed: () async {
                          await player.seekToNext();
                          await player.play();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22),
                        onPressed: () async {
                          homeMiniVisible.value = false;
                          await player.stop();
                        },
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
