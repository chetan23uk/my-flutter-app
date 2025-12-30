package com.youplay.app.youplay_music

import android.app.Activity
import android.content.Intent
import android.content.IntentSender
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
        Log.d("MediaDelete", "Plugin attached to engine")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "deleteUris") {
            result.notImplemented()
            return
        }

        val act = activity
        if (act == null) {
            Log.e("MediaDelete", "No activity attached")
            result.success(false)
            return
        }

        val uris = call.argument<List<String>>("uris") ?: emptyList()
        Log.d("MediaDelete", "deleteUris called count=${uris.size}")

        if (uris.isEmpty()) {
            result.success(true)
            return
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            Log.d("MediaDelete", "SDK<29 -> return false (Dart fallback)")
            result.success(false)
            return
        }

        if (pendingResult != null) {
            result.error("BUSY", "A delete request is already running.", null)
            return
        }

        val uriList = uris.map { it.toUri() }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val pi = MediaStore.createDeleteRequest(act.contentResolver, uriList)
                pendingResult = result
                act.startIntentSenderForResult(pi.intentSender, reqDelete, null, 0, 0, 0)
            } else {
                var deletedCount = 0
                for (u in uriList) {
                    deletedCount += act.contentResolver.delete(u, null, null)
                }
                Log.d("MediaDelete", "API29 deletedCount=$deletedCount")
                result.success(deletedCount > 0)
            }
        } catch (e: RecoverableSecurityException) {
            Log.e("MediaDelete", "RecoverableSecurityException -> asking user", e)
            pendingResult = result
            act.startIntentSenderForResult(e.userAction.actionIntent.intentSender, reqDelete, null, 0, 0, 0)
        } catch (e: SecurityException) {
            Log.e("MediaDelete", "SecurityException", e)
            result.success(false)
        } catch (e: IllegalArgumentException) {
            Log.e("MediaDelete", "IllegalArgumentException (bad uri?)", e)
            result.success(false)
        } catch (e: IntentSender.SendIntentException) {
            Log.e("MediaDelete", "SendIntentException", e)
            pendingResult = null
            result.error("INTENT_FAILED", e.message, null)
        } catch (e: Exception) {
            Log.e("MediaDelete", "Exception", e)
            result.error("DELETE_FAILED", e.message, null)
        }
    }

    // ActivityAware
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
        Log.d("MediaDelete", "Attached to activity=${activity?.javaClass?.simpleName}")
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // ActivityResult
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != reqDelete) return false
        val ok = (resultCode == Activity.RESULT_OK)
        Log.d("MediaDelete", "result ok=$ok resultCode=$resultCode")
        pendingResult?.success(ok)
        pendingResult = null
        return true
    }
}
