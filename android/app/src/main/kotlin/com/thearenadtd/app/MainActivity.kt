package com.thearenadtd.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.media.AudioManager
import android.telephony.TelephonyManager
import android.telephony.PhoneStateListener
import android.os.Build

class MainActivity : FlutterActivity() {
    private val AUDIO_CHANNEL = "com.thearenadtd.app/audio"
    private val AUDIO_FOCUS_CHANNEL = "arena/audio_focus"
    private val PHONE_CALL_CHANNEL = "com.thearenadtd.app/phone_call"
    private lateinit var audioFocusHandler: AudioFocusHandler
    private var phoneStateListener: PhoneStateListener? = null
    private var isOnPhoneCall = false

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

        // Setup phone call detection channel
        val phoneCallChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PHONE_CALL_CHANNEL)

        phoneCallChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startMonitoring" -> {
                    startPhoneCallMonitoring(phoneCallChannel)
                    result.success(isOnPhoneCall)
                }
                "stopMonitoring" -> {
                    stopPhoneCallMonitoring()
                    result.success(null)
                }
                "getCallState" -> {
                    result.success(isOnPhoneCall)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startPhoneCallMonitoring(channel: MethodChannel) {
        try {
            val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager

            phoneStateListener = object : PhoneStateListener() {
                @Deprecated("Deprecated in API 31")
                override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                    val wasOnCall = isOnPhoneCall
                    isOnPhoneCall = state != TelephonyManager.CALL_STATE_IDLE

                    if (wasOnCall != isOnPhoneCall) {
                        // Notify Flutter about call state change
                        channel.invokeMethod("onCallStateChanged", mapOf("isOnCall" to isOnPhoneCall))
                    }
                }
            }

            telephonyManager.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE)
        } catch (e: Exception) {
            println("Error starting phone call monitoring: ${e.message}")
        }
    }

    private fun stopPhoneCallMonitoring() {
        try {
            phoneStateListener?.let {
                val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
                telephonyManager.listen(it, PhoneStateListener.LISTEN_NONE)
                phoneStateListener = null
            }
        } catch (e: Exception) {
            println("Error stopping phone call monitoring: ${e.message}")
        }
    }

    override fun onDestroy() {
        stopPhoneCallMonitoring()
        super.onDestroy()
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