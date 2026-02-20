part of '../home_screen.dart';

/// ---------------- HOME MINI PLAYER (swipe + cut) ----------------
class HomeMiniPlayer extends StatelessWidget {
  const HomeMiniPlayer({super.key});

  static const AdSize _fixedAayatSize = AdSize(width: 320, height: 50);

  @override
  Widget build(BuildContext context) {
    final player = PlayerManager.I.player;

    return SafeArea(
      top: false,
      child: StreamBuilder<SequenceState?>(
        stream: player.sequenceStateStream,
        builder: (context, snap) {
          final seqState = snap.data;
          final idx = player.currentIndex ?? -1;

          if (seqState == null || idx < 0 || idx >= seqState.sequence.length) {
            return const SizedBox.shrink();
          }

          final list = PlayerManager.I.currentPlaylist();
          final hasSongModel = list.isNotEmpty && idx < list.length;

          MediaItem? media;
          if (!hasSongModel) {
            final tag = seqState.sequence[idx].tag;
            if (tag is MediaItem) media = tag;
          }

          if (!hasSongModel && media == null) {
            return const SizedBox.shrink();
          }

          final title = hasSongModel
              ? (list[idx].title.isNotEmpty ? list[idx].title : p.basename(list[idx].data))
              : (media!.title.isNotEmpty ? media.title : 'Unknown');

          final artist = hasSongModel
              ? ((list[idx].artist == null || list[idx].artist!.toLowerCase() == '<unknown>')
              ? 'Unknown artist'
              : list[idx].artist!)
              : ((media!.artist?.isNotEmpty ?? false) ? media.artist! : 'Unknown artist');

          return Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NowPlayingScreen(startPlayback: false),
                      ),
                    ).then((value) {
                      homeMiniVisible.value = true;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 46,
                            height: 46,
                            child: hasSongModel
                                ? QueryArtworkWidget(
                              id: list[idx].id,
                              type: ArtworkType.AUDIO,
                              nullArtworkWidget: Container(
                                color: Colors.white10,
                                child: const Icon(Icons.music_note, color: Colors.white70, size: 28),
                              ),
                            )
                                : Container(
                              color: Colors.white10,
                              child: const Icon(Icons.music_note, color: Colors.white70, size: 28),
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
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded),
                          onPressed: player.hasPrevious
                              ? () async {
                            await player.seekToPrevious();
                            await player.play();
                          }
                              : null,
                        ),
                        StreamBuilder<bool>(
                          stream: player.playingStream,
                          builder: (context, playSnap) {
                            final playing = playSnap.data ?? false;
                            return IconButton(
                              icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
                              iconSize: 34,
                              onPressed: () => PlayerManager.I.togglePlayPause(),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded),
                          onPressed: player.hasNext
                              ? () async {
                            await player.seekToNext();
                            await player.play();
                          }
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 22),
                          onPressed: () async {
                            homeMiniVisible.value = false;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Center(
                    child: BannerAdWidget(
                      key: const ValueKey('banner-mini-player'),
                      adUnitId: AdIds.banner,
                      placement: 'mini_player',
                      slot: 9999,
                      size: _fixedAayatSize,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
