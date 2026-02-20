part of '../home_screen.dart';

extension _HomeTabFoldersExt on _HomeScreenState {
  Widget _buildFolders() {
    return FutureBuilder<Map<String, List<SongModel>>>(
      future: _foldersFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snap.data ?? {};

        if (data.isEmpty) {
          return Center(
            child: Text(
              'home_no_folders'.tr(),
              style: const TextStyle(color: Colors.white60),
            ),
          );
        }

        final entries = data.entries
            .where((e) => !_hiddenFolders.contains(e.key))
            .toList();

        if (entries.isEmpty && _hiddenFolders.isEmpty) {
          return const Center(child: Text('No folders found'));
        }

        return Column(
          children: [
            if (_hiddenFolders.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _showHiddenFoldersSheet(data),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: Text('Hidden folders (${_hiddenFolders.length})'),
                  ),
                ),
              ),
            Expanded(
              child: entries.isEmpty
                  ? const Center(child: Text('All folders are hidden'))
                  : Builder(
                builder: (context) {
                  final int len = entries.length;

                  final int bannerCount =
                  BannerPlan.bannerCountForItems(len);
                  final plan = BannerPlan.build(
                      items: len, banners: bannerCount);
                  final int totalCount = plan.totalCount;

                  return ListView.builder(
                    padding: const EdgeInsets.only(
                        bottom: 92), // Mini player space
                    itemCount: totalCount,
                    itemBuilder: (context, index) {
                      // ✅ Ad check
                      final bool isAd = plan.isAdIndex(index);

                      if (isAd) {
                        return _inlineBanner(
                          placement: 'home_folders',
                          slot: plan.slotForListIndex(index),
                        ); // Aapka banner ad widget
                      }

                      // ✅ Real index calculation (ads minus karke)
                      final int realIdx =
                      plan.dataIndexFromListIndex(index);

                      if (realIdx < 0 || realIdx >= len) {
                        return const SizedBox.shrink();
                      }

                      final entry = entries[realIdx];
                      final folderPath = entry.key;
                      final songs = entry.value;
                      final name = p.basename(folderPath);

                      final selected =
                      _selectedFolderPaths.contains(folderPath);

                      // --- Folder Display Logic ---
                      if (_selectMode) {
                        return ListTile(
                          leading: Checkbox(
                            value: selected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedFolderPaths.add(folderPath);
                                } else {
                                  _selectedFolderPaths.remove(folderPath);
                                }
                              });
                            },
                          ),
                          title: Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${songs.length} ${'songs'.tr()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          onTap: () {
                            setState(() {
                              if (selected) {
                                _selectedFolderPaths.remove(folderPath);
                              } else {
                                _selectedFolderPaths.add(folderPath);
                              }
                            });
                          },
                        );
                      }

                      return FolderTile(
                        name: name,
                        path: folderPath,
                        songCount: songs.length,
                        onTap: () async {
                          if (_selectMode) {
                            setState(() {
                              if (_selectedFolderPaths
                                  .contains(folderPath)) {
                                _selectedFolderPaths.remove(folderPath);
                              } else {
                                _selectedFolderPaths.add(folderPath);
                              }
                            });
                            return;
                          }
                          await InterstitialHelper.instance.tryShow(placement: 'open_folder');
                          if (!mounted) return;
                          final changed = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FolderDetailScreen(
                                folderName: name,
                                folderPath: folderPath,
                                songs: songs,
                              ),
                            ),
                          );

                          if (changed == true) {
                            await _initPermissionsAndLoad();
                            if (mounted) setState(() {});
                          }
                        },
                        onLongPress: () {
                          setState(() {
                            _selectMode = true;
                            _selectedFolderPaths.add(folderPath);
                          });
                        },
                        onMenu: (action) {
                          _onFolderMenuAction(
                            name,
                            folderPath,
                            songs,
                            action as FolderMenu,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showHiddenFoldersSheet(Map<String, List<SongModel>> data) {
    if (_hiddenFolders.isEmpty) return;

    final hidden = <MapEntry<String, List<SongModel>>>[];
    for (final path in _hiddenFolders) {
      final songs = data[path];
      if (songs != null) {
        hidden.add(MapEntry(path, songs));
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                const Text(
                  'Hidden folders',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: hidden.length,
                    separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Colors.white12),
                    itemBuilder: (context, i) {
                      final entry = hidden[i];
                      final path = entry.key;
                      final name = p.basename(path);
                      final count = entry.value.length;

                      return ListTile(
                        leading: const Icon(Icons.folder_off,
                            color: Color(0xFF7E57FF)),
                        title: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          '$count songs',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        trailing: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _unhideFolder(name, path);
                          },
                          child: const Text('Unhide',
                              style: TextStyle(color: Colors.white)),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _unhideFolder(name, path);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
