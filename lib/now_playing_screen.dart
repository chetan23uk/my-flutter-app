// lib/now_playing_screen.dart
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'ads/ad_ids.dart';
import 'ads/banner_ad_widget.dart';
import 'audio_utils.dart';
import 'playing_manager.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdaptiveBanner extends StatefulWidget {
  const AdaptiveBanner({
    super.key,
    required this.adUnitId,
    this.fallback = AdSize.banner,
  });

  final String adUnitId;
  final AdSize fallback;

  @override
  State<AdaptiveBanner> createState() => _AdaptiveBannerState();
}

class _AdaptiveBannerState extends State<AdaptiveBanner> {
  AdSize? _size;
  int? _lastWidth;

  Future<void> _resolveSize(int width) async {
    if (_lastWidth == width) return;
    _lastWidth = width;

    try {
      final s = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
      if (!mounted) return;
      setState(() => _size = s ?? widget.fallback);
    } catch (_) {
      if (!mounted) return;
      setState(() => _size = widget.fallback);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.isFinite ? c.maxWidth.floor() : 0;
        if (w > 0) {
          _resolveSize(w);
        }
        return BannerAdWidget(
          adUnitId: widget.adUnitId,
          size: _size ?? widget.fallback,
        );
      },
    );
  }
}

class NowPlayingScreen extends StatefulWidget {
  static const routeName = '/now';

  final List<SongModel>? playlist;
  final int? startIndex;
  final bool startPlayback;

  const NowPlayingScreen({
    super.key,
    this.playlist,
    this.startIndex,
    this.startPlayback = true,
  });

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  AudioPlayer get _player => PlayerManager.I.player;

