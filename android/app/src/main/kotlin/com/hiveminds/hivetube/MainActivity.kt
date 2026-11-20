package com.hiveminds.hivetube

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.Manifest
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.res.Configuration
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.media.AudioManager
import android.os.Build
import android.provider.Settings
import android.util.Rational
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private lateinit var audioManager: AudioManager
    private var audioChannel: MethodChannel? = null
    private var updateChannel: MethodChannel? = null
    private var pipChannel: MethodChannel? = null
    private var pipEligible = false
    private var pipPlaying = false
    private val pipAction = "com.hiveminds.hivetube.PIP_PLAY_PAUSE"
    private val pipReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == pipAction) pipChannel?.invokeMethod("playPause", null)
        }
    }
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        when (change) {
            AudioManager.AUDIOFOCUS_GAIN -> audioChannel?.invokeMethod("focusGain", null)
            AudioManager.AUDIOFOCUS_LOSS, AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> audioChannel?.invokeMethod("focusLoss", null)
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> audioChannel?.invokeMethod("focusDuck", null)
        }
    }
    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                audioChannel?.invokeMethod("noisy", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
        }
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hivetube/audio_focus")
        audioChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "activate" -> result.success(audioManager.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED)
                "deactivate" -> { audioManager.abandonAudioFocus(focusListener); result.success(null) }
                else -> result.notImplemented()
            }
        }
        updateChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hivetube/update_install")
        updateChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "canRequestInstall" -> result.success(
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()
                )
                "openPermissionSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hivetube/picture_in_picture")
        pipChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    pipEligible = call.argument<Boolean>("eligible") == true
                    pipPlaying = call.argument<Boolean>("playing") == true
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && isInPictureInPictureMode) {
                        setPictureInPictureParams(pipParams())
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        val pipFilter = IntentFilter(pipAction)
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(pipReceiver, pipFilter, Context.RECEIVER_NOT_EXPORTED)
        else registerReceiver(pipReceiver, pipFilter)
        val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(noisyReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        else registerReceiver(noisyReceiver, filter)
    }

    private fun pipParams(): PictureInPictureParams {
        val intent = Intent(pipAction).setPackage(packageName)
        val pending = PendingIntent.getBroadcast(this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val icon = if (pipPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
        val label = if (pipPlaying) "Pause" else "Play"
        val action = RemoteAction(Icon.createWithResource(this, icon), label, label, pending)
        return PictureInPictureParams.Builder().setAspectRatio(Rational(16, 9)).setActions(listOf(action)).build()
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && pipEligible && !isInPictureInPictureMode && packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)) {
            pipChannel?.invokeMethod("entering", null)
            val entered = try { enterPictureInPictureMode(pipParams()) } catch (_: RuntimeException) { false }
            if (!entered) pipChannel?.invokeMethod("changed", false)
        }
    }

    override fun onPictureInPictureModeChanged(inPip: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(inPip, newConfig)
        pipChannel?.invokeMethod("changed", inPip)
    }

    override fun onStop() {
        super.onStop()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N || !isInPictureInPictureMode) {
            pipChannel?.invokeMethod("backgroundWithoutPip", null)
        }
    }

    override fun onDestroy() {
        unregisterReceiver(noisyReceiver)
        unregisterReceiver(pipReceiver)
        pipChannel?.setMethodCallHandler(null)
        pipChannel = null
        audioChannel?.setMethodCallHandler(null)
        audioChannel = null
        updateChannel?.setMethodCallHandler(null)
        updateChannel = null
        super.onDestroy()
    }
}
