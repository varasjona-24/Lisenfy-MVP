package com.example.listenfy.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.os.Build
import android.widget.RemoteViews
import androidx.media.session.MediaButtonReceiver
import androidx.palette.graphics.Palette
import android.support.v4.media.session.PlaybackStateCompat
import com.example.listenfy.MainActivity
import com.example.listenfy.R
import android.view.View
import java.io.File
import kotlin.math.pow

class PlayerWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (ACTION_WIDGET_UPDATE == intent.action) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                android.content.ComponentName(context, PlayerWidgetProvider::class.java)
            )
            onUpdate(context, mgr, ids)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            val views = buildViews(context)
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun buildViews(context: Context): RemoteViews {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val title = prefs.getString(KEY_TITLE, "Listenfy") ?: "Listenfy"
        val artist = prefs.getString(KEY_ARTIST, "") ?: ""
        val artPath = prefs.getString(KEY_ART_PATH, "") ?: ""
        val playing = prefs.getBoolean(KEY_PLAYING, false)

        // Tu color guardado (lo usamos si no hay portada)
        val fallbackBg = Color.parseColor("#151A23")
        val fallbackBar = prefs.getInt(KEY_BAR_COLOR, 0xFF1E2633.toInt())

        val views = RemoteViews(context.packageName, R.layout.player_widget)

        // Text
        views.setTextViewText(R.id.widget_title, title)
        views.setTextViewText(R.id.widget_artist, artist)
        views.setViewVisibility(
            R.id.widget_artist,
            if (artist.isBlank()) View.GONE else View.VISIBLE
        )

        // --- Load cover bitmap (si existe) ---
        val coverFile = if (artPath.isNotEmpty()) File(artPath) else null
        val bitmap: Bitmap? =
            if (coverFile != null && coverFile.exists()) BitmapFactory.decodeFile(coverFile.absolutePath)
            else null

        val bgColor: Int
        if (bitmap != null) {
            views.setImageViewBitmap(R.id.widget_cover, bitmap)
            bgColor = extractCoverBackground(bitmap, fallbackBg)
        } else {
            views.setImageViewResource(R.id.widget_cover, R.mipmap.ic_launcher)
            bgColor = fallbackBg
        }

        // Fondo del widget completo
        views.setInt(R.id.widget_root, "setBackgroundColor", bgColor)

        // Controles: mismo color pero un poco más oscuro (se ve más “pro”)
        val barColor = if (bgColor != fallbackBg) darkenColor(bgColor, 0.78f) else fallbackBar
        views.setInt(R.id.widget_controls, "setBackgroundColor", barColor)

        // Contraste automático
        val primaryTextColor = chooseTextColor(bgColor)
        val secondaryTextColor = adjustSecondaryTextColor(primaryTextColor)

        views.setTextColor(R.id.widget_title, primaryTextColor)
        views.setTextColor(R.id.widget_artist, secondaryTextColor)

        // Iconos según contraste (RemoteViews-friendly)
        val iconColor = primaryTextColor
        tintImageButton(views, R.id.widget_prev, iconColor)
        tintImageButton(views, R.id.widget_next, iconColor)
        tintImageButton(views, R.id.widget_play_pause, iconColor)
        views.setInt(R.id.widget_logo, "setColorFilter", iconColor)

        // Play / Pause icon
        val playRes =
            if (playing) android.R.drawable.ic_media_pause
            else android.R.drawable.ic_media_play
        views.setImageViewResource(R.id.widget_play_pause, playRes)

        // Open app on click
        val contentIntent = Intent(context, MainActivity::class.java)
        val contentPending = PendingIntent.getActivity(
            context,
            0,
            contentIntent,
            pendingFlags()
        )
        views.setOnClickPendingIntent(R.id.widget_root, contentPending)

        // Media buttons
        val prevIntent = MediaButtonReceiver.buildMediaButtonPendingIntent(
            context,
            PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
        )
        val playPauseIntent = MediaButtonReceiver.buildMediaButtonPendingIntent(
            context,
            PlaybackStateCompat.ACTION_PLAY_PAUSE
        )
        val nextIntent = MediaButtonReceiver.buildMediaButtonPendingIntent(
            context,
            PlaybackStateCompat.ACTION_SKIP_TO_NEXT
        )

        views.setOnClickPendingIntent(R.id.widget_prev, prevIntent)
        views.setOnClickPendingIntent(R.id.widget_play_pause, playPauseIntent)
        views.setOnClickPendingIntent(R.id.widget_next, nextIntent)

        return views
    }

    private fun tintImageButton(views: RemoteViews, viewId: Int, color: Int) {
        // setColorFilter(int) existe en ImageView y suele funcionar bien en widgets
        views.setInt(viewId, "setColorFilter", color)
    }

    private fun pendingFlags(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
    }

    // -------------------------
    // Color helpers
    // -------------------------

   private fun extractCoverBackground(bitmap: Bitmap, fallback: Int): Int {
    return try {
        val palette = Palette.from(bitmap).generate()
        palette.getDominantColor(fallback) // <- tal cual, sin oscurecer
    } catch (e: Exception) {
        fallback
    }
}



    private fun darkenColor(color: Int, factor: Float = 0.88f): Int {
        val r = (Color.red(color) * factor).toInt().coerceIn(0, 255)
        val g = (Color.green(color) * factor).toInt().coerceIn(0, 255)
        val b = (Color.blue(color) * factor).toInt().coerceIn(0, 255)
        return Color.rgb(r, g, b)
    }

    private fun chooseTextColor(bgColor: Int): Int {
        val luminance = relativeLuminance(bgColor)
        return if (luminance > 0.55) Color.BLACK else Color.WHITE
    }

    private fun adjustSecondaryTextColor(primary: Int): Int {
        return if (primary == Color.WHITE) Color.parseColor("#C9D1E3")
        else Color.parseColor("#2B3342")
    }

    private fun relativeLuminance(color: Int): Double {
        fun channel(c: Int): Double {
            val v = c / 255.0
            return if (v <= 0.03928) v / 12.92 else ((v + 0.055) / 1.055).pow(2.4)
        }

        val r = channel(Color.red(color))
        val g = channel(Color.green(color))
        val b = channel(Color.blue(color))
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    companion object {
        const val ACTION_WIDGET_UPDATE =
            "com.example.listenfy.ACTION_WIDGET_UPDATE"

        const val PREFS = "player_widget"
        const val KEY_TITLE = "title"
        const val KEY_ARTIST = "artist"
        const val KEY_ART_PATH = "artPath"
        const val KEY_PLAYING = "playing"
        const val KEY_BAR_COLOR = "barColor"
        const val KEY_LOGO_COLOR = "logoColor"
    }
}
