part of '../home_screen.dart';

mixin HomeIntentsMixin on State<HomeScreen> {
  StreamSubscription<ri.Intent?>? _intentSub;
  bool _openingNowPlaying = false;

  Future<void> initAudioOpenWithIntents() async {
    if (!Platform.isAndroid) return;

    final initial = await ri.ReceiveIntent.getInitialIntent();
    await _handleIncomingIntent(initial);

    _intentSub = ri.ReceiveIntent.receivedIntentStream.listen(
          (intent) async => _handleIncomingIntent(intent),
    );
  }

  String? _extractAudioUri(ri.Intent intent) {
    // 1) direct data
    final d = intent.data;
    if (d != null && d.trim().isNotEmpty) return d.trim();

    // 2) many file managers send in EXTRA_STREAM
    final extra = intent.extra;
    final stream = extra?['android.intent.extra.STREAM'];
    if (stream != null) return stream.toString().trim();

    // 3) fallback: sometimes "uri" key
    final u = extra?['uri'];
    if (u != null) return u.toString().trim();

    return null;
  }

  Future<void> _handleIncomingIntent(ri.Intent? intent) async {
    if (!mounted) return;
    if (intent == null) return;

    final action = intent.action ?? '';
    if (action != 'android.intent.action.VIEW') return;

    final uriStr = _extractAudioUri(intent);
    if (uriStr == null || uriStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read the audio file URI.')),
      );
      return;
    }

    homeMiniVisible.value = true;

    try {
      await PlayerManager.I.playExternalUri(uriStr);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audio play failed: $e')),
      );
      return;
    }

    if (!mounted) return;

    if (_openingNowPlaying) return;
    _openingNowPlaying = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _openingNowPlaying = false;
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const NowPlayingScreen(startPlayback: false),
        ),
      ).then((_) {
        homeMiniVisible.value = true;
        _openingNowPlaying = false;
      });
    });
  }

  void disposeAudioOpenWithIntents() {
    _intentSub?.cancel();
    _intentSub = null;
  }
}
