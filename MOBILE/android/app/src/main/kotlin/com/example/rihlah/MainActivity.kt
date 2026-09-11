package com.example.rihlah

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "rihlah/power_mode"
    private var powerSaveReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isPowerSaveMode" -> {
                    result.success(powerManager.isPowerSaveMode)
                }
                else -> result.notImplemented()
            }
        }

        // Listen for power-save mode changes and push to Flutter
        powerSaveReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val isPowerSave = powerManager.isPowerSaveMode
                channel.invokeMethod("powerSaveModeChanged", isPowerSave)
            }
        }
        registerReceiver(
            powerSaveReceiver,
            IntentFilter(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED)
        )
    }

    override fun onDestroy() {
        powerSaveReceiver?.let { unregisterReceiver(it) }
        super.onDestroy()
    }
}
