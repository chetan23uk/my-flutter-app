// lib/lists/song_list_screen.dart
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import 'audio_utils.dart';
import '../services/media_delete.dart'; // ✅ MediaDeleteService import

// ✅ Ads imports (only added)
import '../ads/ad_ids.dart';
import '../ads/banner_ad_widget.dart';
import '../ads/banner_plan.dart';

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
  // ✅ Fix: Search ke liye text controller use karna better hai warnings hatane ke liye
  final TextEditingController _searchController = TextEditingController();
  final String _query = '';

  // ✅ Selection Variables
  bool _isSelectionMode = false;
  final Set<SongModel> _selectedSongs = {};

  @override
  void initState() {
    super.initState();
    _list = [...widget.songs]
      ..sort((a, b) => cleanTitle(a).toLowerCase().compareTo(cleanTitle(b).toLowerCase()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(SongModel song) {
    setState(() {
      if (_selectedSongs.contains(song)) {
        _selectedSongs.remove(song);
        if (_selectedSongs.isEmpty) _isSelectionMode = false;
      } else {
        _selectedSongs.add(song);
      }
    });
  }

  // ✅ Fix: Don't use BuildContext across async gaps
  Future<void> _deleteSelected() async {
    final List<String> uris = _selectedSongs.map((s) => s.uri!).toList();

    final bool success = await MediaDeleteService.deleteUris(uris);

    // ✅ Async gap check
    if (!mounted) return;

    if (success) {
      setState(() {
        _list.removeWhere((s) => _selectedSongs.contains(s));
        _selectedSongs.clear();
        _isSelectionMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selected songs deleted")),
      );
    }
  }

  void _showConfirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Delete Songs?", style: TextStyle(color: Colors.white)),
        content: Text("Kya aap ${_selectedSongs.length} gaano ko hamesha ke liye delete karna chahte hain?",
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteSelected();
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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

    // ✅ BannerPlan injection (only added)
    final int len = items.length;
    final int bannerCount = BannerPlan.bannerCountForItems(len);
    final plan = BannerPlan.build(items: len, banners: bannerCount);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(_isSelectionMode ? "${_selectedSongs.length} Selected" : widget.title),
        leading: _isSelectionMode
            ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() {
            _isSelectionMode = false;
            _selectedSongs.clear();
          }),
        )
            : const BackButton(),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _showConfirmDelete,
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.search, color: Colors.white38),
            ),
        ],
      ),
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(color: Color(0xFF090909))),
          Column(
            children: [
              const SizedBox(height: kToolbarHeight + 20),
              // Search Input logic (if any)
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),

                  // ✅ UPDATED: use plan.totalCount
                  itemCount: plan.totalCount,

                  itemBuilder: (context, index) {
                    final bool isAd = plan.isAdIndex(index);

                    if (isAd) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: BannerAdWidget(
                          adUnitId: AdIds.banner,
                          placement: 'song_list',
                          slot: plan.slotForListIndex(index),
                        ),
                      );
                    }

                    final int realIndex = plan.dataIndexFromListIndex(index);

                    if (realIndex < 0 || realIndex >= items.length) {
                      return const SizedBox.shrink();
                    }

                    final s = items[realIndex];
                    final isSelected = _selectedSongs.contains(s);

                    return GestureDetector(
                      onLongPress: () {
                        if (!_isSelectionMode) {
                          setState(() {
                            _isSelectionMode = true;
                            _toggleSelection(s);
                          });
                        }
                      },
                      onTap: () {
                        if (_isSelectionMode) {
                          _toggleSelection(s);
                        } else {
                          // Play Logic
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          // ✅ Fix: .withValues() instead of .withOpacity()
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(15),
                          border: isSelected ? Border.all(color: Colors.blueAccent) : null,
                        ),
                        child: Row(
                          children: [
                            if (_isSelectionMode)
                              Checkbox(
                                value: isSelected,
                                onChanged: (_) => _toggleSelection(s),
                                activeColor: Colors.blueAccent,
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cleanTitle(s),
                                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                      maxLines: 1),
                                  Text(artistOf(s), style: const TextStyle(color: Colors.white60, fontSize: 13)),
                                ],
                              ),
                            ),
                            Text(fmtDur(s.duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
