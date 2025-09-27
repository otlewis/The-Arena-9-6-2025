package com.thearenadtd.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.media.AudioManager

class MainActivity : FlutterActivity() {
    private val AUDIO_CHANNEL = "com.thearenadtd.app/audio"
    private val AUDIO_FOCUS_CHANNEL = "arena/audio_focus"
    private lateinit var audioFocusHandler: AudioFocusHandler

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Setup existing audio channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSpeakerphoneOn" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    setSpeakerphoneOn(enabled)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Setup audio focus channel
        val audioFocusChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_FOCUS_CHANNEL)
        audioFocusHandler = AudioFocusHandler(this, audioFocusChannel)

        audioFocusChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestAudioFocus" -> {
                    val success = audioFocusHandler.requestAudioFocus()
                    result.success(success)
                }
                "abandonAudioFocus" -> {
                    val success = audioFocusHandler.abandonAudioFocus()
                    result.success(success)
                }
                "isAudioFocusGranted" -> {
                    result.success(audioFocusHandler.isAudioFocusGranted())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun setSpeakerphoneOn(enabled: Boolean) {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

            // Force speakerphone
            audioManager.isSpeakerphoneOn = enabled

            if (enabled) {
                // Set mode for communication
                audioManager.mode = AudioManager.MODE_IN_COMMUNICATION

                // Boost volume to 80% of max
                val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_VOICE_CALL)
                val targetVolume = (maxVolume * 0.8).toInt()
                audioManager.setStreamVolume(
                    AudioManager.STREAM_VOICE_CALL,
                    targetVolume,
                    AudioManager.FLAG_SHOW_UI
                )
            }
        } catch (e: Exception) {
            println("Error setting speakerphone: ${e.message}")
        }
    }
}