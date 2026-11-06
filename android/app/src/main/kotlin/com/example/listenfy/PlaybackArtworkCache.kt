package com.example.listenfy

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Typeface
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
    fun letterCover(context: Context, letter: String): File {
        // Bounded alphabet and safe filenames, including the non-Latin group.
        require(letter == "#" || Regex("[A-Z]").matches(letter))
        val directory = File(context.cacheDir, "playback-letters-v1")
        if (!directory.isDirectory && !directory.mkdirs()) {
            throw IOException("Cannot create artist initial cache")
        }
        val target = File(directory, "${if (letter == "#") "other" else letter}.png")
        if (target.isFile && target.length() > 0) return target
        val bitmap = Bitmap.createBitmap(256, 256, Bitmap.Config.ARGB_8888)
        try {
            val canvas = Canvas(bitmap)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            paint.color = Color.rgb(42, 49, 56)
            canvas.drawRoundRect(0f, 0f, 256f, 256f, 28f, 28f, paint)
            paint.color = Color.WHITE
            paint.textSize = 144f
            paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            paint.textAlign = Paint.Align.CENTER
            val metrics = paint.fontMetrics
            canvas.drawText(letter, 128f, 128f - (metrics.ascent + metrics.descent) / 2f, paint)
            val temporary = File.createTempFile("letter-", ".tmp", directory)
            try {
                temporary.outputStream().use {
                    if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)) {
                        throw IOException("Cannot encode artist initial")
                    }
                }
                if (!temporary.renameTo(target)) throw IOException("Cannot persist artist initial")
            } finally {
                temporary.delete()
            }
        } finally {
            bitmap.recycle()
        }
        return target
    }

    @Synchronized
    fun iconCover(context: Context, name: String, resource: Int): File {
        val directory = File(context.cacheDir, "playback-icons-v1")
        if (!directory.isDirectory && !directory.mkdirs()) {
            throw IOException("Cannot create media icon cache")
        }
        val target = File(directory, "$name.png")
        if (target.isFile && target.length() > 0) return target
        val drawable = context.getDrawable(resource)
            ?: throw IOException("Cannot load media icon")
        val bitmap = Bitmap.createBitmap(128, 128, Bitmap.Config.ARGB_8888)
        try {
            drawable.setBounds(16, 16, 112, 112)
            drawable.draw(Canvas(bitmap))
            val temporary = File.createTempFile("icon-", ".tmp", directory)
            try {
                temporary.outputStream().use {
                    if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)) {
                        throw IOException("Cannot encode media icon")
                    }
                }
                if (!temporary.renameTo(target)) throw IOException("Cannot persist media icon")
            } finally {
                temporary.delete()
            }
        } finally {
            bitmap.recycle()
        }
        return target
    }

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
