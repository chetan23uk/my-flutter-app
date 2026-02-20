part of '../folder_detail_screen.dart';

mixin _FolderDetailActionsMixin on State<FolderDetailScreen>, _FolderDetailHelpersMixin {
  void _exitSelectMode() {
    final state = this as _FolderDetailScreenState;

    setState(() {
      state._selectMode = false;
      state._selectedSongIds.clear();
    });
  }

  void _handleBack() {
    final state = this as _FolderDetailScreenState;

    if (state._selectMode) {
      _exitSelectMode(); // ✅ back = exit selection first
      return;
    }
    Navigator.pop(context, state._didChange);
  }

  // ---------- Bottom Sheet ----------
  void _openSongActions(
      BuildContext context,
      SongModel song, {
        required String title,
        required String artist,
      }) {
    final state = this as _FolderDetailScreenState;

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
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
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 8),
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
                          child: const Icon(Icons.music_note, color: Colors.white70),
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context, state._didChange),
                  ),
                ),
                const Divider(height: 1, color: Colors.white12),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: EdgeInsets.zero,
                    children: [
                      _sheetTile(Icons.play_arrow_rounded, 'Play next', () async {
                        final nav = Navigator.of(context);

                        await PlayerManager.I.playNext(song);

                        if (!mounted) return;
                        nav.pop();
                        _toast('Will play next');
                      }),

                      _sheetTile(Icons.queue_music_rounded, 'Add to queue', () async {
                        final nav = Navigator.of(context);

                        await PlayerManager.I.addToQueue(song);

                        if (!mounted) return;
                        nav.pop();
                        _toast('Added to queue');
                      }),

                      _sheetTile(Icons.playlist_add_rounded, 'Add to playlist', () async {
                        final nav = Navigator.of(context);

                        await PlayerManager.I.addPlaylist([song]);

                        if (!mounted) return;
                        nav.pop();
                        _toast('Added to current playlist');
                      }),

                      _sheetTile(Icons.album_rounded, 'Go to album', () async {
                        final nav = Navigator.of(context);

                        final album = song.album ?? '';
                        final list = state._list.where((e) => (e.album ?? '') == album).toList();

                        if (!mounted) return;
                        nav.pop();

                        Navigator.push(
                          this.context,
                          MaterialPageRoute(
                            builder: (_) => _SimpleSongListScreen(
                              title: album.isEmpty ? 'Unknown album' : album,
                              songs: list,
                            ),
                          ),
                        );
                      }),

                      _sheetTile(Icons.person_rounded, 'Go to artist', () async {
                        final nav = Navigator.of(context);

                        final artist = song.artist ?? '';
                        final list = state._list.where((e) => (e.artist ?? '') == artist).toList();

                        if (!mounted) return;
                        nav.pop();

                        Navigator.push(
                          this.context,
                          MaterialPageRoute(
                            builder: (_) => _SimpleSongListScreen(
                              title: artist.isEmpty ? 'Unknown artist' : artist,
                              songs: list,
                            ),
                          ),
                        );
                      }),

                      _sheetTile(Icons.share_rounded, 'Share', () async {
                        final nav = Navigator.of(context);

                        try {
                          await Share.shareXFiles([XFile(song.data)], text: _cleanTitle(song));
                        } catch (_) {
                          await Share.share(song.data);
                        }

                        if (!mounted) return;
                        nav.pop();
                      }),

                      _sheetTile(Icons.music_note_rounded, 'Set as ringtone', () async {
                        final nav = Navigator.of(context);

                        try {
                          final file = File(song.data);
                          if (await file.exists()) {
                            await RingtoneSet.setRingtoneFromFile(file);
                            if (mounted) _toast('Ringtone set successfully');
                          } else {
                            if (mounted) _toast('Audio file not found');
                          }
                        } catch (_) {
                          if (mounted) _toast('Failed to set ringtone');
                        }

                        if (!mounted) return;
                        nav.pop();
                      }),

                      const Divider(height: 1, color: Colors.white12),

                      _sheetTile(
                        Icons.delete_forever_rounded,
                        'Delete from device',
                            () async {
                          final nav = Navigator.of(context);

                          final ok = await _confirmDelete(this.context);
                          if (!ok) return;

                          final success = await PlayerManager.I.deleteFile(song);

                          if (!mounted) return;

                          if (success) {
                            setState(() {
                              state._list.removeWhere((e) => e.id == song.id);
                              state._didChange = true;
                            });
                            _toast('Deleted');
                          } else {
                            _toast('Delete failed');
                          }

                          nav.pop();
                        },
                        danger: true,
                      ),
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
        content: const Text('This will permanently remove the audio file.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ??
        false;
  }

  Widget _sheetTile(
      IconData icon,
      String text,
      VoidCallback onTap, {
        bool danger = false,
      }) {
    return ListTile(
      leading: Icon(icon, color: danger ? const Color(0xFFFF6B6B) : Colors.white),
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
