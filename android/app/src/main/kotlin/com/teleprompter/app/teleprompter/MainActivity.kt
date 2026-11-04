package com.teleprompter.app.teleprompter

import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.FileNotFoundException
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val backgroundWork = Executors.newSingleThreadExecutor()
    private val mainThread = Handler(Looper.getMainLooper())
    private lateinit var saver: PublicVideoSaver
    private lateinit var sharer: PublicVideoSharer

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        saver = PublicVideoSaver(applicationContext, PUBLIC_FOLDER_NAME)
        sharer = PublicVideoSharer(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveVideo" -> saveVideo(call, result)
                "shareVideos" -> shareVideos(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun saveVideo(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val fileName = call.argument<String>("fileName")
        if (path == null || fileName == null) {
            result.error("bad_arguments", "path and fileName are required", null)
            return
        }
        // Copying a large take must not block the UI thread.
        backgroundWork.execute {
            try {
                val savedAt = saver.save(path, fileName)
                mainThread.post { result.success(savedAt) }
            } catch (error: SecurityException) {
                mainThread.post { result.error("permission_denied", error.message, null) }
            } catch (error: Exception) {
                mainThread.post { result.error("save_failed", error.message, null) }
            }
        }
    }

    private fun shareVideos(call: MethodCall, result: MethodChannel.Result) {
        val uris = call.argument<List<String>>("uris")?.map(Uri::parse)
        if (uris.isNullOrEmpty()) {
            result.error("bad_arguments", "uris are required", null)
            return
        }
        try {
            sharer.share(uris, call.argument<String>("subject"))
            result.success(null)
        } catch (error: FileNotFoundException) {
            result.error("missing_public_copy", error.message, null)
        } catch (error: Exception) {
            result.error("share_failed", error.message, null)
        }
    }

    override fun onDestroy() {
        backgroundWork.shutdown()
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "cuevanta/public_videos"
        private const val PUBLIC_FOLDER_NAME = "Cuevanta"
    }
}
