package com.teleprompter.app.teleprompter

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.FileInputStream
import java.io.IOException

/**
 * Copies a finished take into the shared Movies/<folder> collection so it shows
 * up in Gallery, over USB on a computer, and survives uninstalling the app.
 */
class PublicVideoSaver(private val context: Context, private val folderName: String) {

    /** Returns a reference to the public copy (content URI or file path). */
    @Throws(IOException::class)
    fun save(sourcePath: String, displayName: String): String {
        val source = File(sourcePath)
        if (!source.exists()) throw IOException("Take not found: $sourcePath")
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveWithMediaStore(source, displayName)
        } else {
            saveToLegacyMoviesFolder(source, displayName)
        }
    }

    /** Android 10+: scoped storage, no permission needed for our own videos. */
    private fun saveWithMediaStore(source: File, displayName: String): String {
        val resolver = context.contentResolver
        val collection = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val pending = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Video.Media.MIME_TYPE, VIDEO_MIME_TYPE)
            put(MediaStore.Video.Media.RELATIVE_PATH, "${Environment.DIRECTORY_MOVIES}/$folderName")
            put(MediaStore.Video.Media.IS_PENDING, 1)
        }
        val uri = resolver.insert(collection, pending)
            ?: throw IOException("Android refused to create the video entry")

        try {
            resolver.openOutputStream(uri)?.use { output ->
                FileInputStream(source).use { input -> input.copyTo(output) }
            } ?: throw IOException("Could not open the public video for writing")
            resolver.update(uri, ContentValues().apply { put(MediaStore.Video.Media.IS_PENDING, 0) }, null, null)
            return uri.toString()
        } catch (error: IOException) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    /** Android 7–9: needs WRITE_EXTERNAL_STORAGE (requested from Dart beforehand). */
    @Suppress("DEPRECATION")
    private fun saveToLegacyMoviesFolder(source: File, displayName: String): String {
        val folder = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES), folderName)
        if (!folder.exists() && !folder.mkdirs()) throw IOException("Could not create ${folder.path}")
        val target = uniqueFile(folder, displayName)
        source.copyTo(target)
        MediaScannerConnection.scanFile(context, arrayOf(target.path), arrayOf(VIDEO_MIME_TYPE), null)
        return target.path
    }

    private fun uniqueFile(folder: File, displayName: String): File {
        val stem = displayName.substringBeforeLast('.')
        val extension = displayName.substringAfterLast('.', "")
        var candidate = File(folder, displayName)
        var copy = 2
        while (candidate.exists()) {
            candidate = File(folder, "$stem ($copy).$extension")
            copy++
        }
        return candidate
    }

    companion object {
        private const val VIDEO_MIME_TYPE = "video/mp4"
    }
}
