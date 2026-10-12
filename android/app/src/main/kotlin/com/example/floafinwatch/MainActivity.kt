package com.example.floafinwatch

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.example.floafinwatch/app_settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "openAutostartSettings" -> {
                    val candidates = listOf(
                        Intent().apply {
                            component = ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        },
                        Intent().apply {
                            component = ComponentName("com.miui.securitycenter", "com.miui.securityadd.autostart.AutoStartManagementActivity")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        },
                        Intent("miui.intent.action.OP_AUTO_START").apply {
                            addCategory(Intent.CATEGORY_DEFAULT)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        },
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                    )
                    var launched = false
                    for (intent in candidates) {
                        try {
                            startActivity(intent)
                            launched = true
                            break
                        } catch (_: Exception) {}
                    }
                    result.success(launched)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val fallback = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(fallback)
                            result.success(true)
                        } catch (ex: Exception) {
                            result.error("ERROR", ex.message, null)
                        }
                    }
                }
                "isAutostartEnabled" -> {
                    if (!isXiaomi()) {
                        result.success(true)
                    } else {
                        val allowed = isAutostartAllowed(applicationContext)
                        result.success(allowed)
                    }
                }
                "isIgnoringBatteryOptimizations" -> {
                    try {
                        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
                        val isIgnoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && powerManager != null) {
                            powerManager.isIgnoringBatteryOptimizations(packageName)
                        } else {
                            true
                        }
                        result.success(isIgnoring)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "isXiaomiDevice" -> {
                    result.success(isXiaomi())
                }
                "updateWidgetPreviews" -> {
                    val themeMode = call.argument<String>("theme_mode")
                    val isDark = call.argument<Boolean>("is_dark")
                    updateAllWidgetPreviews(themeMode, isDark)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        syncSystemNightMode()
    }

    override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
        super.onConfigurationChanged(newConfig)
        syncSystemNightMode()
    }

    private fun syncSystemNightMode() {
        try {
            val isDark = (resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES
            val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val themeMode = prefs.getString("theme_mode", "system") ?: "system"
            val shouldBeDark = when (themeMode) {
                "dark" -> true
                "light" -> false
                else -> isDark
            }
            prefs.edit()
                .putBoolean("is_system_dark", isDark)
                .putBoolean("is_dark_theme", shouldBeDark)
                .apply()
        } catch (_: Throwable) {}
    }

    private fun updateAllWidgetPreviews(themeModeArg: String? = null, isDarkArg: Boolean? = null) {
        if (Build.VERSION.SDK_INT >= 35) {
            try {
                val appWidgetManager = android.appwidget.AppWidgetManager.getInstance(this)
                val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

                if (themeModeArg != null) {
                    prefs.edit()
                        .putString("theme_mode", themeModeArg)
                        .putBoolean("is_dark_theme", isDarkArg ?: false)
                        .commit()
                }

                HakDevWidgetProvider.updateDynamicPreview(this, appWidgetManager, prefs, force = true)
                PayoutWidgetProvider.updateDynamicPreview(this, appWidgetManager, prefs, force = true)
                TrendChartWidgetProvider.updateDynamicPreview(this, appWidgetManager, prefs, force = true)
            } catch (e: Throwable) {
                android.util.Log.w("MainActivity", "Error in updateAllWidgetPreviews: ${e.message}")
            }
        }
    }

    private fun isXiaomi(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        return manufacturer.contains("xiaomi") || 
               manufacturer.contains("redmi") || 
               manufacturer.contains("poco")
    }

    private fun isAutostartAllowed(context: Context): Boolean {
        return try {
            val appOpsManager = context.getSystemService(Context.APP_OPS_SERVICE) as? android.app.AppOpsManager
            if (appOpsManager != null) {
                val uid = android.os.Process.myUid()
                val pkg = context.packageName
                var mode = -1
                try {
                    val method = appOpsManager.javaClass.getMethod(
                        "checkOpNoThrow",
                        Int::class.javaPrimitiveType,
                        Int::class.javaPrimitiveType,
                        String::class.java
                    )
                    mode = method.invoke(appOpsManager, 10008, uid, pkg) as Int
                } catch (_: Exception) {
                    try {
                        val method = appOpsManager.javaClass.getMethod(
                            "unsafeCheckOpRawNoThrow",
                            Int::class.javaPrimitiveType,
                            Int::class.javaPrimitiveType,
                            String::class.java
                        )
                        mode = method.invoke(appOpsManager, 10008, uid, pkg) as Int
                    } catch (_: Exception) {}
                }
                mode == android.app.AppOpsManager.MODE_ALLOWED
            } else {
                false
            }
        } catch (_: Exception) {
            false
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        syncSystemNightMode()
        
        // Unlock high refresh rate (90Hz / 120Hz / 144Hz) on Android devices
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                @Suppress("DEPRECATION")
                val modes = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    display?.supportedModes
                } else {
                    windowManager.defaultDisplay.supportedModes
                }
                
                val maxMode = modes?.maxByOrNull { it.refreshRate }
                if (maxMode != null) {
                    val params = window.attributes
                    params.preferredDisplayModeId = maxMode.modeId
                    window.attributes = params
                }
            } catch (_: Exception) {
                // Fallback to default system display mode
            }
        }
    }
}
