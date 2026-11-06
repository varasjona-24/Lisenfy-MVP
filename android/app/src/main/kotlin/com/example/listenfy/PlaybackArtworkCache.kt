package com.example.listenfy

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import java.io.File
import java.io.IOException
import java.security.MessageDigest

/** Derived media artwork; never edits the user's original cover. */
internal object PlaybackArtworkCache {
    private const val maxSide = 512
    private const val maxEntries = 64

    @Synchronized
    fun squareCover(source: File, cacheRoot: File): File {
        val directory = File(cacheRoot, "playback-artwork-v2")
        if (!directory.isDirectory && !directory.mkdirs()) {
            throw IOException("Cannot create playback artwork cache")
        }
        val signature = "${source.canonicalPath}|${source.length()}|${source.lastModified()}"
        val key = MessageDigest.getInstance("SHA-256")
            .digest(signature.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it.toInt() and 0xff) }
        val target = File(directory, "$key.png")
        if (target.isFile && target.length() > 0) {
            target.setLastModified(System.currentTimeMillis())
            return target
        }

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(source.path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            throw IOException("Invalid artwork image")
        }
        // Bound decoded memory even when a full-resolution capture is selected.
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / sample > maxSide * 2) {
            sample *= 2
        }
        val decoded = BitmapFactory.decodeFile(source.path,
            BitmapFactory.Options().apply { inSampleSize = sample })
            ?: throw IOException("Cannot decode artwork")
        try {
            val crop = ArtworkCropBounds.centeredSquare(decoded.width, decoded.height)
            val size = minOf(maxSide, crop[2] - crop[0])
            val square = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            try {
                Canvas(square).drawBitmap(decoded,
                    Rect(crop[0], crop[1], crop[2], crop[3]),
                    Rect(0, 0, size, size), Paint(Paint.FILTER_BITMAP_FLAG))
                val temporary = File.createTempFile("cover-", ".tmp", directory)
                try {
                    temporary.outputStream().use {
                        if (!square.compress(Bitmap.CompressFormat.PNG, 100, it)) {
                            throw IOException("Cannot encode artwork")
                        }
                    }
                    if (!temporary.renameTo(target)) {
                        throw IOException("Cannot persist artwork")
                    }
                } finally {
                    temporary.delete()
                }
            } finally {
                square.recycle()
            }
        } finally {
            decoded.recycle()
        }
        directory.listFiles { file -> file.extension == "png" }
            ?.sortedByDescending { it.lastModified() }
            ?.drop(maxEntries)
            ?.filter { it != target }
            ?.forEach { it.delete() }
        return target
    }
}
