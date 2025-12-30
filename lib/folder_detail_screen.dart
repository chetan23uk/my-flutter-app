// lib/folder_detail_screen.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;
import 'package:ringtone_set_plus/ringtone_set_plus.dart';
import 'package:share_plus/share_plus.dart';

import 'home_screen.dart';
import 'now_playing_screen.dart';
import 'playing_manager.dart'; // ✅ आपका ही मैनेजर नाम
import 'ads/ad_ids.dart';
import 'ads/banner_ad_widget.dart';

// ---- MiniPlayer layout constants ----
const double _kMiniPlayerHeight = 78; // actual bar height
const double _kMiniOuterV = 6; // mini bar के ऊपर/नीचे का margin (प्रत्येक side)



// ListView के लिए जितनी bottom space रिज़र्व करनी है
double _miniReserve(BuildContext c) {
  final inset = MediaQuery.of(c).padding.bottom; // SafeArea bottom
  return _kMiniPlayerHeight + (_kMiniOuterV * 2) + inset;
}

class FolderDetailScreen extends StatefulWidget {
  static const routeName = '/folder-detail';

  final String folderName;
  final String folderPath;
  final List<SongModel> songs;

  const FolderDetailScreen({
    super.key,
    required this.folderName,
    required this.folderPath,
    required this.songs,
  });

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  // ---------------- Ads placement ----------------
// every 7 items

  late List<SongModel> _list; // full sorted list
  String _query = '';

  @override
  void initState() {
    super.initState();
    _list = [...widget.songs]
      ..sort((a, b) =>
          _cleanTitle(a).toLowerCase().compareTo(_cleanTitle(b).toLowerCase()));
  }

  // ---------- helpers ----------
  String _cleanTitle(SongModel s) {
    final t = (s.title.isNotEmpty && s.title.toLowerCase() != '<unknown>')
        ? s.title
        : p.basenameWithoutExtension(s.data);
    return t.replaceAll('_', ' ').trim();
  }

  String _artistOf(SongModel s) {
    final a = s.artist ?? '';
    if (a.isEmpty || a.toLowerCase() == '<unknown>') return 'Unknown artist';
    return a;
  }