  @override
  void initState() {
    super.initState();
    _spinCtrl =
    AnimationController(vsync: this, duration: const Duration(seconds: 18))
      ..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.playlist != null && widget.playlist!.isNotEmpty) {
        final idx = math.max(0, widget.startIndex ?? 0);

        if (widget.startPlayback) {
          PlayerManager.I.playPlaylist(widget.playlist!, idx);
          return;
        }

        final current = PlayerManager.I.currentPlaylist();
        final currentIndex = _player.currentIndex ?? -1;

        final List<int> currIds = current.map((e) => e.id).toList();
        final List<int> newIds = widget.playlist!.map((e) => e.id).toList();
        final bool samePlaylist = listEquals(currIds, newIds);

        if (!samePlaylist || currentIndex != idx) {
          PlayerManager.I.playPlaylist(widget.playlist!, idx);
        }
      }
    });

    _player.playerStateStream.listen((_) {
      if (mounted) setState(() {});
    });
    _player.currentIndexStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  SongModel? get _currentSong {
    final list = PlayerManager.I.currentPlaylist();
    final idx = PlayerManager.I.player.currentIndex;
    if (list.isEmpty || idx == null || idx < 0 || idx >= list.length) return null;
    return list[idx];
  }

  MediaItem? get _currentMediaItem {
    try {
      final seq = _player.sequence;
      final idx = _player.currentIndex;
      if (seq == null || idx == null || idx < 0 || idx >= seq.length) return null;
      final tag = seq[idx].tag;
      return tag is MediaItem ? tag : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _player.playing;
    final song = _currentSong;
    final media = _currentMediaItem;

    final title = song != null ? cleanTitle(song) : (media?.title.isNotEmpty == true ? media!.title : 'Unknown');
    final artist = song != null ? artistOf(song) : (media?.artist?.isNotEmpty == true ? media!.artist! : 'Received');

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {
                        final s = _currentSong;
                        if (s != null) { _openSongDetailsSheet(s); return; }
                        final m = _currentMediaItem;
                        if (m != null) { _openMediaDetailsSheet(m); return; }
                      },
                    ),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: AdaptiveBanner(adUnitId: AdIds.banner),
                ),

                // Title & Artist
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                          Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white60)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        if (song != null) {
                          PlayerManager.I.toggleFavorite(song);
                          setState(() {});
                        }
                      },
                      icon: Icon(
                        PlayerManager.I.isFavorite(song) ? Icons.favorite : Icons.favorite_border,
                        color: PlayerManager.I.isFavorite(song) ? Colors.redAccent : Colors.white,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Album Art Progress
                Center(
                  child: SizedBox(
                    width: 260,
                    height: 260,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const SizedBox(width: 260, height: 260, child: CircularProgressIndicator(value: 1, strokeWidth: 6, valueColor: AlwaysStoppedAnimation(Colors.white12))),
                        StreamBuilder<Duration>(
                          stream: _player.positionStream,
                          builder: (_, snap) {
                            final pos = snap.data ?? Duration.zero;
                            final total = _player.duration ?? Duration.zero;
                            final progress = total.inMilliseconds == 0 ? 0.0 : pos.inMilliseconds / total.inMilliseconds;
                            return SizedBox(width: 260, height: 260, child: CircularProgressIndicator(value: progress.clamp(0.0, 1.0), strokeWidth: 6, valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary)));
                          },
                        ),
                        RotationTransition(
                          turns: _spinCtrl,
                          child: Container(width: 230, height: 230, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white12, width: 2))),
                        ),
                        ClipOval(
                          child: SizedBox(
                            width: 210, height: 210,
                            child: (song == null)
                                ? Container(color: Colors.white10, child: const Icon(Icons.music_note, color: Colors.white70, size: 54))
                                : QueryArtworkWidget(id: song.id, type: ArtworkType.AUDIO, keepOldArtwork: true, nullArtworkWidget: Container(color: Colors.white10, child: const Icon(Icons.music_note, color: Colors.white70, size: 28))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const AdaptiveBanner(adUnitId: AdIds.banner),

                // Timer Text
                StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (_, snap) {
                    final pos = snap.data ?? Duration.zero;
                    final total = _player.duration ?? Duration.zero;
                    return Center(child: Text('${_mmss(pos)} / ${_mmss(total)}', style: const TextStyle(color: Colors.white60)));
                  },
                ),

                const SizedBox(height: 24),

                // Slider
                StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (_, snap) {
                    final pos = snap.data ?? Duration.zero;
                    final total = _player.duration ?? Duration.zero;
                    final max = total.inMilliseconds.clamp(0, 86400000).toDouble();
                    return Slider(
                      min: 0, max: max, value: pos.inMilliseconds.clamp(0, max).toDouble(),
                      onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt())),
                      activeColor: Theme.of(context).colorScheme.primary,
                    );
                  },
                ),

                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(icon: Icon(Icons.shuffle, color: _player.shuffleModeEnabled ? Theme.of(context).colorScheme.primary : null), onPressed: () async { await _player.setShuffleModeEnabled(!_player.shuffleModeEnabled); setState(() {}); }),
                    IconButton(iconSize: 28, icon: const Icon(Icons.skip_previous_rounded), onPressed: _player.hasPrevious ? _player.seekToPrevious : null),
                    GestureDetector(
                      onTap: () async { await PlayerManager.I.togglePlayPause(); setState(() {}); },
                      child: Container(width: 72, height: 72, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white), child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 42, color: Colors.black)),
                    ),
                    IconButton(iconSize: 28, icon: const Icon(Icons.skip_next_rounded), onPressed: _player.hasNext ? _player.seekToNext : null),
                    IconButton(icon: Icon(_player.loopMode == LoopMode.one ? Icons.repeat_one : Icons.repeat, color: _player.loopMode == LoopMode.off ? null : Theme.of(context).colorScheme.primary), onPressed: () async { final next = _player.loopMode == LoopMode.off ? LoopMode.one : (_player.loopMode == LoopMode.one ? LoopMode.all : LoopMode.off); await _player.setLoopMode(next); setState(() {}); }),
                  ],
                ),

                const SizedBox(height: 16),
                Text('now_next_songs_title'.tr(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),

                // Next Songs List with Ad after 7 items
                (widget.playlist == null)
                    ? StreamBuilder<SequenceState?>(
                  stream: _player.sequenceStateStream,
                  builder: (_, snap) {
                    final seq = snap.data?.sequence ?? [];
                    final items = seq.map((e) => e.tag).whereType<MediaItem>().toList();
                    final count = items.isEmpty ? seq.length : items.length;
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: count + (count > 7 ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == 7) return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: AdaptiveBanner(adUnitId: AdIds.banner));
                        final actualIdx = i > 7 ? i - 1 : i;
                        final it = items.isNotEmpty ? items[actualIdx] : null;
                        return ListTile(
                          leading: const Icon(Icons.music_note),
                          title: Text(it?.title ?? 'Track ${actualIdx + 1}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(it?.artist ?? 'Received', maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () => _player.seek(Duration.zero, index: actualIdx),
                        );
                      },
                    );
                  },
                )
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.playlist!.length + (widget.playlist!.length > 7 ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == 7) return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: AdaptiveBanner(adUnitId: AdIds.banner));
                    final actualIdx = i > 7 ? i - 1 : i;
                    final s = widget.playlist![actualIdx];
                    return ListTile(
                      leading: const Icon(Icons.music_note),
                      title: Text(cleanTitle(s), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(artistOf(s), maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => _player.seek(Duration.zero, index: actualIdx),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Details Sheets Helpers
  void _openSongDetailsSheet(SongModel song) { /* ... same as before ... */ }
  void _openMediaDetailsSheet(MediaItem item) { /* ... same as before ... */ }
  String _mmss(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}