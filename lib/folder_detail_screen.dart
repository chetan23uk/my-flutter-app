// lib/folder_detail_screen.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;
import 'package:ringtone_set_plus/ringtone_set_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youplay_music/services/media_delete.dart';
import 'ads/banner_plan.dart';

import 'home_screen.dart';
import 'now_playing_screen.dart';
import 'playing_manager.dart'; // ✅ आपका ही मैनेजर नाम
import 'ads/ad_ids.dart';
import 'ads/banner_ad_widget.dart';

part 'folder_detail_parts/folder_detail_helpers_mixin.dart';
part 'folder_detail_parts/folder_detail_actions_mixin.dart';
part 'folder_detail_parts/folder_detail_build_mixin.dart';
part 'folder_detail_parts/search_bar.dart';
part 'folder_detail_parts/simple_song_list_screen.dart';
part 'folder_detail_parts/mini_player.dart';

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

class _FolderDetailScreenState extends State<FolderDetailScreen>
    with _FolderDetailHelpersMixin, _FolderDetailActionsMixin, _FolderDetailBuildMixin {
  bool _didChange = false;
  bool _selectMode = false;
  final Set<int> _selectedSongIds = <int>{};

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

  late final bottomInset = MediaQuery.of(context).padding.bottom;
}
