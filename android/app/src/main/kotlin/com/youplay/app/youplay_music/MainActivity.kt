package com.youplay.app.youplay_music

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ✅ Use ONLY plugin (do NOT create another MethodChannel here)
        flutterEngine.plugins.add(MediaDeletePlugin())
    }
}
