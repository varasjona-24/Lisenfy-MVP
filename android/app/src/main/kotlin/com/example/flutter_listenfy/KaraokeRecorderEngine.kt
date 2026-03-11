package com.example.flutter_listenfy

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

internal class KaraokeRecorderEngine(private val context: Context) {
    private data class ActiveSession(
        val baseName: String,
        val karaokeDir: File,
        val sourcePath: String,
        val instrumentalPath: String,
        val ownsInstrumentalFile: Boolean,
        val voicePath: String,
        val sampleRate: Int,
        val channels: Int,
        val startedAtMs: Long,
        val player: MediaPlayer,
        val recorder: MediaRecorder
    )

    private data class PcmFormat(
        val bytes: ByteArray,
        val sampleRate: Int,
        val channels: Int
    )

    private var activeSession: ActiveSession? = null

    @Synchronized
    fun isRecording(): Boolean = activeSession != null

    @Synchronized
    fun startSession(
        sourcePathRaw: String,
        instrumentalGainRaw: Double,
        instrumentalPathOverrideRaw: String? = null
    ): Map<String, Any> {
        if (activeSession != null) {
            throw IllegalStateException("Ya hay una grabación karaoke activa.")
        }

        val sourcePath = normalizePath(sourcePathRaw)
        if (sourcePath.isEmpty()) {
            throw IllegalArgumentException("sourcePath es obligatorio.")
        }
        val sourceFile = File(sourcePath)
        if (!sourceFile.exists()) {
            throw IllegalArgumentException("Archivo no encontrado: $sourcePath")
        }

        val karaokeDir = ensureKaraokeDir()
        val token = System.currentTimeMillis()
        val baseName = sanitizeFileName(sourceFile.nameWithoutExtension.ifBlank { "track" })

        var instrumentalFile: File
        var sampleRate: Int
        var channels: Int
        var ownsInstrumentalFile = false

        val overridePath = normalizePath(instrumentalPathOverrideRaw ?: "")
        if (overridePath.isNotEmpty()) {
            val overrideFile = File(overridePath)
            if (!overrideFile.exists()) {
                throw IllegalArgumentException(
                    "Pista instrumental IA no encontrada: $overridePath"
                )
            }
            val overridePcm = OpenALBridge.decodeToPcm(overridePath)
                ?: throw IllegalStateException("No se pudo decodificar instrumental IA.")
            sampleRate = overridePcm.sampleRate.coerceAtLeast(8_000)
            channels = overridePcm.channels.coerceAtLeast(1)
            instrumentalFile = overrideFile
            ownsInstrumentalFile = false
        } else {
            val sourcePcm = OpenALBridge.decodeToPcm(sourcePath)
                ?: throw IllegalStateException("No se pudo decodificar el audio local.")
            sampleRate = sourcePcm.sampleRate.coerceAtLeast(8_000)
            channels = sourcePcm.channels.coerceAtLeast(1)
            val instrumentalGain = instrumentalGainRaw.coerceIn(0.10, 1.80)
            instrumentalFile = File(karaokeDir, "${baseName}_inst_$token.wav")
            val instrumentalPcm = buildInstrumentalPcm16(
                pcm = sourcePcm.bytes,
                channels = channels,
                gain = instrumentalGain
            )
            writePcm16Wav(
                outputFile = instrumentalFile,
                pcm = instrumentalPcm,
                sampleRate = sampleRate,
                channels = channels
            )
            ownsInstrumentalFile = true
        }

        val voiceFile = File(karaokeDir, "${baseName}_voice_$token.m4a")

        val player = buildMediaPlayer(instrumentalFile)
        val recorder = buildMediaRecorder(voiceFile, sampleRate)

        try {
            recorder.start()
            player.start()
        } catch (e: Throwable) {
            try {
                player.release()
            } catch (_: Throwable) {
            }
            try {
                recorder.reset()
                recorder.release()
            } catch (_: Throwable) {
            }
            if (voiceFile.exists()) {
                voiceFile.delete()
            }
            if (ownsInstrumentalFile && instrumentalFile.exists()) {
                instrumentalFile.delete()
            }
            throw IllegalStateException(
                e.message ?: "No se pudo iniciar la sesión de karaoke."
            )
        }

        val startedAt = System.currentTimeMillis()
        activeSession = ActiveSession(
            baseName = baseName,
            karaokeDir = karaokeDir,
            sourcePath = sourcePath,
            instrumentalPath = instrumentalFile.absolutePath,
            ownsInstrumentalFile = ownsInstrumentalFile,
            voicePath = voiceFile.absolutePath,
            sampleRate = sampleRate,
            channels = channels,
            startedAtMs = startedAt,
            player = player,
            recorder = recorder
        )

        val instrumentalPcm = OpenALBridge.decodeToPcm(instrumentalFile.absolutePath)
        val instrumentalDurationMs = if (instrumentalPcm != null) {
            val frames = instrumentalPcm.bytes.size / (2 * channels)
            ((frames * 1000.0) / sampleRate.toDouble()).roundToInt().coerceAtLeast(0)
        } else {
            0
        }

        val estimatedDurationMs =
            instrumentalDurationMs

        return mapOf(
            "sourcePath" to sourcePath,
            "instrumentalPath" to instrumentalFile.absolutePath,
            "voicePath" to voiceFile.absolutePath,
            "sampleRate" to sampleRate,
            "channels" to channels,
            "estimatedDurationMs" to estimatedDurationMs,
            "startedAtMs" to startedAt
        )
    }