  String _fmtDur(int? ms) {
    final d = Duration(milliseconds: ms ?? 0);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  List<SongModel> get _filtered {
    if (_query.trim().isEmpty) return _list;
    final q = _query.toLowerCase();
    return _list.where((s) {
      return _cleanTitle(s).toLowerCase().contains(q) ||
          _artistOf(s).toLowerCase().contains(q);
    }).toList();
  }
  late final bottomInset = MediaQuery.of(context).padding.bottom;

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: _SearchBar(
          initial: _query,
          hint: 'Search in ${widget.folderName}',
          onChanged: (v) => setState(() => _query = v),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          // subtle top gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment(0, .25),
                  colors: [Color(0xFF1E1B1C), Colors.transparent],
                ),
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + count
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.folderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .2,
                        ),
                      ),
                    ),
                    Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${items.length} ${items.length == 1 ? "track" : "tracks"}',
                        style:
                        const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await Future<void>.delayed(const Duration(milliseconds: 250));
                    if (mounted) setState(() {});
                  },
                  child: Scrollbar(
                    thickness: 3,
                    radius: const Radius.circular(8),
                    child: Builder(
                      builder: (context) {
                        final int len = items.length;
                        const int k = 7; // Har 7 items ke baad ad

                        // Logic: Agar 1-6 gaane hain to last mein 1 ad, agar 7+ hain to har 7 ke baad ad
                        final bool showSingleAd = len > 0 && len < k;
                        final int adCount = (len >= k) ? (len ~/ k) : (showSingleAd ? 1 : 0);
                        final int totalCount = len + adCount;

                        return ListView.separated(
                          padding: EdgeInsets.only(
                            // ✅ MiniPlayer + SafeArea का exact reserve
                            bottom: _miniReserve(context),
                          ),
                          itemCount: totalCount,
                          separatorBuilder: (_, i) {
                            // Ad ke pehle ya baad wale divider ko hide karna
                            final bool isCurrentAd = (len >= k)
                                ? ((i + 1) % (k + 1) == 0)
                                : (showSingleAd && i == totalCount - 1);

                            final bool isNextAd = (len >= k)
                                ? ((i + 2) % (k + 1) == 0)
                                : false;

                            if (isCurrentAd || isNextAd) return const SizedBox.shrink();

                            return const Divider(
                              height: 1,
                              color: Colors.white12,
                              indent: 80,
                            );
                          },
                          itemBuilder: (context, i) {
                            // ✅ AD Check
                            final bool isAd = (len >= k)
                                ? ((i + 1) % (k + 1) == 0)
                                : (showSingleAd && i == totalCount - 1);

                            if (isAd) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: BannerAdWidget(
                                  adUnitId: AdIds.banner,
                                ),
                              );
                            }

                            // ✅ Real Index calculation
                            final int adsBefore = (len >= k) ? ((i + 1) ~/ (k + 1)) : 0;
                            final int realIndex = i - adsBefore;

                            if (realIndex < 0 || realIndex >= len) return const SizedBox.shrink();

                            final s = items[realIndex];
                            final title = _cleanTitle(s);
                            final artist = _artistOf(s);

                            return InkWell(
                              onTap: () {
                                ScaffoldMessenger.of(context).clearSnackBars();

                                // ✅ koi song play ho to mini player wapas show ho
                                homeMiniVisible.value = true;

                                final startIndex = _list.indexOf(s);
                                PlayerManager.I.playPlaylist(_list, startIndex);

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => NowPlayingScreen(
                                      playlist: _list,
                                      startIndex: math.max(0, startIndex),
                                    ),
                                  ),
                                ).then((_) {
                                  // Jab NowPlaying se wapas aayein tab bhi mini player dikhe
                                  homeMiniVisible.value = true;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Artwork
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        width: 52,
                                        height: 52,
                                        child: QueryArtworkWidget(
                                          id: s.id,
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

                                    // Title + artist
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            artist,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Duration + 3-dots
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _fmtDur(s.duration),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        IconButton(
                                          icon: const Icon(Icons.more_vert),
                                          onPressed: () => _openSongActions(
                                            context,
                                            s,
                                            title: title,
                                            artist: artist,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ⬇️ MiniPlayer bottom पर, SafeArea के साथ (overflow-free)
          // Home Screen ke Stack ke andar
          Stack(
            children: [
              // Aapke baaki widgets (Body, etc.)

              // ✅ Mini Player + Ad group
              ValueListenableBuilder<bool>(
                valueListenable: homeMiniVisible,
                builder: (context, visible, _) {
                  if (!visible) return const SizedBox.shrink();

                  return Positioned(
                    left: 0,
                    right: 0,
                    bottom: MediaQuery.of(context).padding.bottom + 10,
                    child: const HomeMiniPlayer(), // Jo aapne Home Screen mein banaya hai
                  );
                },
              ),
            ],
          )
        ],
      ),
    );
  }

  // ---------- Bottom Sheet ----------
  void _openSongActions(BuildContext context, SongModel song,
      {required String title, required String artist}) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true, // draggable + full-height feel
      backgroundColor: const Color(0xFF1E1B1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.40,
          maxChildSize: 0.90,
          builder: (context, scrollCtrl) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                // drag-handle
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 8),

                // Header tile
                ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 48,
                      height: 48,
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
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const Divider(height: 1, color: Colors.white12),

                // Options (scrollable)
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: EdgeInsets.zero,
                    children: [
                      _sheetTile(Icons.play_arrow_rounded, 'Play next',
                              () async {
                            await PlayerManager.I.playNext(song);
                            if (mounted) {
                              Navigator.pop(context);
                              _toast('Will play next');
                            }
                          }),
                      _sheetTile(Icons.queue_music_rounded, 'Add to queue',
                              () async {
                            await PlayerManager.I.addToQueue(song);
                            if (mounted) {
                              Navigator.pop(context);
                              _toast('Added to queue');
                            }
                          }),
                      _sheetTile(
                          Icons.playlist_add_rounded, 'Add to playlist',
                              () async {
                            await PlayerManager.I.addPlaylist([song]);
                            if (mounted) {
                              Navigator.pop(context);
                              _toast('Added to current playlist');
                            }
                          }),
                      _sheetTile(Icons.album_rounded, 'Go to album', () {
                        final album = song.album ?? '';
                        final list =
                        _list.where((e) => (e.album ?? '') == album).toList();
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _SimpleSongListScreen(
                              title: album.isEmpty ? 'Unknown album' : album,
                              songs: list,
                            ),
                          ),
                        );
                      }),
                      _sheetTile(Icons.person_rounded, 'Go to artist', () {
                        final artist = song.artist ?? '';
                        final list = _list
                            .where((e) => (e.artist ?? '') == artist)
                            .toList();
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _SimpleSongListScreen(
                              title:
                              artist.isEmpty ? 'Unknown artist' : artist,
                              songs: list,
                            ),
                          ),
                        );
                      }),
                      _sheetTile(Icons.share_rounded, 'Share', () async {
                        try {
                          await Share.shareXFiles([XFile(song.data)],
                              text: _cleanTitle(song));
                        } catch (_) {
                          await Share.share(song.data);
                        }
                        if (mounted) Navigator.pop(context);
                      }),
                      _sheetTile(Icons.music_note_rounded, 'Set as ringtone', () async {
                        try {
                          final file = File(song.data); // on_audio_query ka local path

                          if (await file.exists()) {
                            // 👉 Default phone ringtone set karega
                            await RingtoneSet.setRingtoneFromFile(file);

                            if (mounted) _toast('Ringtone set successfully');
                          } else {
                            if (mounted) _toast('Audio file not found');
                          }
                        } catch (e) {
                          if (mounted) _toast('Failed to set ringtone');
                        }

                        if (mounted) Navigator.pop(context);
                      }),

                      const Divider(height: 1, color: Colors.white12),
                      _sheetTile(Icons.delete_forever_rounded,
                          'Delete from device', () async {
                            final ok = await _confirmDelete(context);
                            if (ok) {
                              final success =
                              await PlayerManager.I.deleteFile(song);
                              if (success) {
                                setState(() => _list
                                    .removeWhere((e) => e.data == song.data));
                                _toast('Deleted');
                              } else {
                                _toast('Delete failed');
                              }
                            }
                            if (mounted) Navigator.pop(context);
                          }, danger: true),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this file?'),
        content:
        const Text('This will permanently remove the audio file.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
            const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ??
        false;
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m)),
    );
  }

  Widget _sheetTile(
      IconData icon, String text, VoidCallback onTap,
      {bool danger = false}) {
    return ListTile(
      leading: Icon(icon,
          color: danger ? const Color(0xFFFF6B6B) : Colors.white),
      title: Text(
        text,
        style: TextStyle(
          color: danger ? const Color(0xFFFF6B6B) : Colors.white,
          fontWeight: danger ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}

/// Simple inline search bar used in the AppBar
class _SearchBar extends StatefulWidget {
  final String initial;
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.initial,
    required this.hint,
    required this.onChanged,
  });

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kToolbarHeight - 12,
      child: TextField(
        controller: _c,
        onChanged: widget.onChanged,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: Colors.white10,
          prefixIcon: const Icon(Icons.search),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

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
            title:
            Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
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
              homeMiniVisible.value = true; // ✅ Gaana chalte hi mini player activate
            },
          );
        },
      ),
    );
  }
}

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
        // agar user ne cut kar diya ho
        if (!isVisible) return const SizedBox.shrink();

        return SafeArea(
          top: false,
          child: StreamBuilder<SequenceState?>(
            stream: player.sequenceStateStream,
            builder: (context, snap) {
              final seqState = snap.data;
              final idx = player.currentIndex ?? -1;
              final list = PlayerManager.I.currentPlaylist();

              if (seqState == null ||
                  list.isEmpty ||
                  idx < 0 ||
                  idx >= list.length) {
                // No active item – मिनीप्लेयर छुपा दो
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
                height: _kMiniPlayerHeight, // ✅ fixed height
                decoration: BoxDecoration(
                  color: const Color(0xFF3b2d20).withAlpha((0.95 * 255).round()),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: GestureDetector(
                  // ⬇️ Swipe gestures
                  onHorizontalDragEnd: (details) async {
                    final v = details.primaryVelocity ?? 0;
                    if (v < -50) {
                      // swipe left → next
                      await player.seekToNext();
                      await player.play();
                    } else if (v > 50) {
                      // swipe right → previous
                      await player.seekToPrevious();
                      await player.play();
                    }
                  },
                  onTap: () {
                    final pl = PlayerManager.I.currentPlaylist();
                    final current =
                        PlayerManager.I.player.currentIndex ?? 0;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NowPlayingScreen(
                          playlist: pl,
                          startIndex: current,
                          startPlayback:
                          false, // <-- नया flag (default true पुरानी behavior के लिए)
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
                        icon:
                        const Icon(Icons.skip_next_rounded, size: 26),
                        onPressed: () async {
                          await player.seekToNext();
                          await player.play();
                        },
                      ),
                      // ✅ naya CUT button
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22),
                        onPressed: () async {
                          homeMiniVisible.value = false; // mini player hide
                          await player.stop(); // music bhi band (chahe to hata sakte ho)
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