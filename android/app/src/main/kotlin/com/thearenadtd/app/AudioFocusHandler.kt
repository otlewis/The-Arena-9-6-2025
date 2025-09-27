package com.thearenadtd.app

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import io.flutter.plugin.common.MethodChannel

class AudioFocusHandler(private val context: Context, private val channel: MethodChannel) {
    private var audioManager: AudioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var focusRequest: AudioFocusRequest? = null
    private var hasAudioFocus = false

    private val audioFocusChangeListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_GAIN -> {
                hasAudioFocus = true
                channel.invokeMethod("onAudioFocusGain", null)
            }
            AudioManager.AUDIOFOCUS_LOSS -> {
                hasAudioFocus = false
                channel.invokeMethod("onAudioFocusLoss", null)
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                hasAudioFocus = false
                channel.invokeMethod("onAudioFocusLossTransient", null)
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                channel.invokeMethod("onAudioFocusLossTransientCanDuck", null)
            }
        }
    }

    fun requestAudioFocus(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            requestAudioFocusOreo()
        } else {
            requestAudioFocusLegacy()
        }
    }

    @Suppress("DEPRECATION")
    private fun requestAudioFocusLegacy(): Boolean {
        val result = audioManager.requestAudioFocus(
            audioFocusChangeListener,
            AudioManager.STREAM_MUSIC,
            AudioManager.AUDIOFOCUS_GAIN
        )
        hasAudioFocus = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        return hasAudioFocus
    }

    private fun requestAudioFocusOreo(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()

            focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(audioAttributes)
                .setAcceptsDelayedFocusGain(true)
                .setOnAudioFocusChangeListener(audioFocusChangeListener)
                .build()

            val result = audioManager.requestAudioFocus(focusRequest!!)
            hasAudioFocus = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
            return hasAudioFocus
        }
        return false
    }

    fun abandonAudioFocus(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            abandonAudioFocusOreo()
        } else {
            abandonAudioFocusLegacy()
        }
    }

    @Suppress("DEPRECATION")
    private fun abandonAudioFocusLegacy(): Boolean {
        val result = audioManager.abandonAudioFocus(audioFocusChangeListener)
        hasAudioFocus = false
        return result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    private fun abandonAudioFocusOreo(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let {
                val result = audioManager.abandonAudioFocusRequest(it)
                hasAudioFocus = false
                return result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
            }
        }
        return false
    }

    fun isAudioFocusGranted(): Boolean {
        return hasAudioFocus
    }
}