    @Synchronized
    fun stopSession(
        exportMixed: Boolean,
        voiceGainRaw: Double,
        instrumentalGainRaw: Double
    ): Map<String, Any?> {
        val session = activeSession ?: throw IllegalStateException("No hay grabación activa.")
        activeSession = null

        releasePlayer(session.player)
        val voiceOk = stopRecorderSafely(session.recorder, File(session.voicePath))
        val stoppedAtMs = System.currentTimeMillis()
        val recordedMs = (stoppedAtMs - session.startedAtMs).coerceAtLeast(0L).toInt()

        var mixedPath: String? = null
        var mixedDurationMs = 0
        var mixedSampleRate = session.sampleRate
        var mixedChannels = session.channels

        if (exportMixed && voiceOk && File(session.voicePath).exists()) {
            val voiceGain = voiceGainRaw.coerceIn(0.0, 2.0)
            val instrumentalGain = instrumentalGainRaw.coerceIn(0.0, 2.0)
            val mixFile = File(
                session.karaokeDir,
                "${session.baseName}_karaoke_${System.currentTimeMillis()}.wav"
            )
            val mixMeta = mixVoiceWithInstrumental(
                instrumentalPath = session.instrumentalPath,
                voicePath = session.voicePath,
                outputPath = mixFile.absolutePath,
                voiceGain = voiceGain,
                instrumentalGain = instrumentalGain
            )
            mixedPath = mixFile.absolutePath
            mixedDurationMs = mixMeta.durationMs
            mixedSampleRate = mixMeta.sampleRate
            mixedChannels = mixMeta.channels
        }

        return mapOf(
            "sourcePath" to session.sourcePath,
            "instrumentalPath" to session.instrumentalPath,
            "voicePath" to session.voicePath,
            "mixedPath" to mixedPath,
            "recordedMs" to recordedMs,
            "durationMs" to mixedDurationMs,
            "sampleRate" to mixedSampleRate,
            "channels" to mixedChannels
        )
    }

    @Synchronized
    fun cancelSession(): Boolean {
        val session = activeSession ?: return false
        activeSession = null

        releasePlayer(session.player)
        stopRecorderSafely(session.recorder, File(session.voicePath))

        try {
            File(session.voicePath).delete()
        } catch (_: Throwable) {
        }
        if (session.ownsInstrumentalFile) {
            try {
                File(session.instrumentalPath).delete()
            } catch (_: Throwable) {
            }
        }
        return true
    }

    @Synchronized
    fun release() {
        cancelSession()
    }

    private fun normalizePath(raw: String): String = raw.removePrefix("file://").trim()

    private fun ensureKaraokeDir(): File {
        val dir = File(context.filesDir, "media/karaoke")
        if (!dir.exists() && !dir.mkdirs()) {
            throw IllegalStateException("No se pudo crear carpeta de karaoke.")
        }
        return dir
    }

    private fun sanitizeFileName(value: String): String {
        val sanitized = value.replace(Regex("[^A-Za-z0-9 _-]"), "")
            .trim()
            .replace(Regex("\\s+"), "_")
        return if (sanitized.isBlank()) "track" else sanitized
    }

