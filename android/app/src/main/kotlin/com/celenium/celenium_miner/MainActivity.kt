package com.celenium.celenium_miner

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "celenium/device",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // Android 10+ blocks IMEI from normal apps; Android ID is the
                // stable, permission-free identifier used to derive the wallet.
                "androidId" -> result.success(
                    Settings.Secure.getString(
                        contentResolver,
                        Settings.Secure.ANDROID_ID,
                    ) ?: "",
                )
                else -> result.notImplemented()
            }
        }
    }
}