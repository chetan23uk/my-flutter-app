part of '../folder_detail_screen.dart';

mixin _FolderDetailBuildMixin on State<FolderDetailScreen>, _FolderDetailHelpersMixin, _FolderDetailActionsMixin {

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final state = this as _FolderDetailScreenState;
    final items = _filtered;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (state._selectMode) {
          _exitSelectMode();
          return;
        }

        Navigator.pop(context, state._didChange);
      },
      child: Scaffold(
        extendBodyBehindAppBar: false,
        appBar: AppBar(
          titleSpacing: 0,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack, // ✅ UPDATED: same logic as PopScope
          ),
          title: state._selectMode
              ? Text('${state._selectedSongIds.length} selected')
              : _SearchBar(
            initial: state._query,
            hint: 'Search in ${widget.folderName}',
            onChanged: (v) => setState(() => state._query = v),
          ),
          actions: [
            if (state._selectMode) ...[
              IconButton(
                tooltip: 'Select all',
                icon: const Icon(Icons.select_all),
                onPressed: () {
                  setState(() {
                    final items = _filtered;
                    state._selectedSongIds.addAll(items.map((e) => e.id));
                  });
                },
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_forever_rounded),
                onPressed: state._selectedSongIds.isEmpty
                    ? null
                    : () async {
                  final confirm = await _confirmDelete(context);
                  if (!confirm) return;

                  // ✅ selected songs list
                  final selectedSongs = state._list
                      .where((s) => state._selectedSongIds.contains(s.id))
                      .toList();

                  final uris = selectedSongs
                      .map((s) => s.uri)
                      .whereType<String>()
                      .where((u) => u.isNotEmpty)
                      .toList();

                  if (uris.isEmpty) {
                    _toast('No deletable files found');
                    return;
                  }

                  final ok = await MediaDeleteService.deleteUris(uris);

                  if (!mounted) return;

                  if (ok) {
                    setState(() {
                      state._list.removeWhere(
                              (s) => state._selectedSongIds.contains(s.id));
                      state._selectedSongIds.clear();
                      state._selectMode = false;
                      state._didChange = true;
                    });
                    _toast('Deleted');
                  } else {
                    _toast('Delete failed');
                    // selection mode ko user ke control me rehne do
                  }
                },
              ),
              IconButton(
                tooltip: 'Cancel selection',
                icon: const Icon(Icons.close),
                onPressed: _exitSelectMode,
              ),
            ] else ...[
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {},
              ),
            ],
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${items.length} ${items.length == 1 ? "track" : "tracks"}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
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
                      await Future<void>.delayed(
                          const Duration(milliseconds: 250));
                      if (mounted) setState(() {});
                    },
                    child: Scrollbar(
                      thickness: 3,
                      radius: const Radius.circular(8),
                      child: Builder(
                        builder: (context) {
                          final int len = items.length;

                          // ✅ NEW: BannerPlan based ad insertion
                          final int bannerCount = BannerPlan.bannerCountForItems(len);
                          final plan = BannerPlan.build(items: len, banners: bannerCount);
                          final int totalCount = plan.totalCount;

                          return ListView.separated(
                            padding: EdgeInsets.only(
                              bottom: _miniReserve(context),
                            ),
                            itemCount: totalCount,
                            separatorBuilder: (_, i) {
                              final bool isCurrentAd = plan.isAdIndex(i);
                              final bool isNextAd = plan.isAdIndex(i + 1);

                              if (isCurrentAd || isNextAd) {
                                return const SizedBox.shrink();
                              }

                              return const Divider(
                                height: 1,
                                color: Colors.white12,
                                indent: 80,
                              );
                            },
                            itemBuilder: (context, i) {
                              final bool isAd = plan.isAdIndex(i);

                              if (isAd) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  child: BannerAdWidget(
                                    adUnitId: AdIds.banner,
                                    placement: 'folder_detail',
                                    slot: plan.slotForListIndex(i),
                                  ),
                                );
                              }

                              final int realIndex = plan.dataIndexFromListIndex(i);

                              if (realIndex < 0 || realIndex >= len) {
                                return const SizedBox.shrink();
                              }

                              final s = items[realIndex];
                              final title = _cleanTitle(s);
                              final artist = _artistOf(s);
                              final selected = state._selectedSongIds.contains(s.id);

                              return InkWell(
                                onLongPress: () {
                                  setState(() {
                                    state._selectMode = true;
                                    state._selectedSongIds.add(s.id);
                                  });
                                },
                                onTap: () {
                                  ScaffoldMessenger.of(context).clearSnackBars();

                                  // ✅ If select mode ON: tap = toggle selection
                                  if (state._selectMode) {
                                    setState(() {
                                      if (selected) {
                                        state._selectedSongIds.remove(s.id);
                                        if (state._selectedSongIds.isEmpty) {
                                          _exitSelectMode();
                                        }
                                      } else {
                                        state._selectedSongIds.add(s.id);
                                      }
                                    });
                                    return;
                                  }

                                  // ✅ Normal play (unchanged)
                                  homeMiniVisible.value = true;

                                  final startIndex = state._list.indexOf(s);
                                  PlayerManager.I.playPlaylist(state._list, startIndex);

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NowPlayingScreen(
                                        playlist: state._list,
                                        startIndex: math.max(0, startIndex),
                                      ),
                                    ),
                                  ).then((_) {
                                    homeMiniVisible.value = true;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      state._selectMode
                                          ? Checkbox(
                                        value: selected,
                                        onChanged: (v) {
                                          setState(() {
                                            if (v == true) {
                                              state._selectedSongIds.add(s.id);
                                            } else {
                                              state._selectedSongIds.remove(s.id);
                                              if (state._selectedSongIds.isEmpty) {
                                                _exitSelectMode();
                                              }
                                            }
                                          });
                                        },
                                      )
                                          : ClipRRect(
                                        borderRadius:
                                        BorderRadius.circular(10),
                                        child: SizedBox(
                                          width: 52,
                                          height: 52,
                                          child: QueryArtworkWidget(
                                            id: s.id,
                                            type: ArtworkType.AUDIO,
                                            keepOldArtwork: true,
                                            nullArtworkWidget: Container(
                                              color: Colors.white10,
                                              child: const Icon(
                                                  Icons.music_note,
                                                  color: Colors.white70),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                          if (!state._selectMode)
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

            // ✅ Mini Player + Ad group
            ValueListenableBuilder<bool>(
              valueListenable: homeMiniVisible,
              builder: (context, visible, _) {
                if (!visible) return const SizedBox.shrink();

                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.of(context).padding.bottom + 10,
                  child: const HomeMiniPlayer(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
