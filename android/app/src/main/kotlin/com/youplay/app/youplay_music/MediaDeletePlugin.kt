package com.youplay.app.youplay_music

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.provider.MediaStore
import android.util.Log
import android.app.RecoverableSecurityException
import androidx.core.net.toUri
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class MediaDeletePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {

    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private val reqDelete = 9911
    private var pendingResult: MethodChannel.Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "youplay/media_delete")
        channel?.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "deleteUris") {
            result.notImplemented()
            return
        }

        val act = activity ?: return result.error("NO_ACTIVITY", "Activity null", null)
        val urisStrings = call.argument<List<String>>("uris") ?: emptyList()
        if (urisStrings.isEmpty()) return result.success(true)

        // String paths ko Content URIs mein badlein
        val uriList = urisStrings.mapNotNull { it.toUri() }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // ✅ PLAY STORE BEST PRACTICE: Android 11+ Bulk Request
                // Yeh user se ek hi baar permission maangega chahe 1000 files ho
                val pi = MediaStore.createDeleteRequest(act.contentResolver, uriList)
                pendingResult = result
                act.startIntentSenderForResult(pi.intentSender, reqDelete, null, 0, 0, 0)
            } else if (Build.VERSION.SDK_INT == Build.VERSION_CODES.Q) {
                // Android 10 (Q) logic
                try {
                    for (u in uriList) act.contentResolver.delete(u, null, null)
                    result.success(true)
                } catch (e: RecoverableSecurityException) {
                    pendingResult = result
                    act.startIntentSenderForResult(e.userAction.actionIntent.intentSender, reqDelete, null, 0, 0, 0)
                }
            } else {
                // Android 9 and below: Let Flutter handle it via dart:io
                result.success(false)
            }
        } catch (e: Exception) {
            result.error("DELETE_ERROR", e.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == reqDelete) {
            // Agar user ne 'Allow' button dabaya toh true, warna false
            pendingResult?.success(resultCode == Activity.RESULT_OK)
            pendingResult = null
            return true
        }
        return false
    }

    // --- ActivityAware Boilerplate (Zaroori hai Activity context ke liye) ---
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }
    override fun onDetachedFromActivity() { activity = null }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) { channel?.setMethodCallHandler(null) }
}