    private fun buildMediaPlayer(instrumentalFile: File): MediaPlayer {
        val player = MediaPlayer()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
        } else {
            @Suppress("DEPRECATION")
            player.setAudioStreamType(android.media.AudioManager.STREAM_MUSIC)
        }
        player.setDataSource(instrumentalFile.absolutePath)
        player.isLooping = false
        player.prepare()
        return player
    }

    private fun buildMediaRecorder(voiceFile: File, sampleRate: Int): MediaRecorder {
        val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
        recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        recorder.setAudioEncodingBitRate(128_000)
        recorder.setAudioSamplingRate(sampleRate.coerceIn(16_000, 48_000))
        recorder.setAudioChannels(1)
        recorder.setOutputFile(voiceFile.absolutePath)
        recorder.prepare()
        return recorder
    }

    private fun releasePlayer(player: MediaPlayer) {
        try {
            if (player.isPlaying) {
                player.stop()
            }
        } catch (_: Throwable) {
        }
        try {
            player.release()
        } catch (_: Throwable) {
        }
    }

    private fun stopRecorderSafely(recorder: MediaRecorder, voiceFile: File): Boolean {
        var ok = true
        try {
            recorder.stop()
        } catch (_: RuntimeException) {
            ok = false
            try {
                voiceFile.delete()
            } catch (_: Throwable) {
            }
        } catch (_: Throwable) {
            ok = false
        }
        try {
            recorder.reset()
        } catch (_: Throwable) {
        }
        try {
            recorder.release()
        } catch (_: Throwable) {
        }
        return ok && voiceFile.exists()
    }

    private fun buildInstrumentalPcm16(
        pcm: ByteArray,
        channels: Int,
        gain: Double
    ): ByteArray {
        if (pcm.isEmpty()) return ByteArray(0)
        val safeChannels = channels.coerceAtLeast(1)
        val totalFrames = pcm.size / (2 * safeChannels)
        if (totalFrames <= 0) return ByteArray(0)

        val output = ByteArray(pcm.size)

        if (safeChannels < 2) {
            for (i in 0 until totalFrames) {
                val sample = readPcm16Sample(pcm, i)
                val boosted = (sample * gain).roundToInt()
                writePcm16Sample(output, i, boosted)
            }
            return output
        }

        for (frame in 0 until totalFrames) {
            val left = readPcm16Sample(pcm, frame * safeChannels)
            val right = readPcm16Sample(pcm, frame * safeChannels + 1)
            val reducedLeft = ((left - right) * 0.5 * gain).roundToInt()
            val reducedRight = ((right - left) * 0.5 * gain).roundToInt()

            writePcm16Sample(output, frame * safeChannels, reducedLeft)
            writePcm16Sample(output, frame * safeChannels + 1, reducedRight)
            for (ch in 2 until safeChannels) {
                val ambient = ((reducedLeft + reducedRight) * 0.25).roundToInt()
                writePcm16Sample(output, frame * safeChannels + ch, ambient)
            }
        }

        return output
    }

    private data class MixMeta(
        val durationMs: Int,
        val sampleRate: Int,
        val channels: Int
    )

    private fun mixVoiceWithInstrumental(
        instrumentalPath: String,
        voicePath: String,
        outputPath: String,
        voiceGain: Double,
        instrumentalGain: Double
    ): MixMeta {
        val inst = decodeAsFormat(instrumentalPath)
        val voice = decodeAsFormat(voicePath)

        val outputRate = inst.sampleRate.coerceAtLeast(8_000)
        val outputChannels = inst.channels.coerceAtLeast(1)
        val convertedVoice = convertPcm16Format(
            input = voice.bytes,
            inputRate = voice.sampleRate,
            inputChannels = voice.channels,
            outputRate = outputRate,
            outputChannels = outputChannels
        )

        val instFrames = inst.bytes.size / (2 * outputChannels)
        val voiceFrames = convertedVoice.size / (2 * outputChannels)
        val totalFrames = max(instFrames, voiceFrames)
        val mixed = ByteArray(totalFrames * outputChannels * 2)

        for (frame in 0 until totalFrames) {
            for (ch in 0 until outputChannels) {
                val sampleIndex = frame * outputChannels + ch
                val instSample = if (frame < instFrames) {
                    readPcm16Sample(inst.bytes, sampleIndex)
                } else {
                    0
                }
                val voiceSample = if (frame < voiceFrames) {
                    readPcm16Sample(convertedVoice, sampleIndex)
                } else {
                    0
                }
                val mixedSample =
                    (instSample * instrumentalGain + voiceSample * voiceGain).roundToInt()
                writePcm16Sample(mixed, sampleIndex, mixedSample)
            }
        }

        val outputFile = File(outputPath)
        writePcm16Wav(outputFile, mixed, outputRate, outputChannels)
        val durationMs =
            ((totalFrames * 1000.0) / outputRate.toDouble()).roundToInt().coerceAtLeast(0)
        return MixMeta(
            durationMs = durationMs,
            sampleRate = outputRate,
            channels = outputChannels
        )
    }

    private fun decodeAsFormat(path: String): PcmFormat {
        val pcm = OpenALBridge.decodeToPcm(path)
            ?: throw IllegalStateException("No se pudo decodificar: $path")
        return PcmFormat(
            bytes = pcm.bytes,
            sampleRate = pcm.sampleRate.coerceAtLeast(8_000),
            channels = pcm.channels.coerceAtLeast(1)
        )
    }

    private fun convertPcm16Format(
        input: ByteArray,
        inputRate: Int,
        inputChannels: Int,
        outputRate: Int,
        outputChannels: Int
    ): ByteArray {
        if (input.isEmpty()) return ByteArray(0)

        val inChannels = inputChannels.coerceAtLeast(1)
        val outChannels = outputChannels.coerceAtLeast(1)
        val inRate = inputRate.coerceAtLeast(8_000)
        val outRate = outputRate.coerceAtLeast(8_000)

        if (inRate == outRate && inChannels == outChannels) {
            return input.copyOf()
        }

        val inFrames = input.size / (2 * inChannels)
        if (inFrames <= 0) return ByteArray(0)

        val outFrames = if (inRate == outRate) {
            inFrames
        } else {
            max(1, ((inFrames.toDouble() * outRate.toDouble()) / inRate.toDouble()).roundToInt())
        }

        val out = ByteArray(outFrames * outChannels * 2)
        for (frame in 0 until outFrames) {
            val sourcePos = if (outFrames <= 1) {
                0.0
            } else {
                frame.toDouble() * (inFrames - 1).toDouble() / (outFrames - 1).toDouble()
            }
            val i0 = sourcePos.toInt().coerceIn(0, inFrames - 1)
            val i1 = min(i0 + 1, inFrames - 1)
            val t = sourcePos - i0.toDouble()

            for (outCh in 0 until outChannels) {
                val s0 = sampleForOutputChannel(input, i0, inChannels, outChannels, outCh)
                val s1 = sampleForOutputChannel(input, i1, inChannels, outChannels, outCh)
                val interpolated = (s0 + (s1 - s0) * t).roundToInt()
                writePcm16Sample(out, frame * outChannels + outCh, interpolated)
            }
        }

        return out
    }

    private fun sampleForOutputChannel(
        input: ByteArray,
        frame: Int,
        inChannels: Int,
        outChannels: Int,
        outChannel: Int
    ): Int {
        val base = frame * inChannels
        if (outChannels == 1) {
            var sum = 0
            for (ch in 0 until inChannels) {
                sum += readPcm16Sample(input, base + ch)
            }
            return (sum.toDouble() / inChannels.toDouble()).roundToInt()
        }
        if (inChannels == 1) {
            return readPcm16Sample(input, base)
        }
        val mapped = outChannel.coerceIn(0, inChannels - 1)
        return readPcm16Sample(input, base + mapped)
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

    private fun writePcm16Wav(
        outputFile: File,
        pcm: ByteArray,
        sampleRate: Int,
        channels: Int
    ) {
        val safeRate = sampleRate.coerceAtLeast(8_000)
        val safeChannels = channels.coerceAtLeast(1)
        val bitsPerSample = 16
        val byteRate = safeRate * safeChannels * bitsPerSample / 8
        val blockAlign = safeChannels * bitsPerSample / 8
        val dataSize = pcm.size
        val riffSize = 36 + dataSize

        val header = ByteBuffer.allocate(44)
            .order(ByteOrder.LITTLE_ENDIAN)
            .apply {
                put("RIFF".toByteArray(Charsets.US_ASCII))
                putInt(riffSize)
                put("WAVE".toByteArray(Charsets.US_ASCII))
                put("fmt ".toByteArray(Charsets.US_ASCII))
                putInt(16)
                putShort(1.toShort())
                putShort(safeChannels.toShort())
                putInt(safeRate)
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
    }
}
