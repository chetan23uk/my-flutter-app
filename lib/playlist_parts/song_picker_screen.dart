import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../ads/ad_ids.dart';
import '../ads/banner_ad_widget.dart';
import '../ads/banner_plan.dart';

class SongPickerScreen extends StatefulWidget {
  final int playlistId;
  final String playlistName;
  const SongPickerScreen({
    super.key,
    required this.playlistId,
    required this.playlistName,
  });

  @override
  State<SongPickerScreen> createState() => _SongPickerScreenState();
}

class _SongPickerScreenState extends State<SongPickerScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  final Set<int> _selectedIds = {};
  final Set<int> _alreadyInPlaylist = {};

  late final Future<List<SongModel>> _allSongsFuture;

  bool _existingLoaded = false;
  bool _existingOk = false;
  bool _saving = false;

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();

    // ✅ blink fix: cached future (build me re-create nahi hoga)
    _allSongsFuture = _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
    );

    _loadExisting();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final existing = await _audioQuery.queryAudiosFrom(
        AudiosFromType.PLAYLIST,
        widget.playlistId,
      );

      _alreadyInPlaylist
        ..clear()
        ..addAll(existing.map((e) => e.id));

      _existingOk = true;
    } catch (_) {
      // ✅ If verify fails, add disable (duplicates prevent)
      _existingOk = false;
    }

    if (!mounted) return;
    setState(() => _existingLoaded = true);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _artworkOrIcon(SongModel s) {
    final int albumId = s.albumId ?? 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 46,
        height: 46,
        child: QueryArtworkWidget(
          // ✅ album art fallback
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

  @override
  Widget build(BuildContext context) {
    final canInteract = _existingLoaded && _existingOk && !_saving;

    return Scaffold(
      appBar: AppBar(
        title: Text('Add to ${widget.playlistName}'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.check,
              color: (canInteract && _selectedIds.isNotEmpty)
                  ? Colors.greenAccent
                  : Colors.white38,
              size: 30,
            ),
            onPressed: (!canInteract || _selectedIds.isEmpty)
                ? null
                : _addSongsToPlaylist,
          ),
        ],
      ),
      body: FutureBuilder<List<SongModel>>(
        future: _allSongsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allSongs = snapshot.data ?? const <SongModel>[];
          if (allSongs.isEmpty) {
            return const Center(child: Text('No songs found'));
          }

          // ✅ verify fail UI (so duplicates never happen)
          if (_existingLoaded && !_existingOk) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 56, color: Colors.orangeAccent),
                    const SizedBox(height: 12),
                    const Text(
                      'Playlist verify failed.\nAdd is disabled to prevent duplicates.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _existingLoaded = false;
                          _existingOk = false;
                        });
                        _loadExisting();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final int len = allSongs.length;
          final int bannerCount = BannerPlan.bannerCountForItems(len);
          final plan = BannerPlan.build(items: len, banners: bannerCount);

          return Stack(
            children: [
              ListView.builder(
                key: const PageStorageKey('song_picker_list'),
                controller: _scrollCtrl,
                addAutomaticKeepAlives: true,
                addRepaintBoundaries: true,
                itemCount: plan.totalCount,
                itemBuilder: (context, i) {
                  final bool isAd = plan.isAdIndex(i);

                  if (isAd) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: BannerAdWidget(
                        adUnitId: AdIds.banner,
                        placement: 'song_picker',
                        slot: plan.slotForListIndex(i),
                      ),
                    );
                  }

                  final int realIndex = plan.dataIndexFromListIndex(i);
                  if (realIndex < 0 || realIndex >= allSongs.length) {
                    return const SizedBox.shrink();
                  }

                  final s = allSongs[realIndex];

                  final already = _alreadyInPlaylist.contains(s.id);
                  final selected = _selectedIds.contains(s.id);

                  return CheckboxListTile(
                    value: selected,
                    secondary: _artworkOrIcon(s),
                    title: Text(
                      s.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      already ? 'Already in playlist' : (s.artist ?? 'Unknown'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onChanged: (!canInteract || already)
                        ? null
                        : (val) {
                      setState(() {
                        if (val == true) {
                          _selectedIds.add(s.id);
                        } else {
                          _selectedIds.remove(s.id);
                        }
                      });
                    },
                  );
                },
              ),

              if (!_existingLoaded || _saving)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: true,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.06),
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ✅ Duplicate-proof add (filter before add)
  Future<void> _addSongsToPlaylist() async {
    setState(() => _saving = true);

    try {
      // 1. Current playlist ke gaane fresh fetch karein
      final freshList = await _audioQuery.queryAudiosFrom(
        AudiosFromType.PLAYLIST,
        widget.playlistId,
      );

      // 2. Existing song IDs ka Set (fast checking)
      final existingIds = freshList.map((s) => s.id).toSet();

      int addedCount = 0;

      // 3. Loop sirf unhe add kare jo pehle se nahi hain
      for (final songId in _selectedIds) {
        if (!existingIds.contains(songId)) {
          await _audioQuery.addToPlaylist(widget.playlistId, songId);
          existingIds.add(songId); // ✅ same run me bhi duplicate add na ho
          _alreadyInPlaylist.add(songId); // UI me "Already in playlist" update
          addedCount++;
        }
      }

      if (!mounted) return;
      setState(() => _saving = false);

      _snack(
        addedCount > 0
            ? 'Added $addedCount new song(s)'
            : 'Songs already in playlist',
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Error updating playlist');
    }
  }
}
