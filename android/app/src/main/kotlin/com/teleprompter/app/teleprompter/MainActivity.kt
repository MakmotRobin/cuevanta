package com.teleprompter.app.teleprompter

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val backgroundWork = Executors.newSingleThreadExecutor()
    private val mainThread = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val saver = PublicVideoSaver(applicationContext, PUBLIC_FOLDER_NAME)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "saveVideo") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            val fileName = call.argument<String>("fileName")
            if (path == null || fileName == null) {
                result.error("bad_arguments", "path and fileName are required", null)
                return@setMethodCallHandler
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
