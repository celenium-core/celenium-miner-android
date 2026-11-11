package com.celenium.celenium_miner

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
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
                // Doze defers CPU work for any app the system has not exempted
                // from battery optimisation, so an overnight mining run can
                // stall even while the service holds its wakelock.
                "batteryExempt" -> result.success(isExemptFromBatteryOptimisations())
                "requestBatteryExemption" -> {
                    openBatteryExemptionDialog()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isExemptFromBatteryOptimisations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        return power.isIgnoringBatteryOptimizations(packageName)
    }

    private fun openBatteryExemptionDialog() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            startActivity(
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                },
            )
        } catch (_: Exception) {
            // Some OEM builds ship without the direct-request activity; the
            // full list still lets the user find the app by hand.
            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        }
    }
}