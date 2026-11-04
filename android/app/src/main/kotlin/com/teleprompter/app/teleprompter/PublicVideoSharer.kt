package com.teleprompter.app.teleprompter

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import java.io.FileNotFoundException

/**
 * Opens the share sheet for videos that already live in Movies/Cuevanta.
 * Sharing their content:// URIs needs no copying, so the sheet opens at once
 * whatever the file size.
 */
class PublicVideoSharer(private val activity: Activity) {

    /** Throws [FileNotFoundException] if any video was removed (e.g. deleted in Gallery). */
    @Throws(FileNotFoundException::class)
    fun share(uris: List<Uri>, subject: String?) {
        require(uris.isNotEmpty()) { "Nothing to share" }
        uris.forEach(::ensureStillExists)

        val send = if (uris.size == 1) {
            Intent(Intent.ACTION_SEND).putExtra(Intent.EXTRA_STREAM, uris.single())
        } else {
            Intent(Intent.ACTION_SEND_MULTIPLE).putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(uris))
        }
        send.type = VIDEO_MIME_TYPE
        subject?.let { send.putExtra(Intent.EXTRA_SUBJECT, it) }
        // ClipData carries the read grant through the chooser to the chosen app.
        send.clipData = ClipData.newRawUri(subject ?: "", uris.first()).apply {
            uris.drop(1).forEach { addItem(ClipData.Item(it)) }
        }
        send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

        activity.startActivity(Intent.createChooser(send, subject))
    }

    private fun ensureStillExists(uri: Uri) {
        activity.contentResolver.openFileDescriptor(uri, "r")?.close()
            ?: throw FileNotFoundException("No video at $uri")
    }

    companion object {
        private const val VIDEO_MIME_TYPE = "video/mp4"
    }
}
