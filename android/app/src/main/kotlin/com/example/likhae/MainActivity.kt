package com.example.likhae

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.sin

class MainActivity : FlutterFragmentActivity() {
    private var notificationTrack: AudioTrack? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "likhae/notification_sounds",
        ).setMethodCallHandler { call, result ->
            if (call.method != "play") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            try {
                val rawTones = call.argument<List<*>>("tones").orEmpty()
                val tones = rawTones.mapNotNull { rawTone ->
                    (rawTone as? List<*>)
                        ?.mapNotNull { (it as? Number)?.toInt() }
                        ?.takeIf { it.size >= 3 }
                        ?.let { Triple(it[0], it[1], it[2]) }
                }
                playNotificationTones(tones)
                result.success(null)
            } catch (error: Exception) {
                result.error("SOUND_PLAYBACK_FAILED", error.message, null)
            }
        }
    }

    private fun playNotificationTones(tones: List<Triple<Int, Int, Int>>) {
        if (tones.isEmpty()) return

        notificationTrack?.let { previous ->
            try {
                previous.pause()
                previous.flush()
                previous.release()
            } catch (_: IllegalStateException) {
                // The track may already have completed.
            }
        }

        val sampleRate = 44100
        val durationMs = tones.maxOf { it.second + it.third + 30 }
        val sampleCount = sampleRate * durationMs / 1000
        val samples = ShortArray(sampleCount)
        val attackSeconds = 0.015
        val amplitude = 0.14

        for ((frequency, delayMs, toneDurationMs) in tones) {
            val startSample = sampleRate * delayMs / 1000
            val toneSamples = sampleRate * toneDurationMs / 1000
            for (offset in 0 until toneSamples) {
                val elapsed = offset.toDouble() / sampleRate
                val progress = offset.toDouble() / toneSamples
                val attack = (elapsed / attackSeconds).coerceAtMost(1.0)
                val envelope = attack * exp(-4.0 * progress)
                val value = sin(2.0 * PI * frequency * elapsed) * amplitude * envelope
                val index = startSample + offset
                val mixed = samples[index].toInt() + (value * Short.MAX_VALUE).toInt()
                samples[index] = mixed.coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
            }
        }

        val format = AudioFormat.Builder()
            .setSampleRate(sampleRate)
            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
            .build()
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val track = AudioTrack(
            attributes,
            format,
            samples.size * 2,
            AudioTrack.MODE_STATIC,
            AudioTrack.AUDIO_SESSION_ID_GENERATE,
        )
        notificationTrack = track
        track.setVolume(0.7f)
        track.write(samples, 0, samples.size)
        track.play()
        Handler(Looper.getMainLooper()).postDelayed({
            if (notificationTrack === track) {
                notificationTrack = null
                try {
                    track.stop()
                    track.release()
                } catch (_: IllegalStateException) {
                    // The sound may have stopped during an Activity change.
                }
            }
        }, durationMs.toLong() + 80L)
    }
}
