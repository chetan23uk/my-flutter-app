// lib/lists/song_list_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../now_playing_screen.dart';
import 'audio_utils.dart'; // cleanTitle / artistOf / fmtDur

class SongListScreen extends StatefulWidget {
  final String title;
  final List<SongModel> songs;

  const SongListScreen({
    super.key,
    required this.title,
    required this.songs,
  });

  @override
  State<SongListScreen> createState() => _SongListScreenState();
}

class _SongListScreenState extends State<SongListScreen> {
  late List<SongModel> _list;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _list = [...widget.songs]
      ..sort((a, b) => cleanTitle(a).toLowerCase().compareTo(cleanTitle(b).toLowerCase()));
  }

  List<SongModel> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _list;
    return _list.where((s) =>
    cleanTitle(s).toLowerCase().contains(q) || artistOf(s).toLowerCase().contains(q)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: SizedBox(
          height: kToolbarHeight - 12,
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Search in ${widget.title}',
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
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment(0, .25),
                  colors: [Color(0xFF1E1B1C), Colors.transparent],
                ),
              ),
            ),
          ),
          Column(
            children: [
              const SizedBox(height: kToolbarHeight + 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(20)),
                      child: Text('${items.length} tracks',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Scrollbar(
                  thickness: 3,
                  radius: const Radius.circular(8),
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12, indent: 80),
                    itemBuilder: (_, i) {
                      final s = items[i];
                      return InkWell(
                        onTap: () {
                          final idx = _list.indexOf(s);
                          // ✅ older snackbars clear (red banner fix)
                          ScaffoldMessenger.of(context).clearSnackBars();

                          // ✅ just push; playback will begin inside NowPlaying
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NowPlayingScreen(
                                playlist: _list,
                                startIndex: math.max(0, idx),
                              ),
                            ),
                          );
                        },
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
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cleanTitle(s),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      artistOf(s),
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
                                  Text(fmtDur(s.duration),
                                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  const _RowMenu(),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RowMenu extends StatelessWidget {
  const _RowMenu();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'queue', child: Text('Play next')),
        PopupMenuItem(value: 'details', child: Text('Details')),
        PopupMenuItem(value: 'share', child: Text('Share')),
      ],
    );
  }
}