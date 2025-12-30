import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;

/// Returns a nice, human-readable title for a song.
/// Falls back to file name (without extension) when title is <unknown> / empty.
/// Also decodes URI-encoded names and replaces underscores.
String cleanTitle(SongModel s) {
  String title =
  (s.title.isNotEmpty && s.title.toLowerCase() != '<unknown>')
      ? s.title
      : p.basenameWithoutExtension(s.data);

  // If file path had URL-encoded chars (e.g. %20), decode them.
  try {
    title = Uri.decodeFull(title);
  } catch (_) {
    // ignore decode errors
  }

  // Collapse underscores and extra spaces.
  title = title.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return title;
}

/// Artist with graceful fallback.
String artistOf(SongModel s) {
  final a = s.artist ?? '';
  return (a.isEmpty || a.toLowerCase() == '<unknown>') ? 'Unknown artist' : a;
}

/// Album with graceful fallback.
String albumOf(SongModel s) {
  final a = s.album ?? '';
  return (a.isEmpty || a.toLowerCase() == '<unknown>') ? 'Unknown album' : a;
}

/// Nicely formatted duration:
/// - h:mm:ss when >= 1 hour
/// - m:ss   otherwise
String fmtDur(int? ms) {
  final d = Duration(milliseconds: ms ?? 0);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);

  if (h > 0) {
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return '$h:$mm:$ss';
  } else {
    final ss = s.toString().padLeft(2, '0');
    return '$m:$ss';
  }
}

/// True if a field is empty or "<unknown>"
bool isUnknown(String? value) {
  final v = (value ?? '').trim();
  return v.isEmpty || v.toLowerCase() == '<unknown>';
}