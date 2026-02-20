import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../ads/interstitial_helper.dart';
import '../ads/ad_ids.dart';
import '../ads/banner_ad_widget.dart';
import '../ads/banner_plan.dart';
import '../playing_manager.dart';
import '../now_playing_screen.dart';
import '../services/media_delete.dart';
import 'song_picker_screen.dart';

import '../home_screen.dart'; // homeMiniVisible + HomeMiniPlayer
// ✅ InterstitialHelper import (Ensure path is correct)

class PlaylistDetailScreen extends StatefulWidget {
  final PlaylistModel playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  Future<List<SongModel>>? _songsFuture;

  @override
  void initState() {
    super.initState();
    _reloadSongs();
  }

  void _reloadSongs() {
    _songsFuture = _audioQuery.queryAudiosFrom(
      AudiosFromType.PLAYLIST,
      widget.playlist.id,
    );
    if (mounted) setState(() {});
  }

  Future<void> _ensureWritePerm() async {
    // ✅ best effort (different android versions)
    if (await Permission.audio.isDenied) await Permission.audio.request();
    if (await Permission.storage.isDenied) await Permission.storage.request();
  }

  Widget _artwork(SongModel s) {
    final albumId = s.albumId ?? 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 46,
        height: 46,
        child: QueryArtworkWidget(
          id: albumId != 0 ? albumId : s.id,
          type: albumId != 0 ? ArtworkType.ALBUM : ArtworkType.AUDIO,
          nullArtworkWidget: Container(
            color: Colors.white10,
            child: const Icon(Icons.music_note, color: Colors.white70),
          ),
          errorBuilder: (_, __, ___) => Container(
            color: Colors.white10,
            child: const Icon(Icons.music_note, color: Colors.white70),
          ),
        ),
      ),
    );
  }

  Future<void> _removeFromPlaylist(SongModel s) async {
    await _ensureWritePerm();

    // ✅ ADD: index-based stability
    try {
      final currentSongs = await _audioQuery.queryAudiosFrom(
        AudiosFromType.PLAYLIST,
        widget.playlist.id,
      );
      final index = currentSongs.indexWhere((song) => song.id == s.id);
      if (index == -1) {
        // do nothing here
      }
    } catch (_) {}

    bool ok = false;
    try {
      final dynamic res =
      await _audioQuery.removeFromPlaylist(widget.playlist.id, s.id);
      ok = (res == true) || (res is int && res == 1);
    } catch (_) {
      ok = false;
    }

    if (!mounted) return;

    if (ok) {
      _reloadSongs();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from playlist')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Remove failed (playlist permission / system playlist)'),
        ),
      );
    }
  }

  // ✅ Updated with Interstitial Ad
  void _goToPicker() async {
    await InterstitialHelper.instance.tryShow();
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SongPickerScreen(
          playlistId: widget.playlist.id,
          playlistName: widget.playlist.playlist,
        ),
      ),
    ).then((_) {
      homeMiniVisible.value = true;
      _reloadSongs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.playlist),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _goToPicker, // ✅ Ad logic handled inside method
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<SongModel>>(
              future: _songsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final songs = snapshot.data ?? const <SongModel>[];

                if (songs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.music_note_outlined,
                            size: 80, color: Colors.white24),
                        const SizedBox(height: 16),
                        Text('home_no_songs'.tr(),
                            style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _goToPicker,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Songs'),
                        ),
                      ],
                    ),
                  );
                }

                final int len = songs.length;
                final int bannerCount = BannerPlan.bannerCountForItems(len);
                final plan = BannerPlan.build(items: len, banners: bannerCount);

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: plan.totalCount,
                  itemBuilder: (context, i) {
                    final bool isAd = plan.isAdIndex(i);

                    if (isAd) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: BannerAdWidget(
                          adUnitId: AdIds.banner,
                          placement: 'playlist_detail',
                          slot: plan.slotForListIndex(i),
                        ),
                      );
                    }

                    final int realIdx = plan.dataIndexFromListIndex(i);

                    if (realIdx < 0 || realIdx >= songs.length) {
                      return const SizedBox.shrink();
                    }

                    final s = songs[realIdx];

                    return ListTile(
                      leading: _artwork(s),
                      title: Text(s.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(s.artist ?? 'Unknown Artist',
                          maxLines: 1, overflow: TextOverflow.ellipsis),

                      // ✅ NO Ad here (Play flow smooth rakhne ke liye)
                      onTap: () async {
                        homeMiniVisible.value = true;
                        final nav = Navigator.of(context);

                        try {
                          await PlayerManager.I.playPlaylist(songs, realIdx);
                          if (!context.mounted) return;

                          nav.push(
                            MaterialPageRoute(
                              builder: (_) => NowPlayingScreen(
                                playlist: songs,
                                startIndex: realIdx,
                                startPlayback: false,
                              ),
                            ),
                          ).then((_) => homeMiniVisible.value = true);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Playlist play failed: $e")),
                          );
                        }
                      },

                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) async {
                          if (value == 'share') {
                            // ✅ Add Ad before sharing
                            await InterstitialHelper.instance.tryShow();
                            if (!mounted) return;

                            await Share.shareXFiles(
                              [XFile(s.data)],
                              text: 'Check out this song: ${s.title}',
                            );
                          } else if (value == 'remove') {
                            // ✅ No Ad here (Smooth removal)
                            await _removeFromPlaylist(s);
                          } else if (value == 'delete') {
                            final deleted =
                            await MediaDeleteService.deleteSongs(context, [s]);
                            if (!mounted) return;
                            if (deleted) _reloadSongs();
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share_outlined, size: 20),
                                SizedBox(width: 8),
                                Text('Share Song'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.playlist_remove, size: 20),
                                SizedBox(width: 8),
                                Text('Remove from Playlist'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline,
                                    color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text('Delete from Device',
                                    style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ✅ mini player at bottom
          ValueListenableBuilder<bool>(
            valueListenable: homeMiniVisible,
            builder: (context, visible, _) {
              if (!visible) return const SizedBox.shrink();
              return const HomeMiniPlayer();
            },
          ),
        ],
      ),
    );
  }
}
