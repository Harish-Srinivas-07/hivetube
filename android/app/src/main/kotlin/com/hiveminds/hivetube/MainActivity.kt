package com.hiveminds.hivetube

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.Manifest
import android.content.pm.PackageManager
import android.net.Uri
import android.media.AudioManager
import android.os.Build
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private lateinit var audioManager: AudioManager
    private var audioChannel: MethodChannel? = null
    private var updateChannel: MethodChannel? = null
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
        val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(noisyReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        else registerReceiver(noisyReceiver, filter)
    }

    override fun onDestroy() {
        unregisterReceiver(noisyReceiver)
        audioChannel?.setMethodCallHandler(null)
        audioChannel = null
        updateChannel?.setMethodCallHandler(null)
        updateChannel = null
        super.onDestroy()
    }
}
