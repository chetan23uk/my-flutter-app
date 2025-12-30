import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'playing_manager.dart';

// 🔹 ADS

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  static const double _miniPlayerHeight = 72;

  @override
  Widget build(BuildContext context) {
    final player = PlayerManager.I.player;

    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final isPlaying = state?.playing ?? false;

        if (state == null || state.processingState == ProcessingState.idle) {
          return const SizedBox.shrink();
        }

        return Stack(
          children: [
            // ✅ SLIM AAYAT BANNER (FIXED 320x50 WITH MINI PLAYER)

            // ✅ EXISTING MINI PLAYER (UNCHANGED)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: _miniPlayerHeight,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(230),
                  border: const Border(
                    top: BorderSide(color: Colors.white12),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.music_note, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        player.sequenceState?.currentSource?.tag?.toString() ??
                            'Playing',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        if (isPlaying) {
                          player.pause();
                        } else {
                          player.play();
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () {
                        player.stop();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
