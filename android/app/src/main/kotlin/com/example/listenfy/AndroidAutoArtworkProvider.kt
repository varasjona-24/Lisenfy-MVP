package com.example.listenfy

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import android.util.Log
import android.webkit.MimeTypeMap
import java.io.File
import java.io.FileNotFoundException
import java.nio.charset.StandardCharsets
import android.util.Base64

/**
 * Shares Listenfy's persisted covers and capture artwork with media clients.
 *
 * Media clients run outside this app process, so they cannot read the private
 * `file://` paths used by the Flutter UI. The canonical-path check keeps this
 * provider constrained to known image directories even though it is externally read.
 */
class AndroidAutoArtworkProvider : ContentProvider() {
    companion object {
        private const val tag = "ListenfyAutoArtwork"
    }

    override fun onCreate(): Boolean = true

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") {
            throw FileNotFoundException("Artwork is read-only")
        }

        return try {
            val file = resolvePlaybackCover(uri)
            ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        } catch (error: FileNotFoundException) {
            Log.w(tag, "Android Auto requested unavailable artwork", error)
            throw error
        }
    }

    override fun getType(uri: Uri): String {
        val extension = resolvePlaybackCover(uri).extension.lowercase()
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
            ?: "image/*"
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        val file = resolvePlaybackCover(uri)
        val columns = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        return MatrixCursor(columns).apply {
            addRow(columns.map { column ->
                when (column) {
                    OpenableColumns.DISPLAY_NAME -> file.name
                    OpenableColumns.SIZE -> file.length()
                    else -> null
                }
            })
        }
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0

    private fun resolvePlaybackCover(uri: Uri): File {
        val original = resolveCover(uri)
        val appContext = context ?: throw FileNotFoundException("Provider is unavailable")
        return try {
            PlaybackArtworkCache.squareCover(original, appContext.cacheDir)
        } catch (error: java.io.IOException) {
            // Keep an existing cover available if decoding or cache storage fails.
            Log.w(tag, "Cannot prepare square playback artwork", error)
            original
        }
    }

    private fun resolveCover(uri: Uri): File {
        val pathSegments = uri.pathSegments
        if (pathSegments.size != 2 || pathSegments.firstOrNull() != "cover") {
            throw FileNotFoundException("Unknown artwork URI")
        }

        val encodedPath = pathSegments[1]
        val requestedPath = try {
            val padding = "=".repeat((4 - (encodedPath.length % 4)) % 4)
            String(
                Base64.decode(encodedPath + padding, Base64.URL_SAFE or Base64.NO_WRAP),
                StandardCharsets.UTF_8,
            ).trim()
        } catch (_: IllegalArgumentException) {
            throw FileNotFoundException("Invalid artwork path")
        }
        if (requestedPath.isEmpty()) {
            throw FileNotFoundException("Missing artwork path")
        }
        val appContext = context ?: throw FileNotFoundException("Provider is unavailable")
        val requestedFile = File(requestedPath).canonicalFile
        val appDataDirectory = File(appContext.applicationInfo.dataDir).canonicalFile
        val externalFilesDirectory = appContext.getExternalFilesDir(null)?.canonicalFile
        val roots = arrayOf(
            appDataDirectory,
            File(appDataDirectory, "app_flutter"),
            appContext.filesDir,
            externalFilesDirectory,
            externalFilesDirectory?.let { File(it, "Documents") },
        )
        if (!ArtworkPathPolicy.isAllowed(requestedFile, roots)) {
            throw FileNotFoundException("Artwork file is unavailable")
        }

        return requestedFile
    }

}
