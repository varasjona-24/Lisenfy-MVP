package com.example.flutter_listenfy

import android.graphics.Bitmap
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Rational
import android.app.PictureInPictureParams
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.MediaMetadataRetriever
import android.media.audiofx.BassBoost
import android.media.audiofx.EnvironmentalReverb
import android.media.audiofx.LoudnessEnhancer
import android.media.audiofx.PresetReverb
import android.media.audiofx.Visualizer
import android.media.audiofx.Virtualizer
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.example.flutter_listenfy.widget.PlayerWidgetProvider
import android.content.Intent
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.HashMap
import android.provider.MediaStore
import kotlin.math.log10
import kotlin.math.abs
import kotlin.math.roundToInt
import kotlin.math.sqrt
import kotlin.math.floor
import kotlin.math.ceil
import kotlin.math.pow
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : AudioServiceActivity() {
    private val channel = "listenfy/bluetooth_audio"
    private val spatialChannel = "listenfy/spatial_audio"
    private val openalChannel = "listenfy/openal"
    private val audioCleanupChannel = "listenfy/audio_cleanup"
    private val audioWaveformChannel = "listenfy/audio_waveform"
    private val karaokeRecorderChannel = "listenfy/karaoke_recorder"
    private val audioVisualizerChannel = "listenfy/audio_visualizer"
    private val audioVisualizerEventsChannel = "listenfy/audio_visualizer/events"
    private val pipChannel = "listenfy/pip"
    private val videoPreviewChannel = "listenfy/video_preview"
    private val widgetChannel = "listenfy/player_widget"
    private var pipEnabled: Boolean = false
    private var pipAspect: Double = 1.777777
    private var pipWidth: Int? = null
    private var pipHeight: Int? = null
    private var spatialSessionId: Int? = null
    private var virtualizer: Virtualizer? = null
    private var bassBoost: BassBoost? = null
    private var reverb: PresetReverb? = null
    private var envReverb: EnvironmentalReverb? = null
    private var loudness: LoudnessEnhancer? = null
    private var audioVisualizer: Visualizer? = null
    private var audioVisualizerSink: EventChannel.EventSink? = null
    private var audioVisualizerSessionId: Int? = null
    private var audioVisualizerMode: String = "waveform"
    private var audioVisualizerBarCount: Int = 72
    private var audioVisualizerLastBars: DoubleArray = DoubleArray(0)
    private var audioVisualizerLastEmitAtMs: Long = 0L
    private val uiHandler = Handler(Looper.getMainLooper())
    private val karaokeRecorderEngine by lazy { KaraokeRecorderEngine(applicationContext) }

    private data class SilenceSegment(
        val startMs: Int,
        val endMs: Int,
        val durationMs: Int,
        val meanDb: Double
    )

    private data class FrameRange(
        val startFrame: Int,
        val endFrame: Int
    )


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                if (call.method != "getAudioDevices") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val manager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                val adapter: BluetoothAdapter? = manager?.adapter

                if (adapter == null || !adapter.isEnabled) {
                    result.success(
                        mapOf(
                            "bluetoothOn" to false,
                            "devices" to emptyList<Map<String, Any>>(),
                            "outputs" to emptyList<String>()
                        )
                    )
                    return@setMethodCallHandler
                }

                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val outputKinds = linkedSetOf<String>()
                for (device in audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)) {
                    when (device.type) {
                        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                        AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> outputKinds.add("bluetooth")
                        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                        AudioDeviceInfo.TYPE_WIRED_HEADSET,
                        AudioDeviceInfo.TYPE_USB_HEADSET,
                        AudioDeviceInfo.TYPE_USB_DEVICE -> outputKinds.add("wired")
                        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> outputKinds.add("speaker")
                        AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> outputKinds.add("earpiece")
                    }
                }

                val responded = AtomicBoolean(false)

                adapter.getProfileProxy(
                    this,
                    object : BluetoothProfile.ServiceListener {
                        override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                            if (profile != BluetoothProfile.A2DP) return

                            val devices = proxy.connectedDevices.map { device ->
                                val battery = try {
                                    val method = device.javaClass.getMethod("getBatteryLevel")
                                    (method.invoke(device) as? Int) ?: -1
                                } catch (_: Throwable) {
                                    -1
                                }
                                mapOf(
                                    "name" to (device.name ?: ""),
                                    "address" to device.address,
                                    "kind" to "bluetooth",
                                    "battery" to battery
                                )
                            }

                            if (responded.compareAndSet(false, true)) {
                                result.success(
                                    mapOf(
                                        "bluetoothOn" to true,
                                        "devices" to devices,
                                        "outputs" to outputKinds.toList()
                                    )
                                )
                            }

                            adapter.closeProfileProxy(profile, proxy)
                        }

                        override fun onServiceDisconnected(profile: Int) {
                            if (responded.compareAndSet(false, true)) {
                                result.success(
                                    mapOf(
                                        "bluetoothOn" to true,
                                        "devices" to emptyList<Map<String, Any>>(),
                                        "outputs" to outputKinds.toList()
                                    )
                                )
                            }
                        }
                    },
                    BluetoothProfile.A2DP
                )
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, spatialChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val sessionId = call.argument<Int>("sessionId") ?: 0
                        if (sessionId <= 0) {
                            result.error("NO_SESSION", "Invalid audio session", null)
                            return@setMethodCallHandler
                        }
                        try {
                            if (enabled) {
                                if (virtualizer == null || spatialSessionId != sessionId) {
                                    releaseSpatial()
                                    spatialSessionId = sessionId
                                    virtualizer = Virtualizer(0, sessionId).apply {
                                        setStrength(1000.toShort())
                                        this.enabled = true
                                    }
                                    bassBoost = BassBoost(0, sessionId).apply {
                                        setStrength(200.toShort())
                                        setEnabled(true)
                                    }
                                    reverb = PresetReverb(0, sessionId).apply {
                                        preset = PresetReverb.PRESET_LARGEHALL
                                        setEnabled(true)
                                    }
                                    envReverb = EnvironmentalReverb(0, sessionId).apply {
                                        roomLevel = 0.toShort()
                                        roomHFLevel = 0.toShort()
                                        decayTime = 7000
                                        decayHFRatio = 2000
                                        reflectionsLevel = 0.toShort()
                                        reflectionsDelay = 120
                                        reverbLevel = 0.toShort()
                                        reverbDelay = 180
                                        diffusion = 1000
                                        density = 1000
                                        setEnabled(true)
                                    }
                                    loudness = LoudnessEnhancer(sessionId).apply {
                                        setTargetGain(900)
                                        setEnabled(true)
                                    }
                                } else {
                                    virtualizer?.enabled = true
                                    bassBoost?.enabled = true
                                    reverb?.enabled = true
                                    envReverb?.enabled = true
                                    loudness?.enabled = true
                                }
                            } else {
                                releaseSpatial()
                            }
                            result.success(true)
                        } catch (e: Throwable) {
                            releaseSpatial()
                            result.error("SPATIAL_ERROR", e.message, null)
                        }
                    }
                    "release" -> {
                        releaseSpatial()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pipChannel)
            .setMethodCallHandler { call, result ->
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "setEnabled" -> {
                        pipEnabled = call.argument<Boolean>("enabled") ?: false
                        pipAspect = call.argument<Double>("aspect") ?: 1.777777
                        pipWidth = call.argument<Int>("width")
                        pipHeight = call.argument<Int>("height")
                        result.success(true)
                    }
                    "enter" -> {
                        val width = call.argument<Int>("width")
                        val height = call.argument<Int>("height")
                        val aspect = call.argument<Double>("aspect") ?: 1.777777
                        val ratio = buildPipRational(width, height, aspect)
                        val builder = PictureInPictureParams.Builder()
                            .setAspectRatio(ratio)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            builder.setExpandedAspectRatio(ratio)
                            builder.setSeamlessResizeEnabled(true)
                        }
                        val params = builder.build()
                        val ok = enterPictureInPictureMode(params)
                        result.success(ok)
                    }
                    "exit" -> {
                        // No-op: system exits PiP when activity resumes.
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, videoPreviewChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "extractFrame" -> {
                        val source = call.argument<String>("source")?.trim().orEmpty()
                        val positionMs = call.argument<Int>("positionMs") ?: 0
                        val maxWidth = (call.argument<Int>("maxWidth") ?: 240).coerceAtLeast(64)
                        val quality = (call.argument<Int>("quality") ?: 72).coerceIn(40, 90)

                        if (source.isBlank()) {
                            result.success(null)
                            return@setMethodCallHandler
                        }

                        Thread {
                            var bitmap: Bitmap? = null
                            var output: ByteArrayOutputStream? = null

                            try {
                                bitmap = extractVideoFrameBitmap(source, positionMs, maxWidth)
                                if (bitmap == null) {
                                    runOnUiThread { result.success(null) }
                                    return@Thread
                                }

                                output = ByteArrayOutputStream()
                                bitmap.compress(Bitmap.CompressFormat.JPEG, quality, output)
                                val bytes = output.toByteArray()
                                runOnUiThread { result.success(bytes) }
                            } catch (_: Throwable) {
                                runOnUiThread { result.success(null) }
                            } finally {
                                try {
                                    output?.close()
                                } catch (_: Throwable) {}
                                bitmap?.recycle()
                            }
                        }.start()
                    }
                    "saveFrame" -> {
                        val source = call.argument<String>("source")?.trim().orEmpty()
                        val title = call.argument<String>("title")?.trim().orEmpty()
                        val positionMs = call.argument<Int>("positionMs") ?: 0
                        val maxWidth = (call.argument<Int>("maxWidth") ?: 1920).coerceAtLeast(128)
                        val quality = (call.argument<Int>("quality") ?: 92).coerceIn(50, 100)

                        if (source.isBlank()) {
                            result.success(null)
                            return@setMethodCallHandler
                        }

                        Thread {
                            var bitmap: Bitmap? = null
                            try {
                                bitmap = extractVideoFrameBitmap(source, positionMs, maxWidth)
                                if (bitmap == null) {
                                    runOnUiThread { result.success(null) }
                                    return@Thread
                                }

                                val saved = saveBitmapToGallery(bitmap, title, quality)
                                runOnUiThread { result.success(saved) }
                            } catch (_: Throwable) {
                                runOnUiThread { result.success(null) }
                            } finally {
                                bitmap?.recycle()
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, widgetChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "updateWidget") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val title = call.argument<String>("title") ?: ""
                val artist = call.argument<String>("artist") ?: ""
                val artPath = call.argument<String>("artPath") ?: ""
                val playing = call.argument<Boolean>("playing") ?: false
                val barColorAny = call.argument<Any>("barColor")
                val barColor = when (barColorAny) {
                    is Int -> barColorAny
                    is Long -> barColorAny.toInt()
                    is Double -> barColorAny.toInt()
                    else -> 0xFF1E2633.toInt()
                }
                val logoColorAny = call.argument<Any>("logoColor")
                val logoColor = when (logoColorAny) {
                    is Int -> logoColorAny
                    is Long -> logoColorAny.toInt()
                    is Double -> logoColorAny.toInt()
                    else -> 0xFFFFFFFF.toInt()
                }

                val prefs = getSharedPreferences(PlayerWidgetProvider.PREFS, Context.MODE_PRIVATE)
                prefs.edit()
                    .putString(PlayerWidgetProvider.KEY_TITLE, title)
                    .putString(PlayerWidgetProvider.KEY_ARTIST, artist)
                    .putString(PlayerWidgetProvider.KEY_ART_PATH, artPath)
                    .putBoolean(PlayerWidgetProvider.KEY_PLAYING, playing)
                    .putInt(PlayerWidgetProvider.KEY_BAR_COLOR, barColor)
                    .putInt(PlayerWidgetProvider.KEY_LOGO_COLOR, logoColor)
                    .apply()

                val intent = Intent(this, PlayerWidgetProvider::class.java).apply {
                    action = PlayerWidgetProvider.ACTION_WIDGET_UPDATE
                }
                sendBroadcast(intent)

                result.success(true)
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, openalChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playFile" -> {
                        val path = call.argument<String>("path") ?: ""
                        val enableHrtf = call.argument<Boolean>("enableHrtf") ?: true
                        if (path.isBlank()) {
                            result.error("NO_PATH", "Path required", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            val pcm = OpenALBridge.decodeToPcm(path)
                            if (pcm == null) {
                                runOnUiThread {
                                    result.error("DECODE_FAIL", "Decode failed", null)
                                }
                                return@Thread
                            }
                            val ok = OpenALBridge.nativePlay(
                                pcm.bytes,
                                pcm.sampleRate,
                                pcm.channels,
                                enableHrtf
                            )
                            val durationMs =
                                (pcm.bytes.size / (2 * pcm.channels) * 1000L) / pcm.sampleRate
                            runOnUiThread {
                                if (ok) {
                                    result.success(
                                        mapOf(
                                            "durationMs" to durationMs,
                                            "sampleRate" to pcm.sampleRate,
                                            "channels" to pcm.channels
                                        )
                                    )
                                } else {
                                    result.error("OPENAL_FAIL", "OpenAL failed", null)
                                }
                            }
                        }.start()
                    }
                    "pause" -> {
                        OpenALBridge.nativePause()
                        result.success(true)
                    }
                    "resume" -> {
                        OpenALBridge.nativeResume()
                        result.success(true)
                    }
                    "seek" -> {
                        val seconds = call.argument<Double>("seconds") ?: 0.0
                        OpenALBridge.nativeSeek(seconds.toFloat())
                        result.success(true)
                    }
                    "stop" -> {
                        OpenALBridge.nativeStop()
                        result.success(true)
                    }
                    "release" -> {
                        OpenALBridge.nativeRelease()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, audioCleanupChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "analyzeSilences" -> {
                        val path = call.argument<String>("path")?.trim().orEmpty()
                        if (path.isBlank()) {
                            result.error("NO_PATH", "Path required", null)
                            return@setMethodCallHandler
                        }

                        val minSilenceMs =
                            numberAsInt(call.argument<Any>("minSilenceMs"), 4000).coerceAtLeast(500)
                        val windowMs =
                            numberAsInt(call.argument<Any>("windowMs"), 50).coerceAtLeast(10)
                        val thresholdDb =
                            numberAsDouble(call.argument<Any>("thresholdDb"), -35.0)

                        Thread {
                            try {
                                val payload = analyzeSilencesNative(
                                    path = path,
                                    minSilenceMs = minSilenceMs,
                                    windowMs = windowMs,
                                    thresholdDb = thresholdDb
                                )
                                runOnUiThread { result.success(payload) }
                            } catch (e: Throwable) {
                                runOnUiThread {
                                    result.error(
                                        "ANALYZE_FAIL",
                                        e.message ?: "Silence analysis failed",
                                        null
                                    )
                                }
                            }
                        }.start()
                    }
                    "renderCleanedAudio" -> {
                        val path = call.argument<String>("path")?.trim().orEmpty()
                        if (path.isBlank()) {
                            result.error("NO_PATH", "Path required", null)
                            return@setMethodCallHandler
                        }

                        val fadeMs = numberAsInt(call.argument<Any>("fadeMs"), 20).coerceIn(0, 80)
                        val rawRanges = call.argument<List<*>>("removeRanges") ?: emptyList<Any>()
                        val removeRanges = parseRemovalRangesMs(rawRanges)

                        if (removeRanges.isEmpty()) {
                            result.error("NO_RANGES", "removeRanges required", null)
                            return@setMethodCallHandler
                        }

                        Thread {
                            try {
                                val payload = renderCleanedAudioNative(
                                    path = path,
                                    removeRangesMs = removeRanges,
                                    fadeMs = fadeMs
                                )
                                runOnUiThread { result.success(payload) }
                            } catch (e: Throwable) {
                                runOnUiThread {
                                    result.error(
                                        "RENDER_FAIL",
                                        e.message ?: "Audio cleanup failed",
                                        null
                                    )
                                }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, karaokeRecorderChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isRecording" -> {
                        result.success(karaokeRecorderEngine.isRecording())
                    }
                    "startSession" -> {
                        val sourcePath = call.argument<String>("sourcePath")?.trim().orEmpty()
                        if (sourcePath.isBlank()) {
                            result.error("NO_PATH", "sourcePath required", null)
                            return@setMethodCallHandler
                        }
                        val instrumentalPath = call.argument<String>("instrumentalPath")
                            ?.trim()
                            ?.ifBlank { null }

                        val instrumentalGain = numberAsDouble(
                            call.argument<Any>("instrumentalGain"),
                            1.0
                        ).coerceIn(0.10, 1.80)

                        Thread {
                            try {
                                val payload = karaokeRecorderEngine.startSession(
                                    sourcePathRaw = sourcePath,
                                    instrumentalGainRaw = instrumentalGain,
                                    instrumentalPathOverrideRaw = instrumentalPath
                                )
                                runOnUiThread { result.success(payload) }
                            } catch (e: Throwable) {
                                runOnUiThread {
                                    result.error(
                                        "KARAOKE_START_FAIL",
                                        e.message ?: "No se pudo iniciar karaoke.",
                                        null
                                    )
                                }
                            }
                        }.start()
                    }
                    "stopSession" -> {
                        val exportMixed = call.argument<Boolean>("exportMixed") ?: true
                        val voiceGain = numberAsDouble(call.argument<Any>("voiceGain"), 1.0)
                            .coerceIn(0.0, 2.0)
                        val instrumentalGain =
                            numberAsDouble(call.argument<Any>("instrumentalGain"), 0.8)
                                .coerceIn(0.0, 2.0)

                        Thread {
                            try {
                                val payload = karaokeRecorderEngine.stopSession(
                                    exportMixed = exportMixed,
                                    voiceGainRaw = voiceGain,
                                    instrumentalGainRaw = instrumentalGain
                                )
                                runOnUiThread { result.success(payload) }
                            } catch (e: Throwable) {
                                runOnUiThread {
                                    result.error(
                                        "KARAOKE_STOP_FAIL",
                                        e.message ?: "No se pudo detener karaoke.",
                                        null
                                    )
                                }
                            }
                        }.start()
                    }
                    "cancelSession" -> {
                        Thread {
                            try {
                                val canceled = karaokeRecorderEngine.cancelSession()
                                runOnUiThread { result.success(canceled) }
                            } catch (e: Throwable) {
                                runOnUiThread {
                                    result.error(
                                        "KARAOKE_CANCEL_FAIL",
                                        e.message ?: "No se pudo cancelar karaoke.",
                                        null
                                    )
                                }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, audioWaveformChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "extractWaveform" -> {
                        val path = call.argument<String>("path")?.trim().orEmpty()
                        if (path.isBlank()) {
                            result.error("NO_PATH", "Path required", null)
                            return@setMethodCallHandler
                        }

                        val buckets = numberAsInt(call.argument<Any>("buckets"), 72)
                            .coerceIn(16, 256)

                        Thread {
                            try {
                                val payload = extractWaveformNative(path, buckets)
                                runOnUiThread { result.success(payload) }
                            } catch (e: Throwable) {
                                runOnUiThread {
                                    result.error(
                                        "WAVEFORM_FAIL",
                                        e.message ?: "Waveform extraction failed",
                                        null
                                    )
                                }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, audioVisualizerChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "attach" -> {
                        val sessionId = numberAsInt(call.argument<Any>("sessionId"), -1)
                        if (sessionId <= 0) {
                            result.error("NO_SESSION", "Valid sessionId required", null)
                            return@setMethodCallHandler
                        }

                        val barCount = numberAsInt(call.argument<Any>("barCount"), 72)
                            .coerceIn(16, 128)
                        val captureMode = (call.argument<String>("captureMode") ?: "waveform")
                            .trim()
                            .lowercase()

                        try {
                            attachAudioVisualizer(
                                sessionId = sessionId,
                                barCount = barCount,
                                mode = captureMode
                            )
                            result.success(true)
                        } catch (e: Throwable) {
                            result.error(
                                "VISUALIZER_ATTACH_FAIL",
                                e.message ?: "No se pudo activar visualizador",
                                null
                            )
                        }
                    }
                    "detach" -> {
                        detachAudioVisualizer()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, audioVisualizerEventsChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    audioVisualizerSink = events
                }

                override fun onCancel(arguments: Any?) {
                    audioVisualizerSink = null
                    detachAudioVisualizer()
                }
            })

    }

    override fun onDestroy() {
        karaokeRecorderEngine.release()
        detachAudioVisualizer()
        releaseSpatial()
        super.onDestroy()
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (!pipEnabled) return
        val ratio = buildPipRational(pipWidth, pipHeight, pipAspect)
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(ratio)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setExpandedAspectRatio(ratio)
            builder.setSeamlessResizeEnabled(true)
        }
        val params = builder.build()
        enterPictureInPictureMode(params)
    }

    private fun buildPipRational(width: Int?, height: Int?, aspect: Double): Rational {
        val ratio = when {
            width != null && height != null && width > 0 && height > 0 ->
                width.toDouble() / height.toDouble()
            else -> aspect
        }

        val minRatio = 1.0 / 2.39
        val maxRatio = 2.39
        val clamped = ratio.coerceIn(minRatio, maxRatio)
        val w = 1000
        val h = (w / clamped).roundToInt().coerceAtLeast(1)
        return Rational(w, h)
    }

    private fun extractVideoFrameBitmap(source: String, positionMs: Int, maxWidth: Int): Bitmap? {
        var retriever: MediaMetadataRetriever? = null
        var bitmap: Bitmap? = null
        var scaledBitmap: Bitmap? = null

        try {
            retriever = MediaMetadataRetriever()
            if (source.startsWith("http://") || source.startsWith("https://")) {
                retriever.setDataSource(source, HashMap<String, String>())
            } else {
                retriever.setDataSource(source.removePrefix("file://"))
            }

            val timeUs = positionMs.coerceAtLeast(0).toLong() * 1000L
            bitmap = retriever.getFrameAtTime(
                timeUs,
                MediaMetadataRetriever.OPTION_CLOSEST
            ) ?: retriever.getFrameAtTime(
                timeUs,
                MediaMetadataRetriever.OPTION_PREVIOUS_SYNC
            ) ?: retriever.getFrameAtTime(
                timeUs,
                MediaMetadataRetriever.OPTION_CLOSEST_SYNC
            )

            val frame = bitmap ?: return null
            if (frame.width <= maxWidth) {
                return frame.copy(Bitmap.Config.ARGB_8888, false)
            }

            val targetHeight = (frame.height * (maxWidth.toFloat() / frame.width.toFloat()))
                .roundToInt()
                .coerceAtLeast(1)
            scaledBitmap = Bitmap.createScaledBitmap(frame, maxWidth, targetHeight, true)
            return scaledBitmap.copy(Bitmap.Config.ARGB_8888, false)
        } finally {
            if (scaledBitmap != null) {
                scaledBitmap.recycle()
            }
            bitmap?.recycle()
            retriever?.release()
        }
    }

    private fun saveBitmapToGallery(
        bitmap: Bitmap,
        title: String,
        quality: Int
    ): Map<String, String>? {
        val resolver = contentResolver
        val safeTitle = sanitizeFileName(title.ifBlank { "video" })
        val displayName = "Listenfy_${safeTitle}_${System.currentTimeMillis()}.jpg"
        val relativePath = "${Environment.DIRECTORY_PICTURES}/Listenfy"

        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
            put(MediaStore.Images.Media.RELATIVE_PATH, relativePath)
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }

        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values) ?: return null

        try {
            resolver.openOutputStream(uri)?.use { stream ->
                if (!bitmap.compress(Bitmap.CompressFormat.JPEG, quality, stream)) {
                    throw IllegalStateException("compress failed")
                }
            } ?: throw IllegalStateException("output stream unavailable")

            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return mapOf(
                "displayName" to displayName,
                "uri" to uri.toString()
            )
        } catch (_: Throwable) {
            resolver.delete(uri, null, null)
            return null
        }
    }

    private fun sanitizeFileName(value: String): String {
        val sanitized = value.replace(Regex("[^A-Za-z0-9 _-]"), "")
            .trim()
            .replace(Regex("\\s+"), "_")
        return if (sanitized.isBlank()) "video" else sanitized
    }

    private fun numberAsInt(value: Any?, fallback: Int): Int {
        return when (value) {
            is Int -> value
            is Long -> value.toInt()
            is Double -> value.roundToInt()
            is Float -> value.roundToInt()
            is String -> value.toDoubleOrNull()?.roundToInt() ?: fallback
            else -> fallback
        }
    }

    private fun numberAsDouble(value: Any?, fallback: Double): Double {
        return when (value) {
            is Int -> value.toDouble()
            is Long -> value.toDouble()
            is Double -> value
            is Float -> value.toDouble()
            is String -> value.toDoubleOrNull() ?: fallback
            else -> fallback
        }
    }

    private fun parseRemovalRangesMs(rawRanges: List<*>): List<Pair<Int, Int>> {
        val out = mutableListOf<Pair<Int, Int>>()
        for (entry in rawRanges) {
            if (entry !is Map<*, *>) continue
            val startMs = numberAsInt(entry["startMs"], -1)
            val endMs = numberAsInt(entry["endMs"], -1)
            if (startMs < 0 || endMs <= startMs) continue
            out.add(startMs to endMs)
        }
        return out
    }

    private fun normalizePathForMediaExtractor(path: String): String {
        return path.removePrefix("file://").trim()
    }

    private fun analyzeSilencesNative(
        path: String,
        minSilenceMs: Int,
        windowMs: Int,
        thresholdDb: Double
    ): Map<String, Any> {
        val normalizedPath = normalizePathForMediaExtractor(path)
        val pcm = OpenALBridge.decodeToPcm(normalizedPath)
            ?: throw IllegalStateException("No se pudo decodificar audio.")

        val sampleRate = pcm.sampleRate.coerceAtLeast(1)
        val channels = pcm.channels.coerceAtLeast(1)
        val bytes = pcm.bytes
        val totalFrames = bytes.size / (2 * channels)
        val durationMs = ((totalFrames * 1000L) / sampleRate).toInt()

        if (totalFrames <= 0) {
            return mapOf(
                "durationMs" to 0,
                "sampleRate" to sampleRate,
                "channels" to channels,
                "segments" to emptyList<Map<String, Any>>()
            )
        }

        val windowFrames = ((windowMs.toLong() * sampleRate) / 1000L).toInt().coerceAtLeast(1)
        val rawSegments = mutableListOf<SilenceSegment>()

        var frame = 0
        var inSilence = false
        var silenceStartFrame = 0
        var silenceDbSum = 0.0
        var silenceWindowCount = 0

        while (frame < totalFrames) {
            val endFrame = minOf(totalFrames, frame + windowFrames)
            val windowDb = computeWindowDb(bytes, frame, endFrame, channels)
            val isSilence = windowDb <= thresholdDb

            if (isSilence) {
                if (!inSilence) {
                    inSilence = true
                    silenceStartFrame = frame
                    silenceDbSum = 0.0
                    silenceWindowCount = 0
                }
                silenceDbSum += windowDb
                silenceWindowCount += 1
            } else if (inSilence) {
                finalizeSilenceSegment(
                    startFrame = silenceStartFrame,
                    endFrame = frame,
                    sampleRate = sampleRate,
                    dbSum = silenceDbSum,
                    windowCount = silenceWindowCount,
                    minSilenceMs = minSilenceMs
                )?.let(rawSegments::add)
                inSilence = false
            }

            frame = endFrame
        }

        if (inSilence) {
            finalizeSilenceSegment(
                startFrame = silenceStartFrame,
                endFrame = totalFrames,
                sampleRate = sampleRate,
                dbSum = silenceDbSum,
                windowCount = silenceWindowCount,
                minSilenceMs = minSilenceMs
            )?.let(rawSegments::add)
        }

        val merged = mergeCloseSilenceSegments(
            rawSegments,
            maxGapMs = (windowMs * 2).coerceAtLeast(20)
        )

        return mapOf(
            "durationMs" to durationMs,
            "sampleRate" to sampleRate,
            "channels" to channels,
            "segments" to merged.map { seg ->
                mapOf(
                    "startMs" to seg.startMs,
                    "endMs" to seg.endMs,
                    "durationMs" to seg.durationMs,
                    "meanDb" to seg.meanDb
                )
            }
        )
    }

    private fun extractWaveformNative(
        path: String,
        buckets: Int
    ): Map<String, Any> {
        val normalizedPath = normalizePathForMediaExtractor(path)
        val pcm = OpenALBridge.decodeToPcm(normalizedPath)
            ?: throw IllegalStateException("No se pudo decodificar audio.")

        val sampleRate = pcm.sampleRate.coerceAtLeast(1)
        val channels = pcm.channels.coerceAtLeast(1)
        val bytes = pcm.bytes
        val totalFrames = bytes.size / (2 * channels)
        if (totalFrames <= 0) {
            return mapOf(
                "durationMs" to 0,
                "sampleRate" to sampleRate,
                "channels" to channels,
                "buckets" to emptyList<Double>()
            )
        }

        val durationMs = ((totalFrames * 1000L) / sampleRate).toInt()
        val bucketCount = buckets.coerceAtLeast(1)
        val framesPerBucket = maxOf(1, totalFrames / bucketCount)
        val raw = DoubleArray(bucketCount)

        for (bucket in 0 until bucketCount) {
            val startFrame = bucket * framesPerBucket
            val endFrame = if (bucket == bucketCount - 1) {
                totalFrames
            } else {
                minOf(totalFrames, startFrame + framesPerBucket)
            }
            if (endFrame <= startFrame) {
                raw[bucket] = 0.0
                continue
            }

            var peak = 0.0
            for (frame in startFrame until endFrame) {
                val base = frame * channels
                for (ch in 0 until channels) {
                    val sample = abs(readPcm16Sample(bytes, base + ch)) / 32768.0
                    if (sample > peak) peak = sample
                }
            }
            raw[bucket] = peak
        }

        var maxValue = 0.0
        for (v in raw) {
            if (v > maxValue) maxValue = v
        }

        val normalized = MutableList(bucketCount) { index ->
            val value = raw[index]
            val ratio = if (maxValue > 1e-9) value / maxValue else 0.0
            ratio.coerceIn(0.0, 1.0)
        }

        val smoothed = MutableList(bucketCount) { 0.0 }
        for (i in 0 until bucketCount) {
            val prev = if (i > 0) normalized[i - 1] else normalized[i]
            val curr = normalized[i]
            val next = if (i < bucketCount - 1) normalized[i + 1] else normalized[i]
            val avg = (prev + curr * 2.0 + next) / 4.0
            smoothed[i] = avg.coerceIn(0.02, 1.0)
        }

        return mapOf(
            "durationMs" to durationMs,
            "sampleRate" to sampleRate,
            "channels" to channels,
            "buckets" to smoothed
        )
    }

    private fun attachAudioVisualizer(sessionId: Int, barCount: Int, mode: String) {
        if (sessionId <= 0) throw IllegalArgumentException("sessionId invalido")
        val normalizedMode = if (mode == "fft") "fft" else "waveform"
        if (
            audioVisualizer != null &&
            audioVisualizerSessionId == sessionId &&
            audioVisualizerMode == normalizedMode
        ) {
            audioVisualizerBarCount = barCount
            return
        }

        detachAudioVisualizer()

        val visualizer = Visualizer(sessionId)
        val range = Visualizer.getCaptureSizeRange()
        var captureSize = highestPowerOfTwoAtMost(1024).coerceAtLeast(128)
        captureSize = captureSize.coerceIn(range[0], range[1])
        captureSize = highestPowerOfTwoAtMost(captureSize).coerceAtLeast(range[0])

        visualizer.captureSize = captureSize
        try {
            visualizer.scalingMode = Visualizer.SCALING_MODE_NORMALIZED
        } catch (_: Throwable) {
        }

        audioVisualizerBarCount = barCount.coerceIn(16, 128)
        audioVisualizerLastBars = DoubleArray(audioVisualizerBarCount) { 0.0 }
        audioVisualizerSessionId = sessionId
        audioVisualizerMode = normalizedMode
        val useWaveform = normalizedMode == "waveform"
        val useFft = normalizedMode == "fft"

        val captureRate = (Visualizer.getMaxCaptureRate() / 2).coerceAtLeast(8_000)
        visualizer.setDataCaptureListener(
            object : Visualizer.OnDataCaptureListener {
                override fun onWaveFormDataCapture(
                    visualizer: Visualizer?,
                    waveform: ByteArray?,
                    samplingRate: Int
                ) {
                    if (!useWaveform || waveform == null || waveform.isEmpty()) return
                    val bars = buildRealtimeBarsFromWaveform(
                        waveform = waveform,
                        barCount = audioVisualizerBarCount
                    )
                    emitAudioVisualizerBars(bars)
                }

                override fun onFftDataCapture(
                    visualizer: Visualizer?,
                    fft: ByteArray?,
                    samplingRate: Int
                ) {
                    if (!useFft || fft == null || fft.isEmpty()) return
                    val bars = buildRealtimeBarsFromFft(
                        fft = fft,
                        barCount = audioVisualizerBarCount,
                        samplingRateMilliHz = samplingRate
                    )
                    emitAudioVisualizerBars(bars)
                }
            },
            captureRate,
            useWaveform,
            useFft
        )

        visualizer.enabled = true
        audioVisualizer = visualizer
    }

    private fun detachAudioVisualizer() {
        try {
            audioVisualizer?.setDataCaptureListener(null, 0, false, false)
        } catch (_: Throwable) {
        }
        try {
            audioVisualizer?.enabled = false
        } catch (_: Throwable) {
        }
        try {
            audioVisualizer?.release()
        } catch (_: Throwable) {
        }
        audioVisualizer = null
        audioVisualizerSessionId = null
        audioVisualizerMode = "waveform"
        audioVisualizerLastBars = DoubleArray(0)
        audioVisualizerLastEmitAtMs = 0L
    }

    private fun highestPowerOfTwoAtMost(value: Int): Int {
        if (value <= 1) return 1
        var out = 1
        while (out * 2 <= value) out *= 2
        return out
    }

    private fun buildRealtimeBarsFromWaveform(waveform: ByteArray, barCount: Int): List<Double> {
        if (barCount <= 0 || waveform.isEmpty()) return emptyList()

        val count = barCount.coerceIn(16, 128)
        val samplesPerBar = maxOf(1, waveform.size / count)
        val raw = DoubleArray(count) { 0.0 }

        for (i in 0 until count) {
            val start = i * samplesPerBar
            val end = if (i == count - 1) waveform.size else minOf(waveform.size, start + samplesPerBar)
            var peak = 0.0
            for (j in start until end) {
                val centered = (waveform[j].toInt() and 0xFF) - 128
                val amplitude = abs(centered) / 128.0
                if (amplitude > peak) peak = amplitude
            }
            raw[i] = peak.coerceIn(0.0, 1.0)
        }

        if (audioVisualizerLastBars.size != count) {
            audioVisualizerLastBars = DoubleArray(count) { 0.0 }
        }

        val out = MutableList(count) { 0.0 }
        for (i in 0 until count) {
            val prev = audioVisualizerLastBars[i]
            val target = raw[i]
            val attack = 0.58
            val release = 0.34
            val alpha = if (target >= prev) attack else release
            val smoothed = (prev + (target - prev) * alpha).coerceIn(0.0, 1.0)
            audioVisualizerLastBars[i] = smoothed
            out[i] = smoothed.coerceIn(0.0, 1.0)
        }

        return out
    }

    private fun buildRealtimeBarsFromFft(
        fft: ByteArray,
        barCount: Int,
        samplingRateMilliHz: Int
    ): List<Double> {
        if (barCount <= 0 || fft.isEmpty()) return emptyList()

        val count = barCount.coerceIn(16, 128)
        val n = fft.size
        if (n < 4) return emptyList()

        val sampleRateHz = if (samplingRateMilliHz > 300_000) {
            (samplingRateMilliHz / 1000.0).coerceAtLeast(8_000.0)
        } else {
            samplingRateMilliHz.toDouble().coerceAtLeast(8_000.0)
        }
        val nyquist = (sampleRateHz / 2.0).coerceAtLeast(2_000.0)
        val fMin = 35.0
        val fMax = minOf(16_000.0, nyquist)
        if (fMax <= fMin) return emptyList()

        // Basado en el layout oficial de Visualizer.getFft(): [Rf0, Rf(n/2), Rf1, If1, ...]
        val magnitudes = DoubleArray(n / 2 + 1) { 0.0 }
        magnitudes[0] = abs(fft[0].toInt()).toDouble()
        magnitudes[n / 2] = abs(fft[1].toInt()).toDouble()
        for (k in 1 until (n / 2)) {
            val i = k * 2
            val real = fft[i].toDouble()
            val imag = fft[i + 1].toDouble()
            magnitudes[k] = sqrt(real * real + imag * imag)
        }

        val raw = DoubleArray(count) { 0.0 }
        for (band in 0 until count) {
            val t0 = band.toDouble() / count.toDouble()
            val t1 = (band + 1).toDouble() / count.toDouble()
            val startHz = fMin * (fMax / fMin).pow(t0)
            val endHz = fMin * (fMax / fMin).pow(t1)

            val startBin = floor((startHz * n) / sampleRateHz).toInt().coerceIn(1, n / 2)
            val endBin = ceil((endHz * n) / sampleRateHz).toInt().coerceIn(startBin, n / 2)

            var peak = 0.0
            var sumSq = 0.0
            var points = 0
            for (k in startBin..endBin) {
                val mag = magnitudes[k].coerceAtLeast(1e-6)
                val db = 20.0 * log10(mag)
                val normalized = ((db + 74.0) / 64.0).coerceIn(0.0, 1.0)
                if (normalized > peak) peak = normalized
                sumSq += normalized * normalized
                points += 1
            }

            val energy = if (points > 0) sqrt(sumSq / points.toDouble()) else 0.0
            val mixed = (peak * 0.60 + energy * 0.40).coerceIn(0.0, 1.0)
            raw[band] = sqrt(mixed).coerceIn(0.0, 1.0)
        }

        if (audioVisualizerLastBars.size != count) {
            audioVisualizerLastBars = DoubleArray(count) { 0.0 }
        }

        val envelope = DoubleArray(count) { 0.0 }
        for (i in 0 until count) {
            val prev = audioVisualizerLastBars[i]
            val target = raw[i]
            val attack = 0.62
            val release = 0.26
            val alpha = if (target >= prev) attack else release
            envelope[i] = (prev + (target - prev) * alpha).coerceIn(0.0, 1.0)
        }

        val out = MutableList(count) { 0.0 }
        for (i in 0 until count) {
            val prev = if (i > 0) envelope[i - 1] else envelope[i]
            val curr = envelope[i]
            val next = if (i < count - 1) envelope[i + 1] else envelope[i]
            val spatial = (prev * 0.18 + curr * 0.64 + next * 0.18).coerceIn(0.0, 1.0)
            val gated = if (spatial < 0.02) 0.0 else spatial
            val finalValue = gated.coerceIn(0.0, 1.0)
            out[i] = finalValue
            audioVisualizerLastBars[i] = finalValue
        }

        return out
    }

    private fun emitAudioVisualizerBars(bars: List<Double>) {
        if (bars.isEmpty()) return
        val now = SystemClock.uptimeMillis()
        if (now - audioVisualizerLastEmitAtMs < 20L) return
        audioVisualizerLastEmitAtMs = now

        val payload = mapOf(
            "bars" to bars,
            "sessionId" to (audioVisualizerSessionId ?: 0)
        )
        uiHandler.post {
            audioVisualizerSink?.success(payload)
        }
    }

    private fun renderCleanedAudioNative(
        path: String,
        removeRangesMs: List<Pair<Int, Int>>,
        fadeMs: Int
    ): Map<String, Any> {
        val normalizedPath = normalizePathForMediaExtractor(path)
        val pcm = OpenALBridge.decodeToPcm(normalizedPath)
            ?: throw IllegalStateException("No se pudo decodificar audio.")

        val sampleRate = pcm.sampleRate.coerceAtLeast(1)
        val channels = pcm.channels.coerceAtLeast(1)
        val sourceBytes = pcm.bytes
        val totalFrames = sourceBytes.size / (2 * channels)
        if (totalFrames <= 0) {
            throw IllegalStateException("Audio vacio.")
        }

        val originalDurationMs = ((totalFrames * 1000L) / sampleRate).toInt()
        val removeRanges = normalizeRemovalRanges(
            rangesMs = removeRangesMs,
            totalFrames = totalFrames,
            sampleRate = sampleRate
        )
        if (removeRanges.isEmpty()) {
            throw IllegalStateException("No hay rangos validos para recortar.")
        }

        val keepRanges = buildKeepRanges(removeRanges, totalFrames)
        if (keepRanges.isEmpty()) {
            throw IllegalStateException("No se puede eliminar todo el audio.")
        }

        val cleanedOutput = ByteArrayOutputStream()
        val joinFrames = mutableListOf<Int>()
        var writtenFrames = 0

        for ((idx, range) in keepRanges.withIndex()) {
            val startByte = range.startFrame * channels * 2
            val endByte = range.endFrame * channels * 2
            if (endByte <= startByte) continue
            if (idx > 0) joinFrames.add(writtenFrames)
            cleanedOutput.write(sourceBytes, startByte, endByte - startByte)
            writtenFrames += (range.endFrame - range.startFrame)
        }

        val cleanedPcm = cleanedOutput.toByteArray()
        val fadeFrames = ((fadeMs.toLong() * sampleRate) / 1000L).toInt().coerceAtLeast(0)
        if (cleanedPcm.isNotEmpty() && fadeFrames > 0 && joinFrames.isNotEmpty()) {
            applyJoinFadesPcm16(
                pcm = cleanedPcm,
                joinFrames = joinFrames,
                channels = channels,
                fadeFrames = fadeFrames
            )
        }

        val cleanedDurationMs = ((writtenFrames * 1000L) / sampleRate).toInt()
        val removedDurationMs = (originalDurationMs - cleanedDurationMs).coerceAtLeast(0)
        val outputPath = writePcm16Wav(
            sourcePath = normalizedPath,
            pcm = cleanedPcm,
            sampleRate = sampleRate,
            channels = channels
        )

        return mapOf(
            "outputPath" to outputPath,
            "originalDurationMs" to originalDurationMs,
            "cleanedDurationMs" to cleanedDurationMs,
            "removedDurationMs" to removedDurationMs,
            "sampleRate" to sampleRate,
            "channels" to channels,
            "removedSegmentsCount" to removeRanges.size
        )
    }

    private fun finalizeSilenceSegment(
        startFrame: Int,
        endFrame: Int,
        sampleRate: Int,
        dbSum: Double,
        windowCount: Int,
        minSilenceMs: Int
    ): SilenceSegment? {
        if (endFrame <= startFrame) return null
        val startMs = ((startFrame * 1000L) / sampleRate).toInt()
        val endMs = ((endFrame * 1000L) / sampleRate).toInt()
        val durationMs = (endMs - startMs).coerceAtLeast(0)
        if (durationMs < minSilenceMs) return null

        val meanDbRaw = if (windowCount > 0) dbSum / windowCount.toDouble() else -120.0
        val meanDb = ((meanDbRaw * 100.0).roundToInt()) / 100.0
        return SilenceSegment(
            startMs = startMs,
            endMs = endMs,
            durationMs = durationMs,
            meanDb = meanDb
        )
    }

    private fun mergeCloseSilenceSegments(
        segments: List<SilenceSegment>,
        maxGapMs: Int
    ): List<SilenceSegment> {
        if (segments.isEmpty()) return emptyList()

        val sorted = segments.sortedBy { it.startMs }
        val merged = mutableListOf<SilenceSegment>()
        var current = sorted.first()

        for (i in 1 until sorted.size) {
            val next = sorted[i]
            if (next.startMs - current.endMs <= maxGapMs) {
                val mergedEnd = maxOf(current.endMs, next.endMs)
                val mergedDuration = (mergedEnd - current.startMs).coerceAtLeast(0)
                val dbWeight = (current.durationMs + next.durationMs).coerceAtLeast(1)
                val weightedDb =
                    (current.meanDb * current.durationMs + next.meanDb * next.durationMs) /
                        dbWeight.toDouble()
                current = SilenceSegment(
                    startMs = current.startMs,
                    endMs = mergedEnd,
                    durationMs = mergedDuration,
                    meanDb = ((weightedDb * 100.0).roundToInt()) / 100.0
                )
            } else {
                merged.add(current)
                current = next
            }
        }

        merged.add(current)
        return merged
    }

    private fun normalizeRemovalRanges(
        rangesMs: List<Pair<Int, Int>>,
        totalFrames: Int,
        sampleRate: Int
    ): List<FrameRange> {
        if (rangesMs.isEmpty() || totalFrames <= 0) return emptyList()

        val frameRanges = mutableListOf<FrameRange>()
        for ((startMs, endMs) in rangesMs) {
            val startFrame =
                ((startMs.toLong() * sampleRate) / 1000L).toInt().coerceIn(0, totalFrames)
            val endFrame =
                ((endMs.toLong() * sampleRate) / 1000L).toInt().coerceIn(0, totalFrames)
            if (endFrame > startFrame) {
                frameRanges.add(FrameRange(startFrame, endFrame))
            }
        }

        if (frameRanges.isEmpty()) return emptyList()

        val sorted = frameRanges.sortedBy { it.startFrame }
        val merged = mutableListOf<FrameRange>()
        var current = sorted.first()

        for (i in 1 until sorted.size) {
            val next = sorted[i]
            if (next.startFrame <= current.endFrame) {
                current = FrameRange(
                    startFrame = current.startFrame,
                    endFrame = maxOf(current.endFrame, next.endFrame)
                )
            } else {
                merged.add(current)
                current = next
            }
        }
        merged.add(current)

        return merged
    }

    private fun buildKeepRanges(removeRanges: List<FrameRange>, totalFrames: Int): List<FrameRange> {
        if (totalFrames <= 0) return emptyList()
        if (removeRanges.isEmpty()) return listOf(FrameRange(0, totalFrames))

        val keep = mutableListOf<FrameRange>()
        var cursor = 0

        for (remove in removeRanges) {
            if (remove.startFrame > cursor) {
                keep.add(FrameRange(cursor, remove.startFrame))
            }
            cursor = maxOf(cursor, remove.endFrame)
        }

        if (cursor < totalFrames) {
            keep.add(FrameRange(cursor, totalFrames))
        }

        return keep.filter { it.endFrame > it.startFrame }
    }

    private fun computeWindowDb(
        bytes: ByteArray,
        startFrame: Int,
        endFrame: Int,
        channels: Int
    ): Double {
        var sumSquares = 0.0
        var count = 0

        for (frame in startFrame until endFrame) {
            val base = frame * channels
            for (ch in 0 until channels) {
                val sample = readPcm16Sample(bytes, base + ch).toDouble() / 32768.0
                sumSquares += sample * sample
                count += 1
            }
        }

        if (count <= 0) return -120.0
        val rms = sqrt(sumSquares / count.toDouble())
        if (rms <= 1e-9) return -120.0
        return (20.0 * log10(rms)).coerceAtLeast(-120.0)
    }

    private fun readPcm16Sample(bytes: ByteArray, sampleIndex: Int): Int {
        val offset = sampleIndex * 2
        if (offset < 0 || offset + 1 >= bytes.size) return 0
        val low = bytes[offset].toInt() and 0xFF
        val high = bytes[offset + 1].toInt()
        return (high shl 8) or low
    }

    private fun writePcm16Sample(bytes: ByteArray, sampleIndex: Int, value: Int) {
        val offset = sampleIndex * 2
        if (offset < 0 || offset + 1 >= bytes.size) return
        val clamped = value.coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt())
        bytes[offset] = (clamped and 0xFF).toByte()
        bytes[offset + 1] = ((clamped shr 8) and 0xFF).toByte()
    }

    private fun applyJoinFadesPcm16(
        pcm: ByteArray,
        joinFrames: List<Int>,
        channels: Int,
        fadeFrames: Int
    ) {
        if (fadeFrames <= 0 || joinFrames.isEmpty()) return
        val totalFrames = pcm.size / (2 * channels)
        if (totalFrames <= 1) return

        for (join in joinFrames) {
            if (join <= 0 || join >= totalFrames) continue

            val leftFrames = minOf(fadeFrames, join)
            for (i in 0 until leftFrames) {
                val frame = join - leftFrames + i
                val t = (i + 1).toDouble() / (leftFrames + 1).toDouble()
                val gain = (1.0 - t).coerceIn(0.0, 1.0)
                for (ch in 0 until channels) {
                    val sampleIndex = frame * channels + ch
                    val sample = readPcm16Sample(pcm, sampleIndex)
                    writePcm16Sample(
                        pcm,
                        sampleIndex,
                        (sample.toDouble() * gain).roundToInt()
                    )
                }
            }

            val rightFrames = minOf(fadeFrames, totalFrames - join)
            for (i in 0 until rightFrames) {
                val frame = join + i
                val t = (i + 1).toDouble() / (rightFrames + 1).toDouble()
                val gain = t.coerceIn(0.0, 1.0)
                for (ch in 0 until channels) {
                    val sampleIndex = frame * channels + ch
                    val sample = readPcm16Sample(pcm, sampleIndex)
                    writePcm16Sample(
                        pcm,
                        sampleIndex,
                        (sample.toDouble() * gain).roundToInt()
                    )
                }
            }
        }
    }

    private fun writePcm16Wav(
        sourcePath: String,
        pcm: ByteArray,
        sampleRate: Int,
        channels: Int
    ): String {
        val sourceFile = File(sourcePath)
        val safeBaseName = sanitizeFileName(
            sourceFile.nameWithoutExtension.ifBlank { "audio" }
        )
        val mediaDir = File(filesDir, "media")
        if (!mediaDir.exists() && !mediaDir.mkdirs()) {
            throw IllegalStateException("No se pudo crear carpeta de salida.")
        }

        val outputFile = File(
            mediaDir,
            "${safeBaseName}_clean_${System.currentTimeMillis()}.wav"
        )

        val bitsPerSample = 16
        val byteRate = sampleRate * channels * bitsPerSample / 8
        val blockAlign = channels * bitsPerSample / 8
        val dataSize = pcm.size
        val riffChunkSize = 36 + dataSize

        val header = ByteBuffer.allocate(44)
            .order(ByteOrder.LITTLE_ENDIAN)
            .apply {
                put("RIFF".toByteArray(Charsets.US_ASCII))
                putInt(riffChunkSize)
                put("WAVE".toByteArray(Charsets.US_ASCII))
                put("fmt ".toByteArray(Charsets.US_ASCII))
                putInt(16)
                putShort(1.toShort())
                putShort(channels.toShort())
                putInt(sampleRate)
                putInt(byteRate)
                putShort(blockAlign.toShort())
                putShort(bitsPerSample.toShort())
                put("data".toByteArray(Charsets.US_ASCII))
                putInt(dataSize)
            }

        FileOutputStream(outputFile).use { fos ->
            fos.write(header.array())
            fos.write(pcm)
            fos.flush()
        }

        return outputFile.absolutePath
    }

    private fun releaseSpatial() {
        try {
            virtualizer?.enabled = false
        } catch (_: Throwable) {
        }
        try {
            bassBoost?.enabled = false
        } catch (_: Throwable) {
        }
        try {
            reverb?.enabled = false
        } catch (_: Throwable) {
        }
        try {
            envReverb?.enabled = false
        } catch (_: Throwable) {
        }
        try {
            loudness?.enabled = false
        } catch (_: Throwable) {
        }
        try {
            virtualizer?.release()
        } catch (_: Throwable) {
        }
        try {
            bassBoost?.release()
        } catch (_: Throwable) {
        }
        try {
            reverb?.release()
        } catch (_: Throwable) {
        }
        try {
            envReverb?.release()
        } catch (_: Throwable) {
        }
        try {
            loudness?.release()
        } catch (_: Throwable) {
        }
        virtualizer = null
        bassBoost = null
        reverb = null
        envReverb = null
        loudness = null
        spatialSessionId = null
    }
}
