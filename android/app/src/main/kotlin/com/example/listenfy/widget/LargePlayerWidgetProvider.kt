package com.example.listenfy.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.support.v4.media.session.PlaybackStateCompat
import android.view.View
import android.widget.RemoteViews
import androidx.media.session.MediaButtonReceiver
import com.example.listenfy.MainActivity
import com.example.listenfy.R
import java.io.File

class LargePlayerWidgetProvider : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (PlayerWidgetProvider.ACTION_WIDGET_UPDATE == intent.action) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                android.content.ComponentName(context, LargePlayerWidgetProvider::class.java)
            )
            onUpdate(context, manager, ids)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context))
        }
    }

    private fun buildViews(context: Context): RemoteViews {
        val prefs = context.getSharedPreferences(PlayerWidgetProvider.PREFS, Context.MODE_PRIVATE)
        val title = prefs.getString(PlayerWidgetProvider.KEY_TITLE, "Listenfy") ?: "Listenfy"
        val artist = prefs.getString(PlayerWidgetProvider.KEY_ARTIST, "") ?: ""
        val artPath = prefs.getString(PlayerWidgetProvider.KEY_ART_PATH, "") ?: ""
        val playing = prefs.getBoolean(PlayerWidgetProvider.KEY_PLAYING, false)

        val views = RemoteViews(context.packageName, R.layout.player_widget_large)
        views.setTextViewText(R.id.widget_large_title, title)
        views.setTextViewText(R.id.widget_large_artist, artist)
        views.setViewVisibility(
            R.id.widget_large_artist,
            if (artist.isBlank()) View.GONE else View.VISIBLE
        )

        val bitmap = loadWidgetBitmap(artPath, 420)
        if (bitmap != null) {
            views.setImageViewBitmap(R.id.widget_large_cover, bitmap)
            views.setImageViewBitmap(R.id.widget_large_background, softenBackground(bitmap))
        } else {
            views.setImageViewResource(R.id.widget_large_cover, R.mipmap.ic_launcher)
            views.setImageViewResource(R.id.widget_large_background, R.mipmap.ic_launcher)
        }

        val playRes =
            if (playing) android.R.drawable.ic_media_pause
            else android.R.drawable.ic_media_play
        views.setImageViewResource(R.id.widget_large_play_pause, playRes)

        val contentPending = PendingIntent.getActivity(
            context,
            10,
            Intent(context, MainActivity::class.java),
            pendingFlags()
        )
        views.setOnClickPendingIntent(R.id.widget_large_root, contentPending)

        views.setOnClickPendingIntent(
            R.id.widget_large_prev,
            MediaButtonReceiver.buildMediaButtonPendingIntent(
                context,
                PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
            )
        )
        views.setOnClickPendingIntent(
            R.id.widget_large_play_pause,
            MediaButtonReceiver.buildMediaButtonPendingIntent(
                context,
                PlaybackStateCompat.ACTION_PLAY_PAUSE
            )
        )
        views.setOnClickPendingIntent(
            R.id.widget_large_next,
            MediaButtonReceiver.buildMediaButtonPendingIntent(
                context,
                PlaybackStateCompat.ACTION_SKIP_TO_NEXT
            )
        )

        return views
    }

    private fun loadWidgetBitmap(path: String, maxSize: Int): Bitmap? {
        if (path.isBlank()) return null
        val file = File(path)
        if (!file.exists()) return null

        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(file.absolutePath, bounds)
            var sample = 1
            while (bounds.outWidth / sample > maxSize || bounds.outHeight / sample > maxSize) {
                sample *= 2
            }
            val options = BitmapFactory.Options().apply { inSampleSize = sample }
            BitmapFactory.decodeFile(file.absolutePath, options)
        } catch (_: Throwable) {
            null
        }
    }

    private fun pendingFlags(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
    }

    private fun softenBackground(bitmap: Bitmap): Bitmap {
        return try {
            val tiny = Bitmap.createScaledBitmap(bitmap, 24, 24, true)
            val soft = Bitmap.createScaledBitmap(tiny, 420, 420, true)
            if (tiny != bitmap) tiny.recycle()
            soft
        } catch (_: Throwable) {
            bitmap
        }
    }
}
