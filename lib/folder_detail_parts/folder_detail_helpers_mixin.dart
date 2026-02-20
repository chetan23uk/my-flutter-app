part of '../folder_detail_screen.dart';

mixin _FolderDetailHelpersMixin on State<FolderDetailScreen> {
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
    final state = this as _FolderDetailScreenState;

    if (state._query.trim().isEmpty) return state._list;
    final q = state._query.toLowerCase();
    return state._list.where((s) {
      return _cleanTitle(s).toLowerCase().contains(q) ||
          _artistOf(s).toLowerCase().contains(q);
    }).toList();
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m)),
    );
  }
}
